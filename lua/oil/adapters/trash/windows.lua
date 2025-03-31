local util = require("oil.util")
local uv = vim.uv or vim.loop
local cache = require("oil.cache")
local config = require("oil.config")
local constants = require("oil.constants")
local files = require("oil.adapters.files")
local fs = require("oil.fs")
local powershell_trash = require("oil.adapters.trash.windows.powershell-trash")

local FIELD_META = constants.FIELD_META
local FIELD_TYPE = constants.FIELD_TYPE

local M = {}

---@return string
local function get_trash_dir()
  local cwd = assert(vim.fn.getcwd())
  local trash_dir = cwd:sub(1, 3) .. "$Recycle.Bin"
  if vim.fn.isdirectory(trash_dir) == 1 then
    return trash_dir
  end
  trash_dir = "C:\\$Recycle.Bin"
  if vim.fn.isdirectory(trash_dir) == 1 then
    return trash_dir
  end
  error("No trash found")
end

---@param path string
---@return string
local win_addslash = function(path)
  if not vim.endswith(path, "\\") then
    return path .. "\\"
  else
    return path
  end
end

---@class oil.WindowsTrashInfo
---@field trash_file string
---@field original_path string
---@field deletion_date integer
---@field info_file? string

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, cb)
  local _, path = util.parse_url(url)
  path = fs.posix_to_os_path(assert(path))

  local trash_dir = get_trash_dir()
  local show_all_files = fs.is_subpath(path, trash_dir)

  powershell_trash.list_raw_entries(function(err, raw_entries)
    if err then
      cb(err)
      return
    end

    local raw_displayed_entries = vim.tbl_filter(
      ---@param entry {IsFolder: boolean, DeletionDate: integer, Name: string, Path: string, OriginalPath: string}
      function(entry)
        local parent = win_addslash(assert(vim.fn.fnamemodify(entry.OriginalPath, ":h")))
        local is_in_path = path == parent
        local is_subpath = fs.is_subpath(path, parent)
        return is_in_path or is_subpath or show_all_files
      end,
      raw_entries
    )
    local displayed_entries = vim.tbl_map(
      ---@param entry {IsFolder: boolean, DeletionDate: integer, Name: string, Path: string, OriginalPath: string}
      ---@return {[1]:nil, [2]:string, [3]:string, [4]:{stat: uv_fs_t, trash_info: oil.WindowsTrashInfo, display_name: string}}
      function(entry)
        local parent = win_addslash(assert(vim.fn.fnamemodify(entry.OriginalPath, ":h")))

        --- @type oil.InternalEntry
        local cache_entry
        if path == parent or show_all_files then
          local deleted_file_tail = assert(vim.fn.fnamemodify(entry.Path, ":t"))
          local deleted_file_head = assert(vim.fn.fnamemodify(entry.Path, ":h"))
          local info_file_head = deleted_file_head
          --- @type string?
          local info_file
          cache_entry =
            cache.create_entry(url, deleted_file_tail, entry.IsFolder and "directory" or "file")
          -- info_file on windows has the following format: $I<6 char hash>.<extension>
          -- the hash is the same for the deleted file and the info file
          -- so, we take the hash (and extension) from the deleted file
          --
          -- see https://superuser.com/questions/368890/how-does-the-recycle-bin-in-windows-work/1736690#1736690
          local info_file_tail = deleted_file_tail:match("^%$R(.*)$") --[[@as string?]]
          if info_file_tail then
            info_file_tail = "$I" .. info_file_tail
            info_file = info_file_head .. "\\" .. info_file_tail
          end
          cache_entry[FIELD_META] = {
            stat = nil,
            ---@type oil.WindowsTrashInfo
            trash_info = {
              trash_file = entry.Path,
              original_path = entry.OriginalPath,
              deletion_date = entry.DeletionDate,
              info_file = info_file,
            },
            display_name = entry.Name,
          }
        end
        if path ~= parent and (show_all_files or fs.is_subpath(path, parent)) then
          local name = parent:sub(path:len() + 1)
          local next_par = vim.fs.dirname(name)
          while next_par ~= "." do
            name = next_par
            next_par = vim.fs.dirname(name)
            cache_entry = cache.create_entry(url, name, "directory")

            cache_entry[FIELD_META] = {}
          end
        end
        return cache_entry
      end,
      raw_displayed_entries
    )
    cb(nil, displayed_entries)
  end)
