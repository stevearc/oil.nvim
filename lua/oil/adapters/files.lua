local cache = require("oil.cache")
local columns = require("oil.columns")
local config = require("oil.config")
local constants = require("oil.constants")
local fs = require("oil.fs")
local git = require("oil.git")
local log = require("oil.log")
local permissions = require("oil.adapters.files.permissions")
local trash = require("oil.adapters.files.trash")
local util = require("oil.util")
local uv = vim.uv or vim.loop

local M = {}

local FIELD_NAME = constants.FIELD_NAME
local FIELD_TYPE = constants.FIELD_TYPE
local FIELD_META = constants.FIELD_META

local function read_link_data(path, cb)
  uv.fs_readlink(
    path,
    vim.schedule_wrap(function(link_err, link)
      if link_err then
        cb(link_err)
      else
        assert(link)
        local stat_path = link
        if not fs.is_absolute(link) then
          stat_path = fs.join(vim.fn.fnamemodify(path, ":h"), link)
        end
        uv.fs_stat(stat_path, function(stat_err, stat)
          cb(nil, link, stat)
        end)
      end
    end)
  )
end

---@class (exact) oil.FilesAdapter: oil.Adapter
---@field to_short_os_path fun(path: string, entry_type: nil|oil.EntryType): string

---@param path string
---@param entry_type nil|oil.EntryType
---@return string
M.to_short_os_path = function(path, entry_type)
  local shortpath = fs.shorten_path(fs.posix_to_os_path(path))
  if entry_type == "directory" then
    shortpath = util.addslash(shortpath, true)
  end
  return shortpath
end

local file_columns = {}

file_columns.size = {
  require_stat = true,

  render = function(entry, conf)
    local meta = entry[FIELD_META]
    local stat = meta and meta.stat
    if not stat then
      return columns.EMPTY
    end
    if stat.size >= 1e9 then
      return string.format("%.1fG", stat.size / 1e9)
    elseif stat.size >= 1e6 then
      return string.format("%.1fM", stat.size / 1e6)
    elseif stat.size >= 1e3 then
      return string.format("%.1fk", stat.size / 1e3)
    else
      return string.format("%d", stat.size)
    end
  end,

  get_sort_value = function(entry)
    local meta = entry[FIELD_META]
    local stat = meta and meta.stat
    if stat then
      return stat.size
    else
      return 0
    end
  end,

  parse = function(line, conf)
    return line:match("^(%d+%S*)%s+(.*)$")
  end,
}

-- TODO support file permissions on windows
if not fs.is_windows then
  file_columns.permissions = {
    require_stat = true,

    render = function(entry, conf)
      local meta = entry[FIELD_META]
      local stat = meta and meta.stat
      if not stat then
        return columns.EMPTY
      end
      return permissions.mode_to_str(stat.mode)
    end,

    parse = function(line, conf)
      return permissions.parse(line)
    end,

    compare = function(entry, parsed_value)
      local meta = entry[FIELD_META]
      if parsed_value and meta and meta.stat and meta.stat.mode then
        local mask = bit.lshift(1, 12) - 1
        local old_mode = bit.band(meta.stat.mode, mask)
        if parsed_value ~= old_mode then
          return true
        end
      end
      return false
    end,

    render_action = function(action)
      local _, path = util.parse_url(action.url)
      assert(path)
      return string.format(
        "CHMOD %s %s",
        permissions.mode_to_octal_str(action.value),
        M.to_short_os_path(path, action.entry_type)
      )
    end,

    perform_action = function(action, callback)
      local _, path = util.parse_url(action.url)
      assert(path)
      path = fs.posix_to_os_path(path)
      uv.fs_stat(path, function(err, stat)
        if err then
          return callback(err)
        end
        assert(stat)
        -- We are only changing the lower 12 bits of the mode
        local mask = bit.bnot(bit.lshift(1, 12) - 1)
        local old_mode = bit.band(stat.mode, mask)
        uv.fs_chmod(path, bit.bor(old_mode, action.value), callback)
      end)
    end,
  }
end

local current_year
-- Make sure we run this import-time effect in the main loop (mostly for tests)
vim.schedule(function()
  current_year = vim.fn.strftime("%Y")
end)

