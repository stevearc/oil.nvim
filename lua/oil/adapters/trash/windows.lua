local util = require("oil.util")
local uv = vim.uv or vim.loop
local cache = require("oil.cache")
local config = require("oil.config")
local constants = require("oil.constants")
local files = require("oil.adapters.files")
local fs = require("oil.fs")

local FIELD_META = constants.FIELD_META

local powershell_date_grammar
if vim.fn.has("nvim-0.10") == 1 then
  local P, R, V = vim.lpeg.P, vim.lpeg.R, vim.lpeg.V

  powershell_date_grammar = P({
    "date",
    delimiter = P("/"),
    date = V("delimiter") * P("Date(") * (R("09") ^ 1 / tonumber) * P(")") * V("delimiter"),
  })
else
  powershell_date_grammar = {
    ---@param input string
    ---@return integer?
    match = function(self, input)
      return tonumber(input:match("/Date%((%d+)%)/"))
    end,
  }
end

-- Work in progress
local M = {}

---@param line string
---@return string
local remove_cr = function(line)
  local result = line:gsub("\r", "")
  return result
end

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, cb)
  local _, path = util.parse_url(url)
  assert(path)

  ---@type string?
  local stdout

  local jid = vim.fn.jobstart({
    "powershell",
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-Command",
    [[
$shell = New-Object -ComObject 'Shell.Application'
$folder = $shell.NameSpace(0xa)
$data = @(foreach ($i in $folder.items())
    {
        @{
            IsFolder=$i.IsFolder;
            ModifyDate=$i.ModifyDate;Name=$i.Name;
            Path=$i.Path;
            OriginalPath=-join($i.ExtendedProperty('DeletedFrom'), "\", $i.Name)
        }
    })
ConvertTo-Json $data
]],
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      stdout = table.concat(vim.tbl_map(remove_cr, data), "\n")
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        return cb("Error listing files on trash")
      end
      assert(stdout)
      local raw_entries = vim.json.decode(stdout)
      local entries = vim.tbl_map(
        ---@param entry {IsFolder: boolean, ModifyDate: string, Name: string, Path: string, OriginalPath: string}
        ---@return {[1]:nil, [2]:string, [3]:string, [4]:{stat: uv_fs_t, trash_info: oil.TrashInfo, display_name: string}}
        function(entry)
          local cache_entry =
            cache.create_entry(url, entry.Name, entry.IsFolder and "directory" or "file")
          cache_entry[FIELD_META] = {
            stat = nil,
            trash_info = {
              trash_file = entry.Path,
              info_file = nil,
              original_path = entry.OriginalPath,
              deletion_date = powershell_date_grammar:match(entry.ModifyDate),
              stat = nil,
            },
            display_name = entry.Name,
          }
          return cache_entry
        end,
        raw_entries
      )
      cb(nil, entries)
    end,
  })
  if jid <= 0 then
    cb("Could not list windows devices")
  end
end

--TODO: is this ok?
M.is_modifiable = function(_bufnr)
  return true
end

-- TODO: do something similar?
-- local file_columns = {}
-- file_columns.mtime = {
--   render = function(entry, conf)
--     local meta = entry[FIELD_META]
--     if not meta then
--       return nil
--     end
--     ---@type oil.TrashInfo
--     local trash_info = meta.trash_info
--     local time = trash_info and trash_info.deletion_date or meta.stat and meta.stat.mtime.sec
--     if not time then
--       return nil
--     end
--     local fmt = conf and conf.format
--     local ret
--     if fmt then
--       ret = vim.fn.strftime(fmt, time)
--     else
--       local year = vim.fn.strftime("%Y", time)
--       if year ~= current_year then
--         ret = vim.fn.strftime("%b %d %Y", time)
--       else
--         ret = vim.fn.strftime("%b %d %H:%M", time)
--       end
--     end
--     return ret
--   end,

--TODO: is this ok?
---@param name string
---@return nil|oil.ColumnDefinition
M.get_column = function(name)
  return nil
end

--TODO: is this ok?
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
  local meta = internal_entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.TrashInfo, display_name: string}]]
  local trash_info = meta.trash_info

  local path = fs.os_to_posix_path(trash_info.trash_file)
  if entry.type == "directory" then
    path = util.addslash(path)
  end
  cb("oil://" .. path)
end

--TODO: is this ok?
---@param action oil.Action
---@return string
M.render_action = function(action)
  if action.type == "delete" then
    local entry = assert(cache.get_entry_by_url(action.url))
    local meta = entry[FIELD_META]
    ---@type oil.TrashInfo
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

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  if action.type == "create" then
    -- TODO: do nothing?
  elseif action.type == "delete" then
    local entry = assert(cache.get_entry_by_url(action.url))
    local meta = entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.TrashInfo, display_name: string}]]
    local trash_info = meta.trash_info

    local jid = vim.fn.jobstart({
      "powershell",
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-Command",
      ([[
$path = Get-Item '%s'
Remove-Item $path -Recurse -Confirm:$false
]]):format(trash_info.trash_file),
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
      local meta = entry[FIELD_META] --[[@as {stat: uv_fs_t, trash_info: oil.TrashInfo, display_name: string}]]
      local trash_info = meta.trash_info

      local jid = vim.fn.jobstart({
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
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
    ([[
$path = Get-Item '%s'
$shell = New-Object -ComObject 'Shell.Application'
$folder = $shell.NameSpace(0)
$folder.ParseName($path.FullName).InvokeVerb('delete')
]]):format(path),
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