end

M.is_modifiable = function(_bufnr)
  return true
end

local current_year
-- Make sure we run this import-time effect in the main loop (mostly for tests)
vim.schedule(function()
  current_year = vim.fn.strftime("%Y")
end)

local file_columns = {}
file_columns.mtime = {
  render = function(entry, conf)
    local meta = entry[FIELD_META]
    if not meta then
      return nil
    end
    ---@type oil.WindowsTrashInfo
    local trash_info = meta.trash_info
    local time = trash_info and trash_info.deletion_date
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
    ---@type nil|oil.WindowsTrashInfo
    local trash_info = meta and meta.trash_info
    if trash_info and trash_info.deletion_date then
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

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  local scheme, path = util.parse_url(url)
  assert(path)
  local os_path = vim.fn.fnamemodify(fs.posix_to_os_path(path), ":p")
  assert(os_path)
  uv.fs_realpath(
    os_path,
    vim.schedule_wrap(function(_err, new_os_path)
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
  local meta = internal_entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.WindowsTrashInfo, display_name: string}]]
  local trash_info = meta and meta.trash_info
  if not trash_info then
    -- This is a subpath in the trash
    M.normalize_url(url, cb)
    return
  end

  local path = fs.os_to_posix_path(trash_info.trash_file)
  if entry.type == "directory" then
    path = win_addslash(path)
  end
  cb("oil://" .. path)
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
    ---@type oil.WindowsTrashInfo
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

---@param trash_info oil.WindowsTrashInfo
---@param cb fun(err?: string, raw_entries: oil.WindowsRawEntry[]?)
local purge = function(trash_info, cb)
  fs.recursive_delete("file", trash_info.info_file, function(err)
    if err then
      return cb(err)
    end
    fs.recursive_delete("file", trash_info.trash_file, cb)
  end)
end

---@param path string
---@param type string
---@param cb fun(err?: string, trash_info?: oil.TrashInfo)
local function create_trash_info_and_copy(path, type, cb)
  local temp_path = path .. "temp"
  -- create a temporary copy on the same location
  fs.recursive_copy(
    type,
    path,
    temp_path,
    vim.schedule_wrap(function(err)
      if err then
        return cb(err)
      end
      -- delete original file
      M.delete_to_trash(path, function(err2)
        if err2 then
          return cb(err2)
        end
        -- rename temporary copy to the original file name
        fs.recursive_move(type, temp_path, path, cb)
      end)
    end)
  )
end

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  if action.type == "delete" then
    local entry = assert(cache.get_entry_by_url(action.url))
    local meta = entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.WindowsTrashInfo, display_name: string}]]
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
      dest_path = fs.posix_to_os_path(dest_path)
      local entry = assert(cache.get_entry_by_url(action.src_url))
      local meta = entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.WindowsTrashInfo, display_name: string}]]
      local trash_info = meta and meta.trash_info
      fs.recursive_move(action.entry_type, trash_info.trash_file, dest_path, function(err)
        if err then
          return cb(err)
        end
        uv.fs_unlink(trash_info.info_file, cb)
      end)
    end
  elseif action.type == "copy" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if src_adapter.name == "files" then
      local _, path = util.parse_url(action.src_url)
      assert(path)
      path = fs.posix_to_os_path(path)
      local entry = assert(cache.get_entry_by_url(action.src_url))
      create_trash_info_and_copy(path, entry[FIELD_TYPE], cb)
    elseif dest_adapter.name == "files" then
      -- Restore
      local _, dest_path = util.parse_url(action.dest_url)
      assert(dest_path)
      dest_path = fs.posix_to_os_path(dest_path)
      local entry = assert(cache.get_entry_by_url(action.src_url))
      local meta = entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.WindowsTrashInfo, display_name: string}]]
      local trash_info = meta and meta.trash_info
      fs.recursive_copy(action.entry_type, trash_info.trash_file, dest_path, cb)
    else
      error("Must be moving files into or out of trash")
    end
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

M.supported_cross_adapter_actions = { files = "move" }

---@param path string
---@param cb fun(err?: string)
M.delete_to_trash = function(path, cb)
  powershell_trash.delete_to_trash(path, cb)
end

return M
