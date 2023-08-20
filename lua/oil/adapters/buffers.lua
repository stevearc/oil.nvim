local cache = require("oil.cache")
local files = require("oil.adapters.files")
local util = require("oil.util")

local M = {}

---Convert an oil url to a shortened buffer name
---@param url string
---@return string?
local function url_to_bufname(url)
  local _, path = util.parse_url(url)
  if path then
    -- Trim off the leading "/"
    return path:sub(2)
  end
end

---
---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  -- If the url ends with a "/", normalize the url to oil-buffers:///
  if vim.endswith(url, "/") then
    local scheme, _ = util.parse_url(url)
    callback(assert(scheme) .. "/")
  else
    -- If the url doesn't end with a "/", then it is a buffer so normalize the url to the name of
    -- the buffer
    callback(url_to_bufname(url) or url)
  end
end

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, cb)
  local entries = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].buflisted then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if bufname ~= "" then
        local name = files.to_short_os_path(bufname)
        local entry = cache.create_entry(url, name, "file")
        table.insert(entries, entry)
      end
    end
  end
  cb(nil, entries)
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

---Render mutation actions in the action preview window
---@param action oil.Action
---@return string
M.render_action = function(action)
  if action.type == "create" or action.type == "delete" then
    local name = assert(url_to_bufname(action.url))
    return string.format("%s <buffer> %s", action.type:upper(), name)
  elseif action.type == "move" or action.type == "copy" then
    local src_name = assert(url_to_bufname(action.src_url))
    local dest_name = assert(url_to_bufname(action.dest_url))
    return string.format("  %s <buffer> %s -> %s", action.type:upper(), src_name, dest_name)
  else
    error("Bad action type")
  end
end

---Perform mutation actions
---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  if action.type == "create" then
    if action.entry_type == "file" then
      local name = assert(url_to_bufname(action.url))
      local bufnr = vim.fn.bufadd(name)
      vim.fn.bufload(bufnr)
      vim.bo[bufnr].buflisted = true
    end
    cb()
  elseif action.type == "delete" then
    local name = assert(url_to_bufname(action.url))
    local bufnr = vim.fn.bufadd(name)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    cb()
  elseif action.type == "move" then
    local src_name = assert(url_to_bufname(action.src_url))
    local dest_name = assert(url_to_bufname(action.dest_url))
    util.rename_buffer(src_name, dest_name)
    cb()
  elseif action.type == "copy" then
    local name = assert(url_to_bufname(action.src_url))
    local bufnr = vim.fn.bufadd(name)
    if vim.fn.bufloaded(bufnr) == 0 then
      vim.fn.bufload(bufnr)
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local dest_bufnr = vim.api.nvim_create_buf(true, false)
    local dest_name = assert(url_to_bufname(action.dest_url))
    vim.api.nvim_buf_set_name(dest_bufnr, dest_name)
    vim.api.nvim_buf_set_lines(dest_bufnr, 0, -1, true, lines)
    vim.bo[dest_bufnr].modified = false
    cb()
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

return M
