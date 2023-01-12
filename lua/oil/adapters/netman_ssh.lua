local cache = require("oil.cache")
local netman = require("netman")
local pathutil = require("oil.pathutil")
local util = require("oil.util")
local FIELD = require("oil.constants").FIELD
local M = {}

---@param oil_url string
---@return oil.sshUrl
local function parse_url(oil_url)
  local scheme, url = util.parse_url(oil_url)
  local ret = { scheme = scheme }
  local username, rem = url:match("^([^@%s]+)@(.*)$")
  ret.user = username
  url = rem or url
  local host, port, path = url:match("^([^:]+):(%d+)//?(.*)$")
  if host then
    ret.host = host
    ret.port = tonumber(port)
    ret.path = path
  else
    host, path = url:match("^([^/]+)//?(.*)$")
    ret.host = host
    ret.path = path
  end
  if not ret.host or not ret.path then
    error(string.format("Malformed SSH url: %s", oil_url))
  end

  return ret
end

---@param url oil.sshUrl
---@return string
local function url_to_str(url)
  local pieces = { url.scheme }
  if url.user then
    table.insert(pieces, url.user)
    table.insert(pieces, "@")
  end
  table.insert(pieces, url.host)
  if url.port then
    table.insert(pieces, string.format(":%d", url.port))
  end
  table.insert(pieces, "/")
  if vim.startswith(url.path, "/") then
    table.insert(pieces, "/")
  end
  table.insert(pieces, url.path)
  return table.concat(pieces, "")
end

---@param name string
---@return nil|oil.ColumnDefinition
M.get_column = function(name)
  -- TODO
  return nil
end

---@param bufname string
---@return string
M.get_parent = function(bufname)
  local res = parse_url(bufname)
  res.path = pathutil.parent(res.path)
  return url_to_str(res)
end

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  -- TODO
  callback(url)
end

local TYPE_MAP = setmetatable({
  ["regular file"] = "file",
}, {
  __index = function(_, k)
    return k
  end,
})

---@param url string
---@param column_defs string[]
---@param callback fun(err: nil|string, entries: nil|oil.InternalEntry[])
M.list = function(url, column_defs, callback)
  local _, hostpath = util.parse_url(url)
  local netman_url = "scp://" .. hostpath
  cache.begin_update_url(url)
  local res = netman.api.read(netman_url)
  if res.success and res.type == "EXPLORE" then
    for _, entry in ipairs(res.data) do
      local cache_entry = cache.create_entry(url, entry.NAME, TYPE_MAP[entry.METADATA.TYPE])
      cache_entry[FIELD.meta] = entry.METADATA
      cache.store_entry(url, cache_entry)
    end
    callback()
    cache.end_update_url(url)
  else
    cache.end_update_url(url)
    callback("Unknown error")
  end
end

---@param bufnr integer
---@return boolean
M.is_modifiable = function(bufnr)
  -- TODO
  return false
end

---@param url string
M.url_to_buffer_name = function(url)
  local parsed = parse_url(url)
  local pieces = { "scp://" }
  if parsed.user then
    table.insert(pieces, parsed.user)
    table.insert(pieces, "@")
  end
  table.insert(pieces, parsed.host)
  if parsed.port then
    table.insert(pieces, string.format(":%d", parsed.port))
  end
  table.insert(pieces, "/")
  if vim.startswith(parsed.path, "/") then
    table.insert(pieces, "/")
  end
  table.insert(pieces, parsed.path)
  return table.concat(pieces, "")
end

---@param action oil.Action
---@return string
M.render_action = function(action)
  -- TODO
end

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  -- TODO
  cb("Not implemented")
end

-- TODO
M.supports_xfer = {}

return M
