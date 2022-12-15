local cache = require("oil.cache")
local M = {}

---@param path string
---@param column_defs string[]
---@param cb fun(err: nil|string, entries: nil|oil.InternalEntry[])
M.list = function(url, column_defs, cb)
  cb(nil, cache.list_url(url))
end

---@param name string
---@return nil|oil.ColumnDefinition
M.get_column = function(name)
  return nil
end

---@param path string
---@param entry_type oil.EntryType
M.test_set = function(path, entry_type)
  local parent = vim.fn.fnamemodify(path, ":h")
  if parent ~= path then
    M.test_set(parent, "directory")
  end
  local url = "oil-test://" .. path
  if cache.get_entry_by_url(url) then
    -- Already exists
    return
  end
  local name = vim.fn.fnamemodify(path, ":t")
  cache.create_and_store_entry("oil-test://" .. parent, name, entry_type)
end

---@param bufnr integer
---@return boolean
M.is_modifiable = function(bufnr)
  return true
end

---@param url string
M.url_to_buffer_name = function(url)
  error("Test adapter cannot open files")
end

---@param action oil.Action
---@return string
M.render_action = function(action)
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
  cb()
end

return M
