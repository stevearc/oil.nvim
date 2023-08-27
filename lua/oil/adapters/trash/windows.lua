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

return M
