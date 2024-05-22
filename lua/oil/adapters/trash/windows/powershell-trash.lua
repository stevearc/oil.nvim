-- A wrapper around trash operations using windows powershell
local Powershell = require("oil.adapters.trash.windows.powershell-connection")

---@class oil.WindowsRawEntry
---@field IsFolder boolean
---@field DeletionDate integer
---@field Name string
---@field Path string
---@field OriginalPath string

local M = {}

-- 0xa is the constant for Recycle Bin. See https://learn.microsoft.com/en-us/windows/win32/api/shldisp/ne-shldisp-shellspecialfolderconstants
local list_entries_init = [[
$shell = New-Object -ComObject 'Shell.Application'
$folder = $shell.NameSpace(0xa)
]]

local list_entries_cmd = [[
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
ConvertTo-Json $data -Compress
]]

---@type nil|oil.PowershellConnection
local list_entries_powershell

---@param cb fun(err?: string, raw_entries?: oil.WindowsRawEntry[])
M.list_raw_entries = function(cb)
  if not list_entries_powershell then
    list_entries_powershell = Powershell.new(list_entries_init)
  end
  list_entries_powershell:run(list_entries_cmd, function(err, string)
    if err then
      cb(err)
      return
    end

    local ok, value = pcall(vim.json.decode, string)
    if not ok then
      cb(value)
      return
    end
    cb(nil, value)
  end)
end

-- 0 is the constant for Windows Desktop. See https://learn.microsoft.com/en-us/windows/win32/api/shldisp/ne-shldisp-shellspecialfolderconstants
local delete_init = [[
$shell = New-Object -ComObject 'Shell.Application'
$folder = $shell.NameSpace(0)
]]
local delete_cmd = [[
$path = Get-Item '%s'
$folder.ParseName($path.FullName).InvokeVerb('delete')
]]

---@type nil|oil.PowershellConnection
local delete_to_trash_powershell

---@param path string
---@param cb fun(err?: string)
M.delete_to_trash = function(path, cb)
  if not delete_to_trash_powershell then
    delete_to_trash_powershell = Powershell.new(delete_init)
  end
  delete_to_trash_powershell:run((delete_cmd):format(path:gsub("'", "''")), cb)
end

return M
