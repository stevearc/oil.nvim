-- Work in progress
local M = {}

-- ---@return string
-- local function get_trash_dir()
--   -- TODO permission issues when using the recycle bin. The folder gets created without
--   -- read/write perms, so all operations fail
--   local cwd = vim.fn.getcwd()
--   local trash_dir = cwd:sub(1, 3) .. "$Recycle.Bin"
--   if vim.fn.isdirectory(trash_dir) == 1 then
--     return trash_dir
--   end
--   trash_dir = "C:\\$Recycle.Bin"
--   if vim.fn.isdirectory(trash_dir) == 1 then
--     return trash_dir
--   end
--   error("No trash found")
-- end

---@param path string
---@param cb fun(err?: string)
M.delete_to_trash = function(path, cb)
  vim.system({
    "powershell",
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
    text = false,
  }, function(data)
    if data.stderr and data.stderr ~= "" then
      cb(data.stderr)
    else
      cb()
    end
  end)
end

return M
