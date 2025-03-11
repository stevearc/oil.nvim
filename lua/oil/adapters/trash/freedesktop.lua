-- Based on the FreeDesktop.org trash specification
-- https://specifications.freedesktop.org/trash-spec/1.0/
local cache = require("oil.cache")
local config = require("oil.config")
local constants = require("oil.constants")
local files = require("oil.adapters.files")
local fs = require("oil.fs")
local util = require("oil.util")

local uv = vim.uv or vim.loop
local FIELD_META = constants.FIELD_META

local M = {}

local function ensure_trash_dir(path)
  local mode = 448 -- 0700
  fs.mkdirp(fs.join(path, "info"), mode)
  fs.mkdirp(fs.join(path, "files"), mode)
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
---@return boolean
local function is_sticky(mode)
  local extra = bit.rshift(mode, 9)
  return bit.band(extra, 4) ~= 0
end

---Get the topdir .Trash/$uid directory if present and valid
---@param path string
---@return string[]
local function get_top_trash_dirs(path)
  local dirs = {}
  local dev = (uv.fs_lstat(path) or {}).dev
  local top_trash_dirs = vim.fs.find(".Trash", { upward = true, path = path, limit = math.huge })
  for _, top_trash_dir in ipairs(top_trash_dirs) do
    local stat = uv.fs_lstat(top_trash_dir)
    if stat and not dev then
      dev = stat.dev
    end
    if stat and stat.dev == dev and stat.type == "directory" and is_sticky(stat.mode) then
      local trash_dir = fs.join(top_trash_dir, tostring(uv.getuid()))
      ensure_trash_dir(trash_dir)
      table.insert(dirs, trash_dir)
    end
  end

  -- Also search for the .Trash-$uid
  top_trash_dirs = vim.fs.find(
    string.format(".Trash-%d", uv.getuid()),
    { upward = true, path = path, limit = math.huge }
  )
  for _, top_trash_dir in ipairs(top_trash_dirs) do
    local stat = uv.fs_lstat(top_trash_dir)
    if stat and stat.dev == dev then
      ensure_trash_dir(top_trash_dir)
      table.insert(dirs, top_trash_dir)
    end
  end

  return dirs
end

---@param path string
---@return string
local function get_write_trash_dir(path)
  local lstat = uv.fs_lstat(path)
  local home_trash = get_home_trash_dir()
  if not lstat then
    -- If the source file doesn't exist default to home trash dir
    return home_trash
  end
  local dev = lstat.dev
  if uv.fs_lstat(home_trash).dev == dev then
    return home_trash
  end

  local top_trash_dirs = get_top_trash_dirs(path)
  if not vim.tbl_isempty(top_trash_dirs) then
    return top_trash_dirs[1]
  end

  local parent = vim.fn.fnamemodify(path, ":h")
  local next_parent = vim.fn.fnamemodify(parent, ":h")
  while parent ~= next_parent and uv.fs_lstat(next_parent).dev == dev do
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

---@param url string
---@param entry oil.Entry
---@param cb fun(path: string)
M.get_entry_path = function(url, entry, cb)
  local internal_entry = assert(cache.get_entry_by_id(entry.id))
  local meta = assert(internal_entry[FIELD_META])
  ---@type oil.TrashInfo
  local trash_info = meta.trash_info
  if not trash_info then
    -- This is a subpath in the trash
    M.normalize_url(url, cb)
    return
  end
  local path = fs.os_to_posix_path(trash_info.trash_file)
  if meta.stat.type == "directory" then
    path = util.addslash(path)
  end
  cb("oil://" .. path)
end

