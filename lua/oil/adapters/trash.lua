-- Based on the FreeDesktop.org trash specification
-- https://specifications.freedesktop.org/trash-spec/trashspec-1.0.html
local cache = require("oil.cache")
local constants = require("oil.constants")
local fs = require("oil.fs")
local util = require("oil.util")

local uv = vim.uv or vim.loop
local FIELD_META = constants.FIELD_META

local M = {}

local function touch_dir(path)
  uv.fs_mkdir(path, 448) -- 0700
end

local function ensure_trash_dir(path)
  touch_dir(path)
  touch_dir(fs.join(path, "info"))
  touch_dir(fs.join(path, "files"))
end

---Gets the location of the home trash dir, creating it if necessary
---@return string
local function get_home_trash_dir()
  local xdg_home = vim.env.XDG_DATA_HOME
  if not xdg_home then
    xdg_home = fs.join(assert(uv.os_homedir()), ".local", "share")
  end
  local trash_dir = fs.join(xdg_home, "Trash")
  ensure_trash_dir(trash_dir)
  return trash_dir
end

---@param mode integer
local function is_sticky(mode)
  local extra = bit.rshift(mode, 9)
  return bit.band(extra, 4) ~= 0
end

---Get the topdir .Trash/$uid directory if present and valid
---@param path string
---@return string[]
local function get_top_trash_dirs(path)
  local dirs = {}
  local dev = uv.fs_stat(path).dev
  local top_trash_dirs = vim.fs.find(".Trash", { upward = true, path = path, limit = math.huge })
  for _, top_trash_dir in ipairs(top_trash_dirs) do
    local stat = uv.fs_stat(top_trash_dir)
    if stat and stat.dev == dev and stat.type == "directory" and is_sticky(stat.mode) then
      table.insert(dirs, fs.join(top_trash_dir, tostring(uv.getuid())))
    end
  end

  -- Also search for the .Trash-$uid
  top_trash_dirs = vim.fs.find(
    string.format(".Trash-%d", uv.getuid()),
    { upward = true, path = path, limit = math.huge }
  )
  for _, top_trash_dir in ipairs(top_trash_dirs) do
    local stat = uv.fs_stat(top_trash_dir)
    if stat and stat.dev == dev then
      table.insert(dirs, top_trash_dir)
    end
  end

  return dirs
end

---@param path string
---@return string
local function get_write_trash_dir(path)
  local dev = uv.fs_stat(path).dev
  local home_trash = get_home_trash_dir()
  if uv.fs_stat(home_trash).dev == dev then
    return home_trash
  end

  local top_trash_dirs = get_top_trash_dirs(path)
  if not vim.tbl_isempty(top_trash_dirs) then
    return top_trash_dirs[1]
  end

  local parent = vim.fn.fnamemodify(path, ":h")
  local next_parent = vim.fn.fnamemodify(parent, ":h")
  while parent ~= next_parent and uv.fs_stat(next_parent).dev == dev do
    parent = next_parent
    next_parent = vim.fn.fnamemodify(parent, ":h")
  end

  local top_trash = fs.join(parent, string.format(".Trash-%d", uv.getuid()))
  ensure_trash_dir(top_trash)
  return top_trash
end

---@param path string
---@return string[]
local function get_read_trash_dirs(path)
  local dirs = { get_home_trash_dir() }
  vim.list_extend(dirs, get_top_trash_dirs(path))
  return dirs
end

-- FIXME handle oil.select() on duplicate filenames

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  local scheme, path = util.parse_url(url)
  assert(path)
  local os_path = vim.fn.fnamemodify(fs.posix_to_os_path(path), ":p")
  uv.fs_realpath(
    os_path,
    vim.schedule_wrap(function(err, new_os_path)
      local realpath = new_os_path or os_path
      callback(scheme .. util.addslash(fs.os_to_posix_path(realpath)))
    end)
  )
end

---@class oil.TrashInfo
---@field trash_file string
---@field info_file string
---@field original_path string
---@field deletion_date number
---@field stat uv_fs_t

