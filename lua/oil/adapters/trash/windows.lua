local util = require("oil.util")
local uv = vim.uv or vim.loop
local cache = require("oil.cache")
local config = require("oil.config")
local constants = require("oil.constants")
local files = require("oil.adapters.files")
local fs = require("oil.fs")

local FIELD_META = constants.FIELD_META

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

---@class oil.WindowsRawEntry
---@field IsFolder boolean
---@field DeletionDate integer
---@field Name string
---@field Path string
---@field OriginalPath string

---@param cb fun(err?: string, raw_entries: oil.WindowsRawEntry[]?)
local get_raw_entries = function(cb)
  ---@type string?
  local stdout

  local jid = vim.fn.jobstart({
    "powershell",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-Command",
    -- The first line configures Windows Powershell to use UTF-8 for input and output
    -- 0xa is the constant for Recycle Bin. See https://learn.microsoft.com/en-us/windows/win32/api/shldisp/ne-shldisp-shellspecialfolderconstants
    [[
$OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
$shell = New-Object -ComObject 'Shell.Application'
$folder = $shell.NameSpace(0xa)
$data = @(foreach ($i in $folder.items())
    {
        @{
            IsFolder=$i.IsFolder;
            DeletionDate=([DateTimeOffset]$i.extendedproperty('datedeleted')).ToUnixTimeSeconds();
            Name=$i.Name;
            Path=$i.Path;
            OriginalPath=-join($i.ExtendedProperty('DeletedFrom'), "\", $i.Name)
        }
    })
ConvertTo-Json $data
]],
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      stdout = table.concat(data, "\n")
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        return cb("Error listing files on trash")
      end
      assert(stdout)
      local raw_entries = vim.json.decode(stdout)
      cb(nil, raw_entries)
    end,
  })
  if jid <= 0 then
    cb("Could not list windows devices")
  end
end

---@class oil.WindowsTrashInfo
---@field trash_file string?
---@field original_path string?
---@field deletion_date string?

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, cb)
  local _, path = util.parse_url(url)
  path = fs.posix_to_os_path(assert(path))

  local trash_dir = get_trash_dir()
  local show_all_files = fs.is_subpath(path, trash_dir)

  get_raw_entries(function(err, raw_entries)
    if err then
      cb(err)
      return
    end

    local entries = vim.tbl_map(
      ---@param entry {IsFolder: boolean, DeletionDate: integer, Name: string, Path: string, OriginalPath: string}
      ---@return {[1]:nil, [2]:string, [3]:string, [4]:{stat: uv_fs_t, trash_info: oil.WindowsTrashInfo, display_name: string}}
      function(entry)
        local parent = win_addslash(assert(vim.fn.fnamemodify(entry.OriginalPath, ":h")))

        --- @type oil.InternalEntry
        local cache_entry
        if path == parent or show_all_files then
          local unique_name = assert(vim.fn.fnamemodify(entry.Path, ":t"))
          cache_entry =
            cache.create_entry(url, unique_name, entry.IsFolder and "directory" or "file")
          cache_entry[FIELD_META] = {
            stat = nil,
            trash_info = {
              trash_file = entry.Path,
              original_path = entry.OriginalPath,
              deletion_date = entry.DeletionDate,
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
      raw_entries
    )
    cb(nil, entries)
  end)
end

M.is_modifiable = function(_bufnr)
  return true
end

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
    ---@type oil.WindowsTrashInfo
    local trash_info = meta.trash_info
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
    return meta.trash_info ~= nil
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
  local trash_info = meta.trash_info
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
    local trash_info = meta.trash_info
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

---@param path string
---@param cb fun(err?: string, raw_entries: oil.WindowsRawEntry[]?)
local purge = function(path, cb)
  local jid = vim.fn.jobstart({
    "powershell",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-Command",
    ([[
$path = Get-Item '%s'
Remove-Item $path -Recurse -Confirm:$false
]]):format(path:gsub("'", "''")),
  }, {
    on_exit = function(_, code)
      if code ~= 0 then
        return cb("Error purging file")
      end
      cb()
    end,
  })
  if jid <= 0 then
    cb("Could not purge item")
  end
end

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  if action.type == "delete" then
    local entry = assert(cache.get_entry_by_url(action.url))
    local meta = entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.WindowsTrashInfo, display_name: string}]]
    local trash_info = meta.trash_info

    purge(trash_info.trash_file, cb)
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
      local meta = entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.WindowsTrashInfo, display_name: string}]]
      local trash_info = meta.trash_info

      local jid = vim.fn.jobstart({
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        -- 0xa is the constant for Recycle Bin. See https://learn.microsoft.com/en-us/windows/win32/api/shldisp/ne-shldisp-shellspecialfolderconstants
        ([[
$path = Get-Item '%s'
$shell = New-Object -ComObject 'Shell.Application'
$folder = $shell.NameSpace(0xa)
$folder.ParseName($path.FullName).InvokeVerb('undelete')
]]):format(trash_info.trash_file),
      }, {
        stdout_buffered = true,
        on_exit = function(_, code)
          if code ~= 0 then
            return cb("Error restoring file")
          end
          cb()
        end,
      })
      if jid <= 0 then
        cb("Could not restore file")
      end
    end
  elseif action.type == "copy" then
    -- TODO: ...
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

M.supported_cross_adapter_actions = { files = "move" }

---@param path string
---@param cb fun(err?: string)
M.delete_to_trash = function(path, cb)
  local jid = vim.fn.jobstart({
    "powershell",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-Command",
    -- 0 is the constant for Windows Desktop. See https://learn.microsoft.com/en-us/windows/win32/api/shldisp/ne-shldisp-shellspecialfolderconstants
    ([[
$path = Get-Item '%s'
$shell = New-Object -ComObject 'Shell.Application'
$folder = $shell.NameSpace(0)
$folder.ParseName($path.FullName).InvokeVerb('delete')
]]):format(path:gsub("'", "''")),
  }, {
    stdout_buffered = true,
    on_exit = function(_, code)
      if code ~= 0 then
        return cb("Error sendig file to trash")
      end
      cb()
    end,
  })
  if jid <= 0 then
    cb("Could not list windows devices")
  end
end

return M