for _, time_key in ipairs({ "ctime", "mtime", "atime", "birthtime" }) do
  file_columns[time_key] = {
    require_stat = true,

    render = function(entry, conf)
      local meta = entry[FIELD_META]
      local stat = meta and meta.stat
      if not stat then
        return columns.EMPTY
      end
      local fmt = conf and conf.format
      local ret
      if fmt then
        ret = vim.fn.strftime(fmt, stat[time_key].sec)
      else
        local year = vim.fn.strftime("%Y", stat[time_key].sec)
        if year ~= current_year then
          ret = vim.fn.strftime("%b %d %Y", stat[time_key].sec)
        else
          ret = vim.fn.strftime("%b %d %H:%M", stat[time_key].sec)
        end
      end
      return ret
    end,

    parse = function(line, conf)
      local fmt = conf and conf.format
      local pattern
      if fmt then
        -- Replace placeholders with a pattern that matches non-space characters (e.g. %H -> %S+)
        -- and whitespace with a pattern that matches any amount of whitespace
        -- e.g. "%b %d %Y" -> "%S+%s+%S+%s+%S+"
        pattern = fmt
          :gsub("%%.", "%%S+")
          :gsub("%s+", "%%s+")
          -- escape `()[]` because those are special characters in Lua patterns
          :gsub(
            "%(",
            "%%("
          )
          :gsub("%)", "%%)")
          :gsub("%[", "%%[")
          :gsub("%]", "%%]")
      else
        pattern = "%S+%s+%d+%s+%d%d:?%d%d"
      end
      return line:match("^(" .. pattern .. ")%s+(.+)$")
    end,

    get_sort_value = function(entry)
      local meta = entry[FIELD_META]
      local stat = meta and meta.stat
      if stat then
        return stat[time_key].sec
      else
        return 0
      end
    end,
  }
end

---@param column_defs table[]
---@return boolean
local function columns_require_stat(column_defs)
  for _, def in ipairs(column_defs) do
    local name = util.split_config(def)
    local column = M.get_column(name)
    ---@diagnostic disable-next-line: undefined-field We only put this on the files adapter columns
    if column and column.require_stat then
      return true
    end
  end
  return false
end

---@param name string
---@return nil|oil.ColumnDefinition
M.get_column = function(name)
  return file_columns[name]
end

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  local scheme, path = util.parse_url(url)
  assert(path)

  if fs.is_windows then
    if path == "/" then
      return callback(url)
    else
      local is_root_drive = path:match("^/%u$")
      if is_root_drive then
        return callback(url .. "/")
      end
    end
  end

  local os_path = vim.fn.fnamemodify(fs.posix_to_os_path(path), ":p")
  uv.fs_realpath(os_path, function(err, new_os_path)
    local realpath
    if fs.is_windows then
      -- Ignore the fs_realpath on windows because it will resolve mapped network drives to the IP
      -- address instead of using the drive letter
      realpath = os_path
    else
      realpath = new_os_path or os_path
    end

    uv.fs_stat(
      realpath,
      vim.schedule_wrap(function(stat_err, stat)
        local is_directory
        if stat then
          is_directory = stat.type == "directory"
        elseif vim.endswith(realpath, "/") or (fs.is_windows and vim.endswith(realpath, "\\")) then
          is_directory = true
        else
          local filetype = vim.filetype.match({ filename = vim.fs.basename(realpath) })
          is_directory = filetype == nil
        end

        if is_directory then
          local norm_path = util.addslash(fs.os_to_posix_path(realpath))
          callback(scheme .. norm_path)
        else
          callback(realpath)
        end
      end)
    )
  end)
end

---@param url string
---@param entry oil.Entry
---@param cb fun(path: nil|string)
M.get_entry_path = function(url, entry, cb)
  if entry.id then
    local parent_url = cache.get_parent_url(entry.id)
    local scheme, path = util.parse_url(parent_url)
    M.normalize_url(scheme .. path .. entry.name, cb)
  else
    if entry.type == "directory" then
      cb(url)
    else
      local _, path = util.parse_url(url)
      local os_path = vim.fn.fnamemodify(fs.posix_to_os_path(assert(path)), ":p")
      cb(os_path)
    end
  end
end

---@param parent_dir string
---@param entry oil.InternalEntry
---@param require_stat boolean
---@param cb fun(err?: string)
local function fetch_entry_metadata(parent_dir, entry, require_stat, cb)
  local entry_path = fs.posix_to_os_path(parent_dir .. entry[FIELD_NAME])
  local meta = entry[FIELD_META]
  if not meta then
    meta = {}
    entry[FIELD_META] = meta
  end

  -- Sometimes fs_readdir entries don't have a type, so we need to stat them.
  -- See https://github.com/stevearc/oil.nvim/issues/543
  if not require_stat and not entry[FIELD_TYPE] then
    require_stat = true
  end

  -- Make sure we always get fs_stat info for links
  if entry[FIELD_TYPE] == "link" then
    read_link_data(entry_path, function(link_err, link, link_stat)
      if link_err then
        log.warn("Error reading link data %s: %s", entry_path, link_err)
        return cb()
      end
      meta.link = link
      if link_stat then
        -- Use the fstat of the linked file as the stat for the link
        meta.link_stat = link_stat
        meta.stat = link_stat
      elseif require_stat then
        -- The link is broken, so let's use the stat of the link itself
        uv.fs_lstat(entry_path, function(stat_err, stat)
          if stat_err then
            log.warn("Error lstat link file %s: %s", entry_path, stat_err)
            return cb()
          end
          meta.stat = stat
          cb()
        end)
        return
      end

      cb()
    end)
  elseif require_stat then
    uv.fs_stat(entry_path, function(stat_err, stat)
      if stat_err then
        log.warn("Error stat file %s: %s", entry_path, stat_err)
        return cb()
      end
      assert(stat)
      entry[FIELD_TYPE] = stat.type
      meta.stat = stat
      cb()
    end)
  else
    cb()
  end
