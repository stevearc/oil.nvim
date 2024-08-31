local util = require("oil.util")

---@class (exact) oil.Trie
---@field new fun(): oil.Trie
---@field private root table
local Trie = {}

---@return oil.Trie
Trie.new = function()
  ---@type oil.Trie
  return setmetatable({
    root = { values = {}, children = {} },
  }, {
    __index = Trie,
  })
end

---@param url string
---@return string[]
function Trie:_url_to_path_pieces(url)
  local scheme, path = util.parse_url(url)
  assert(path)
  local pieces = vim.split(path, "/")
  table.insert(pieces, 1, scheme)
  return pieces
end

---@param url string
---@param value any
function Trie:insert_action(url, value)
  local pieces = self:_url_to_path_pieces(url)
  self:insert(pieces, value)
end

---@param url string
---@param value any
function Trie:remove_action(url, value)
  local pieces = self:_url_to_path_pieces(url)
  self:remove(pieces, value)
end

---@param path_pieces string[]
---@param value any
function Trie:insert(path_pieces, value)
  local current = self.root
  for _, piece in ipairs(path_pieces) do
    local next_container = current.children[piece]
    if not next_container then
      next_container = { values = {}, children = {} }
      current.children[piece] = next_container
    end
    current = next_container
  end
  table.insert(current.values, value)
end

---@param path_pieces string[]
---@param value any
function Trie:remove(path_pieces, value)
  local current = self.root
  for _, piece in ipairs(path_pieces) do
    local next_container = current.children[piece]
    if not next_container then
      next_container = { values = {}, children = {} }
      current.children[piece] = next_container
    end
    current = next_container
  end
  for i, v in ipairs(current.values) do
    if v == value then
      table.remove(current.values, i)
      -- if vim.tbl_isempty(current.values) and vim.tbl_isempty(current.children) then
      --   TODO remove container from trie
      -- end
      return
    end
  end
  error("Value not present in trie: " .. vim.inspect(value))
end

---Add the first action that affects a parent path of the url
---@param url string
---@param ret oil.InternalEntry[]
function Trie:accum_first_parents_of(url, ret)
  local pieces = self:_url_to_path_pieces(url)
  local containers = { self.root }
  for _, piece in ipairs(pieces) do
    local next_container = containers[#containers].children[piece]
    table.insert(containers, next_container)
  end
  table.remove(containers)
  while not vim.tbl_isempty(containers) do
    local container = containers[#containers]
    if not vim.tbl_isempty(container.values) then
      vim.list_extend(ret, container.values)
      break
    end
    table.remove(containers)
  end
end

---Do a depth-first-search and add all children matching the filter
function Trie:_dfs(container, ret, filter)
  if filter then
    for _, action in ipairs(container.values) do
      if filter(action) then
        table.insert(ret, action)
      end
    end
  else
    vim.list_extend(ret, container.values)
  end
  for _, child in ipairs(container.children) do
    self:_dfs(child, ret)
  end
end

---Add all actions affecting children of the url
---@param url string
---@param ret oil.InternalEntry[]
---@param filter nil|fun(entry: oil.Action): boolean
function Trie:accum_children_of(url, ret, filter)
  local pieces = self:_url_to_path_pieces(url)
  local current = self.root
  for _, piece in ipairs(pieces) do
    current = current.children[piece]
    if not current then
      return
    end
  end
  if current then
    for _, child in pairs(current.children) do
      self:_dfs(child, ret, filter)
    end
  end
end

---Add all actions at a specific path
---@param url string
---@param ret oil.InternalEntry[]
---@param filter? fun(entry: oil.Action): boolean
function Trie:accum_actions_at(url, ret, filter)
  local pieces = self:_url_to_path_pieces(url)
  local current = self.root
  for _, piece in ipairs(pieces) do
    current = current.children[piece]
    if not current then
      return
    end
  end
  if current then
    for _, action in ipairs(current.values) do
      if not filter or filter(action) then
        table.insert(ret, action)
      end
    end
  end
end

return Trie