---@param info_file string
---@param cb fun(err?: string, info?: oil.TrashInfo)
local function read_trash_info(info_file, cb)
  if not vim.endswith(info_file, ".trashinfo") then
    return cb("File is not .trashinfo")
  end
  uv.fs_open(info_file, "r", 448, function(err, fd)
    if err then
      return cb(err)
    end
    assert(fd)
    uv.fs_fstat(fd, function(stat_err, stat)
      if stat_err then
        uv.fs_close(fd)
        return cb(stat_err)
      end
      uv.fs_read(
        fd,
        assert(stat).size,
        nil,
        vim.schedule_wrap(function(read_err, content)
          uv.fs_close(fd)
          if read_err then
            return cb(read_err)
          end
          assert(content)
          local trash_info = {
            info_file = info_file,
          }
          local lines = vim.split(content, "\r?\n")
          if lines[1] ~= "[Trash Info]" then
            return cb("File missing [Trash Info] header")
          end
          local trash_base = vim.fn.fnamemodify(info_file, ":h:h")
          for _, line in ipairs(lines) do
            local key, value = unpack(vim.split(line, "=", { plain = true, trimempty = true }))
            if key == "Path" and not trash_info.original_path then
              if not vim.startswith(value, "/") then
                value = fs.join(trash_base, value)
              end
              trash_info.original_path = value
            elseif key == "DeletionDate" and not trash_info.deletion_date then
              trash_info.deletion_date = vim.fn.strptime("%Y-%m-%dT%H:%M:%S", value)
            end
          end

          if not trash_info.original_path or not trash_info.deletion_date then
            return cb("File missing required fields")
          end

          local basename = vim.fn.fnamemodify(info_file, ":t:r")
          trash_info.trash_file = fs.join(trash_base, "files", basename)
          uv.fs_stat(trash_info.trash_file, function(trash_stat_err, trash_stat)
            if trash_stat_err then
              cb(".trashinfo file points to non-existant file")
            else
              trash_info.stat = trash_stat
              cb(nil, trash_info)
            end
          end)
        end)
      )
    end)
  end)
end

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, cb)
  cb = vim.schedule_wrap(cb)
  local _, path = util.parse_url(url)
  assert(path)
  local trash_dirs = get_read_trash_dirs(path)
  -- FIXME iterate over trash dirs
  local trash_dir = trash_dirs[1]
  local info_dir = fs.join(trash_dir, "info")
  ---@diagnostic disable-next-line: param-type-mismatch
  uv.fs_opendir(info_dir, function(open_err, fd)
    if open_err then
      if open_err:match("^ENOENT: no such file or directory") then
        -- If the directory doesn't exist, treat the list as a success. We will be able to traverse
        -- and edit a not-yet-existing directory.
        return cb()
      else
        return cb(open_err)
      end
    end
    local seen_names = {}
    local read_next
    read_next = function()
      uv.fs_readdir(fd, function(err, entries)
        if err then
          uv.fs_closedir(fd, function()
            cb(err)
          end)
          return
        elseif entries then
          local internal_entries = {}
          local poll = util.cb_collect(#entries, function(inner_err)
            if inner_err then
              cb(inner_err)
            else
              cb(nil, internal_entries, read_next)
            end
          end)

          for _, entry in ipairs(entries) do
            read_trash_info(
              fs.join(info_dir, entry.name),
              vim.schedule_wrap(function(read_err, info)
                if read_err then
                  -- Discard the error. We don't care if there's something wrong with one of these
                  -- files.
                  poll()
                else
                  local parent = util.addslash(vim.fn.fnamemodify(info.original_path, ":h"))
                  if path == parent then
                    local name = vim.fn.fnamemodify(info.original_path, ":t")
                    if seen_names[name] then
                      seen_names[name] = seen_names[name] + 1
                      name = string.format("%s (%d)", name, seen_names[name])
                    else
                      seen_names[name] = 0
                    end
                    ---@diagnostic disable-next-line: undefined-field
                    local cache_entry = cache.create_entry(url, name, info.stat.type)
                    cache_entry[FIELD_META] = {
                      stat = info.stat,
                      trash_info = info,
                    }
                    table.insert(internal_entries, cache_entry)
                  end
                  poll()
                end
              end)
            )
          end
        else
          uv.fs_closedir(fd, function(close_err)
            if close_err then
              cb(close_err)
            else
              cb()
            end
          end)
        end
      end)
    end
    read_next()
    ---@diagnostic disable-next-line: param-type-mismatch
  end, 10000)