end

-- On windows, sometimes the entry type from fs_readdir is "link" but the actual type is not.
-- See https://github.com/stevearc/oil.nvim/issues/535
if fs.is_windows then
  local old_fetch_metadata = fetch_entry_metadata
  fetch_entry_metadata = function(parent_dir, entry, require_stat, cb)
    if entry[FIELD_TYPE] == "link" then
      local entry_path = fs.posix_to_os_path(parent_dir .. entry[FIELD_NAME])
      uv.fs_lstat(entry_path, function(stat_err, stat)
        if stat_err then
          log.warn("Error lstat link file %s: %s", entry_path, stat_err)
          return old_fetch_metadata(parent_dir, entry, require_stat, cb)
        end
        assert(stat)
        entry[FIELD_TYPE] = stat.type
        local meta = entry[FIELD_META]
        if not meta then
          meta = {}
          entry[FIELD_META] = meta
        end
        meta.stat = stat
        old_fetch_metadata(parent_dir, entry, require_stat, cb)
      end)
    else
      return old_fetch_metadata(parent_dir, entry, require_stat, cb)
    end
  end
end

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
local function list_windows_drives(url, column_defs, cb)
  local _, path = util.parse_url(url)
  assert(path)
  local require_stat = columns_require_stat(column_defs)
  local stdout = ""
  local jid = vim.fn.jobstart({ "wmic", "logicaldisk", "get", "name" }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      stdout = table.concat(data, "\n")
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        return cb("Error listing windows devices")
      end
      local lines = vim.split(stdout, "\n", { plain = true, trimempty = true })
      -- Remove the "Name" header
      table.remove(lines, 1)
      local internal_entries = {}
      local complete_disk_cb = util.cb_collect(#lines, function(err)
        if err then
          cb(err)
        else
          cb(nil, internal_entries)
        end
      end)

      for _, disk in ipairs(lines) do
        if disk:match("^%s*$") then
          -- Skip empty line
          complete_disk_cb()
        else
          disk = disk:gsub(":%s*$", "")
          local cache_entry = cache.create_entry(url, disk, "directory")
          table.insert(internal_entries, cache_entry)
          fetch_entry_metadata(path, cache_entry, require_stat, complete_disk_cb)
        end
      end
    end,
  })
  if jid <= 0 then
    cb("Could not list windows devices")
  end