---@class oil.TrashInfo
---@field trash_file string
---@field info_file string
---@field original_path string
---@field deletion_date number
---@field stat uv.aliases.fs_stat_table

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
          uv.fs_lstat(trash_info.trash_file, function(trash_stat_err, trash_stat)
            if trash_stat_err then
              cb(".trashinfo file points to non-existant file")
            else
              trash_info.stat = trash_stat
              ---@cast trash_info oil.TrashInfo
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
  local trash_idx = 0

  local read_next_trash_dir
  read_next_trash_dir = function()
    trash_idx = trash_idx + 1
    local trash_dir = trash_dirs[trash_idx]
    if not trash_dir then
      return cb()
    end

    -- Show all files from the trash directory if we are in the root of the device, which we can
    -- tell if the trash dir is a subpath of our current path
    local show_all_files = fs.is_subpath(path, trash_dir)
    -- The first trash dir is a special case; it is in the home directory and we should only show
    -- all entries if we are in the top root path "/"
    if trash_idx == 1 then
      show_all_files = path == "/"
    end

    local info_dir = fs.join(trash_dir, "info")
    ---@diagnostic disable-next-line: param-type-mismatch, discard-returns
    uv.fs_opendir(info_dir, function(open_err, fd)
      if open_err then
        if open_err:match("^ENOENT: no such file or directory") then
          -- If the directory doesn't exist, treat the list as a success. We will be able to traverse
          -- and edit a not-yet-existing directory.
          return read_next_trash_dir()
        else
          return cb(open_err)
        end
      end
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
                    if path == parent or show_all_files then
                      local name = vim.fn.fnamemodify(info.trash_file, ":t")
                      ---@diagnostic disable-next-line: undefined-field
                      local cache_entry = cache.create_entry(url, name, info.stat.type)
                      local display_name = vim.fn.fnamemodify(info.original_path, ":t")
                      cache_entry[FIELD_META] = {
                        stat = info.stat,
                        trash_info = info,
                        display_name = display_name,
                      }
                      table.insert(internal_entries, cache_entry)
                    end
                    if path ~= parent and (show_all_files or fs.is_subpath(path, parent)) then
                      local name = parent:sub(path:len() + 1)
                      local next_par = vim.fs.dirname(name)
                      while next_par ~= "." do
                        name = next_par
                        next_par = vim.fs.dirname(name)
                      end
                      ---@diagnostic disable-next-line: undefined-field
                      local cache_entry = cache.create_entry(url, name, "directory")

                      cache_entry[FIELD_META] = {
                        stat = info.stat,
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
                vim.schedule(read_next_trash_dir)
              end
            end)
          end
        end)
      end
      read_next()
      ---@diagnostic disable-next-line: param-type-mismatch
    end, 10000)
  end
  read_next_trash_dir()
end

---@param bufnr integer
---@return boolean
M.is_modifiable = function(bufnr)
  return true
end

local file_columns = {}

local current_year
-- Make sure we run this import-time effect in the main loop (mostly for tests)
vim.schedule(function()
  current_year = vim.fn.strftime("%Y")
end)

