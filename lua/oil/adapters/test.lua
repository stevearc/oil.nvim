local cache = require("oil.cache")
local util = require("oil.util")
local M = {}

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  callback(url)
end

local dir_listing = {}

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, cb)
  local _, path = util.parse_url(url)
  local entries = dir_listing[path] or {}
  local cache_entries = {}
  for _, entry in ipairs(entries) do
    local cache_entry = cache.create_entry(url, entry.name, entry.entry_type)
    table.insert(cache_entries, cache_entry)
  end
  cb(nil, cache_entries)
end

M.test_clear = function()
  dir_listing = {}
end

---@param path string
---@param entry_type oil.EntryType
---@return oil.InternalEntry
M.test_set = function(path, entry_type)
  if path == "/" then
    return {}
  end
  local parent = vim.fn.fnamemodify(path, ":h")
  if parent ~= path then
    M.test_set(parent, "directory")
  end
  parent = util.addslash(parent)
  if not dir_listing[parent] then
    dir_listing[parent] = {}
  end
  local name = vim.fn.fnamemodify(path, ":t")
  local entry = {
    name = name,
    entry_type = entry_type,
  }
  table.insert(dir_listing[parent], entry)
  local parent_url = "oil-test://" .. parent
  return cache.create_and_store_entry(parent_url, entry.name, entry.entry_type)
end

---@param name string
---@return nil|oil.ColumnDefinition
M.get_column = function(name)
  return nil
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