end

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, cb)
  local _, path = util.parse_url(url)
  assert(path)
  if fs.is_windows and path == "/" then
    return list_windows_drives(url, column_defs, cb)
  end
  local dir = fs.posix_to_os_path(path)
  local require_stat = columns_require_stat(column_defs)

  ---@diagnostic disable-next-line: param-type-mismatch, discard-returns
  uv.fs_opendir(dir, function(open_err, fd)
    if open_err then
      if open_err:match("^ENOENT: no such file or directory") then
        -- If the directory doesn't exist, treat the list as a success. We will be able to traverse
        -- and edit a not-yet-existing directory.
        return cb()
      else
        return cb(open_err)
      end
    end
    local read_next
    read_next = function()
      uv.fs_readdir(fd, function(err, entries)
        local internal_entries = {}
        if err then
          uv.fs_closedir(fd, function()
            cb(err)
          end)
          return
        elseif entries then
          local poll = util.cb_collect(#entries, function(inner_err)
            if inner_err then
              cb(inner_err)
            else
              cb(nil, internal_entries, read_next)
            end
          end)
          for _, entry in ipairs(entries) do
            local cache_entry = cache.create_entry(url, entry.name, entry.type)
            table.insert(internal_entries, cache_entry)
            fetch_entry_metadata(path, cache_entry, require_stat, poll)
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
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local _, path = util.parse_url(bufname)
  assert(path)
  if fs.is_windows and path == "/" then
    return false
  end
  local dir = fs.posix_to_os_path(path)
  local stat = uv.fs_stat(dir)
  if not stat then
    return true
  end

  -- fs_access can return nil, force boolean return
  return uv.fs_access(dir, "W") == true
end

---@param action oil.Action
---@return string
M.render_action = function(action)
  if action.type == "create" then
    local _, path = util.parse_url(action.url)
    assert(path)
    local ret = string.format("CREATE %s", M.to_short_os_path(path, action.entry_type))
    if action.link then
      ret = ret .. " -> " .. fs.posix_to_os_path(action.link)
    end
    return ret
  elseif action.type == "delete" then
    local _, path = util.parse_url(action.url)
    assert(path)
    local short_path = M.to_short_os_path(path, action.entry_type)
    if config.delete_to_trash then
      return string.format(" TRASH %s", short_path)
    else
      return string.format("DELETE %s", short_path)
    end
  elseif action.type == "move" or action.type == "copy" then
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if dest_adapter == M then
      local _, src_path = util.parse_url(action.src_url)
      assert(src_path)
      local _, dest_path = util.parse_url(action.dest_url)
      assert(dest_path)
      return string.format(
        "  %s %s -> %s",
        action.type:upper(),
        M.to_short_os_path(src_path, action.entry_type),
        M.to_short_os_path(dest_path, action.entry_type)
      )
    else
      -- We should never hit this because we don't implement supported_cross_adapter_actions
      error("files adapter doesn't support cross-adapter move/copy")
    end
  else
    error(string.format("Bad action type: '%s'", action.type))
  end
end

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  if action.type == "create" then
    local _, path = util.parse_url(action.url)
    assert(path)
    path = fs.posix_to_os_path(path)

    if config.git.add(path) then
      local old_cb = cb
      cb = vim.schedule_wrap(function(err)
        if not err then
          git.add(path, old_cb)
        else
          old_cb(err)
        end
      end)
    end

    if action.entry_type == "directory" then
      uv.fs_mkdir(path, 493, function(err)
        -- Ignore if the directory already exists
        if not err or err:match("^EEXIST:") then
          cb()
        else
          cb(err)
        end
      end) -- 0755
    elseif action.entry_type == "link" and action.link then
      local flags = nil
      local target = fs.posix_to_os_path(action.link)
      if fs.is_windows then
        flags = {
          dir = vim.fn.isdirectory(target) == 1,
          junction = false,
        }
      end
      ---@diagnostic disable-next-line: param-type-mismatch
      uv.fs_symlink(target, path, flags, cb)
    else
      fs.touch(path, cb)
    end
  elseif action.type == "delete" then
    local _, path = util.parse_url(action.url)
    assert(path)
    path = fs.posix_to_os_path(path)

    if config.git.rm(path) then
      local old_cb = cb
      cb = vim.schedule_wrap(function(err)
        if not err then
          git.rm(path, old_cb)
        else
          old_cb(err)
        end
      end)
    end

    if config.delete_to_trash then
      if config.trash_command then
        vim.notify_once(
          "Oil now has native support for trash. Remove the `trash_command` from your config to try it out!",
          vim.log.levels.WARN
        )
        trash.recursive_delete(path, cb)
      else
        require("oil.adapters.trash").delete_to_trash(path, cb)
      end
    else
      fs.recursive_delete(action.entry_type, path, cb)
    end
  elseif action.type == "move" then
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if dest_adapter == M then
      local _, src_path = util.parse_url(action.src_url)
      assert(src_path)
      local _, dest_path = util.parse_url(action.dest_url)
      assert(dest_path)
      src_path = fs.posix_to_os_path(src_path)
      dest_path = fs.posix_to_os_path(dest_path)
      if config.git.mv(src_path, dest_path) then
        git.mv(action.entry_type, src_path, dest_path, cb)
      else
        fs.recursive_move(action.entry_type, src_path, dest_path, cb)
      end
    else
      -- We should never hit this because we don't implement supported_cross_adapter_actions
      cb("files adapter doesn't support cross-adapter move")
    end
  elseif action.type == "copy" then
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if dest_adapter == M then
      local _, src_path = util.parse_url(action.src_url)
      assert(src_path)
      local _, dest_path = util.parse_url(action.dest_url)
      assert(dest_path)
      src_path = fs.posix_to_os_path(src_path)
      dest_path = fs.posix_to_os_path(dest_path)
      fs.recursive_copy(action.entry_type, src_path, dest_path, cb)
    else
      -- We should never hit this because we don't implement supported_cross_adapter_actions
      cb("files adapter doesn't support cross-adapter copy")
    end
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

return M