file_columns.mtime = {
  render = function(entry, conf)
    local meta = entry[FIELD_META]
    if not meta then
      return nil
    end
    ---@type oil.TrashInfo
    local trash_info = meta.trash_info
    local time = trash_info and trash_info.deletion_date or meta.stat and meta.stat.mtime.sec
    if not time then
      return nil
    end
    local fmt = conf and conf.format
    local ret
    if fmt then
      ret = vim.fn.strftime(fmt, time)
    else
      local year = vim.fn.strftime("%Y", time)
      if year ~= current_year then
        ret = vim.fn.strftime("%b %d %Y", time)
      else
        ret = vim.fn.strftime("%b %d %H:%M", time)
      end
    end
    return ret
  end,

  get_sort_value = function(entry)
    local meta = entry[FIELD_META]
    ---@type nil|oil.TrashInfo
    local trash_info = meta and meta.trash_info
    if trash_info then
      return trash_info.deletion_date
    else
      return 0
    end
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

M.supported_cross_adapter_actions = { files = "move" }

---@param action oil.Action
---@return boolean
M.filter_action = function(action)
  if action.type == "create" then
    return false
  elseif action.type == "delete" then
    local entry = assert(cache.get_entry_by_url(action.url))
    local meta = entry[FIELD_META]
    return meta ~= nil and meta.trash_info ~= nil
  elseif action.type == "move" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    return src_adapter.name == "files" or dest_adapter.name == "files"
  elseif action.type == "copy" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    return src_adapter.name == "files" or dest_adapter.name == "files"
  else
    error(string.format("Bad action type '%s'", action.type))
  end
end

---@param err oil.ParseError
---@return boolean
M.filter_error = function(err)
  if err.message == "Duplicate filename" then
    return false
  end
  return true
end

---@param action oil.Action
---@return string
M.render_action = function(action)
  if action.type == "delete" then
    local entry = assert(cache.get_entry_by_url(action.url))
    local meta = entry[FIELD_META]
    ---@type oil.TrashInfo
    local trash_info = meta and meta.trash_info
    local short_path = fs.shorten_path(trash_info.original_path)
    return string.format(" PURGE %s", short_path)
  elseif action.type == "move" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if src_adapter.name == "files" then
      local _, path = util.parse_url(action.src_url)
      assert(path)
      local short_path = files.to_short_os_path(path, action.entry_type)
      return string.format(" TRASH %s", short_path)
    elseif dest_adapter.name == "files" then
      local _, path = util.parse_url(action.dest_url)
      assert(path)
      local short_path = files.to_short_os_path(path, action.entry_type)
      return string.format("RESTORE %s", short_path)
    else
      error("Must be moving files into or out of trash")
    end
  elseif action.type == "copy" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if src_adapter.name == "files" then
      local _, path = util.parse_url(action.src_url)
      assert(path)
      local short_path = files.to_short_os_path(path, action.entry_type)
      return string.format("  COPY %s -> TRASH", short_path)
    elseif dest_adapter.name == "files" then
      local _, path = util.parse_url(action.dest_url)
      assert(path)
      local short_path = files.to_short_os_path(path, action.entry_type)
      return string.format("RESTORE %s", short_path)
    else
      error("Must be copying files into or out of trash")
    end
  else
    error(string.format("Bad action type '%s'", action.type))
  end
end

---@param trash_info oil.TrashInfo
---@param cb fun(err?: string)
local function purge(trash_info, cb)
  fs.recursive_delete("file", trash_info.info_file, function(err)
    if err then
      return cb(err)
    end
    ---@diagnostic disable-next-line: undefined-field
    fs.recursive_delete(trash_info.stat.type, trash_info.trash_file, cb)
  end)
end

---@param path string
---@param info_path string
---@param cb fun(err?: string)
local function write_info_file(path, info_path, cb)
  uv.fs_open(
    info_path,
    "w",
    448,
    vim.schedule_wrap(function(err, fd)
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
  )
end

---@param path string
---@param cb fun(err?: string, trash_info?: oil.TrashInfo)
local function create_trash_info(path, cb)
  local trash_dir = get_write_trash_dir(path)
  local basename = vim.fs.basename(path)
  local now = os.time()
  local name = string.format("%s-%d.%d", basename, now, math.random(100000, 999999))
  local dest_path = fs.join(trash_dir, "files", name)
  local dest_info = fs.join(trash_dir, "info", name .. ".trashinfo")
  uv.fs_lstat(path, function(err, stat)
    if err then
      return cb(err)
    end
    assert(stat)
    write_info_file(path, dest_info, function(info_err)
      if info_err then
        return cb(info_err)
      end
      ---@type oil.TrashInfo
      local trash_info = {
        original_path = path,
        trash_file = dest_path,
        info_file = dest_info,
        deletion_date = now,
        stat = stat,
      }
      cb(nil, trash_info)
    end)
  end)
end

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  if action.type == "delete" then
    local entry = assert(cache.get_entry_by_url(action.url))
    local meta = entry[FIELD_META]
    ---@type oil.TrashInfo
    local trash_info = meta and meta.trash_info
    purge(trash_info, cb)
  elseif action.type == "move" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if src_adapter.name == "files" then
      local _, path = util.parse_url(action.src_url)
      M.delete_to_trash(assert(path), cb)
    elseif dest_adapter.name == "files" then
      -- Restore
      local _, dest_path = util.parse_url(action.dest_url)
      assert(dest_path)
      local entry = assert(cache.get_entry_by_url(action.src_url))
      local meta = entry[FIELD_META]
      ---@type oil.TrashInfo
      local trash_info = meta and meta.trash_info
      fs.recursive_move(action.entry_type, trash_info.trash_file, dest_path, function(err)
        if err then
          return cb(err)
        end
        uv.fs_unlink(trash_info.info_file, cb)
      end)
    else
      error("Must be moving files into or out of trash")
    end
  elseif action.type == "copy" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if src_adapter.name == "files" then
      local _, path = util.parse_url(action.src_url)
      assert(path)
      create_trash_info(path, function(err, trash_info)
        if err then
          cb(err)
        else
          local stat_type = trash_info.stat.type or "unknown"
          fs.recursive_copy(stat_type, path, trash_info.trash_file, vim.schedule_wrap(cb))
        end
      end)
    elseif dest_adapter.name == "files" then
      -- Restore
      local _, dest_path = util.parse_url(action.dest_url)
      assert(dest_path)
      local entry = assert(cache.get_entry_by_url(action.src_url))
      local meta = entry[FIELD_META]
      ---@type oil.TrashInfo
      local trash_info = meta and meta.trash_info
      fs.recursive_copy(action.entry_type, trash_info.trash_file, dest_path, cb)
    else
      error("Must be moving files into or out of trash")
    end
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

---@param path string
---@param cb fun(err?: string)
M.delete_to_trash = function(path, cb)
  create_trash_info(path, function(err, trash_info)
    if err then
      cb(err)
    else
      local stat_type = trash_info.stat.type or "unknown"
      fs.recursive_move(stat_type, path, trash_info.trash_file, vim.schedule_wrap(cb))
    end
  end)
end

return M
