local cache = require("oil.cache")
local M = {}

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  callback(url)
end

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, fetch_more?: fun())
M.list = function(url, column_defs, cb)
  cb()
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

---@param bufnr integer
M.read_file = function(bufnr)
  -- pass
end

---@param bufnr integer
M.write_file = function(bufnr)
  -- pass
end

return M