end

---@param bufnr integer
---@return boolean
M.is_modifiable = function(bufnr)
  return true
end

local file_columns = {}

local current_year = vim.fn.strftime("%Y")

file_columns.mtime = {
  render = function(entry, conf)
    local meta = entry[FIELD_META]
    ---@type oil.TrashInfo
    local trash_info = meta.trash_info
    local fmt = conf and conf.format
    local ret
    if fmt then
      ret = vim.fn.strftime(fmt, trash_info.deletion_date)
    else
      local year = vim.fn.strftime("%Y", trash_info.deletion_date)
      if year ~= current_year then
        ret = vim.fn.strftime("%b %d %Y", trash_info.deletion_date)
      else
        ret = vim.fn.strftime("%b %d %H:%M", trash_info.deletion_date)
      end
    end
    return ret
  end,

  parse = function(line, conf)
    local fmt = conf and conf.format
    local pattern
    if fmt then
      pattern = fmt:gsub("%%.", "%%S+")
    else
      pattern = "%S+%s+%d+%s+%d%d:?%d%d"
    end
    return line:match("^(" .. pattern .. ")%s+(.+)$")
  end,
}

---@param name string
---@return nil|oil.ColumnDefinition
M.get_column = function(name)
  return file_columns[name]
end

M.supported_adapters_for_copy = { files = true }

---@param action oil.Action
---@return string
M.render_action = function(action)
  -- FIXME
  if action.type == "create" or action.type == "delete" then
    return string.format("%s %s", action.type:upper(), action.url)
  elseif action.type == "move" or action.type == "copy" then
    return string.format("  %s %s -> %s", action.type:upper(), action.src_url, action.dest_url)
  else
    error("Bad action type")
  end
end

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  -- FIXME
  if action.type == "create" then
    cb(string.format("Creating files in trash is not supported: %s", action.url))
  elseif action.type == "delete" then
    -- FIXME how are we going to specify a unique path with just the url? We could dedupe the url
    -- like we are above, but then how to we recover the trash_info?
    cb()
  elseif action.type == "move" then
    cb()
  elseif action.type == "copy" then
    cb()
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

-- FIXME add keyboard shortcuts for this?

M.restore_file = function()
  -- FIXME
end

---@param path string
---@param info_path string
---@param cb fun(err?: string)
local function write_info_file(path, info_path, cb)
  uv.fs_open(info_path, "w", 448, function(err, fd)
    if err then
      return cb(err)
    end
    assert(fd)
    local deletion_date = vim.fn.strftime("%Y-%m-%dT%H:%M:%S")
    local contents = string.format("[Trash Info]\nPath=%s\nDeletionDate=%s", path, deletion_date)
    uv.fs_write(fd, contents, function(write_err)
      uv.fs_close(fd, function(close_err)
        cb(write_err or close_err)
      end)
    end)
  end)
end

---@param path string
---@param cb fun(err?: string)
M.delete_to_trash = function(path, cb)
  local trash_dir = get_write_trash_dir(path)
  local basename = vim.fs.basename(path)
  local name = string.format("%s-%d.%d", basename, os.time(), math.random(100000, 999999))
  local dest_path = fs.join(trash_dir, "files", name)
  local dest_info = fs.join(trash_dir, "info", name .. ".trashinfo")
  uv.fs_stat(path, function(err, stat)
    if err then
      return cb(err)
    end
    assert(stat)
    write_info_file(path, dest_info, function(info_err)
      if info_err then
        return cb(info_err)
      end
      local stat_type = stat.type
      ---@cast stat_type oil.EntryType
      fs.recursive_move(stat_type, path, dest_path, vim.schedule_wrap(cb))
    end)
  end)
end

return M
