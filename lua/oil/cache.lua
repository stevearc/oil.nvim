local constants = require("oil.constants")
local util = require("oil.util")
local M = {}

local FIELD_ID = constants.FIELD_ID
local FIELD_NAME = constants.FIELD_NAME

local next_id = 1

-- Map<url, Map<entry name, oil.InternalEntry>>
---@type table<string, table<string, oil.InternalEntry>>
local url_directory = {}

---@type table<integer, oil.InternalEntry>
local entries_by_id = {}

---@type table<integer, string>
local parent_url_by_id = {}

-- Temporary map while a directory is being updated
local tmp_url_directory = {}

local _cached_id_fmt

---@param id integer
---@return string
M.format_id = function(id)
  if not _cached_id_fmt then
    local id_str_length = math.max(3, 1 + math.floor(math.log10(next_id)))
    _cached_id_fmt = "/%0" .. string.format("%d", id_str_length) .. "d"
  end
  return _cached_id_fmt:format(id)
end

M.clear_everything = function()
  next_id = 1
  url_directory = {}
  entries_by_id = {}
  parent_url_by_id = {}
end

---@param parent_url string
---@param name string
---@param type oil.EntryType
---@return oil.InternalEntry
M.create_entry = function(parent_url, name, type)
  parent_url = util.addslash(parent_url)
  local parent = tmp_url_directory[parent_url] or url_directory[parent_url]
  local entry
  if parent then
    entry = parent[name]
  end
  if entry then
    return entry
  end
  return { nil, name, type }
end

---@param parent_url string
---@param entry oil.InternalEntry
M.store_entry = function(parent_url, entry)
  parent_url = util.addslash(parent_url)
  local parent = url_directory[parent_url]
  if not parent then
    parent = {}
    url_directory[parent_url] = parent
  end
  local id = entry[FIELD_ID]
  if id == nil then
    id = next_id
    next_id = next_id + 1
    entry[FIELD_ID] = id
    _cached_id_fmt = nil
  end
  local name = entry[FIELD_NAME]
  parent[name] = entry
  local tmp_dir = tmp_url_directory[parent_url]
  if tmp_dir and tmp_dir[name] then
    tmp_dir[name] = nil
  end
  entries_by_id[id] = entry
  parent_url_by_id[id] = parent_url
end

---@param parent_url string
---@param name string
---@param type oil.EntryType
---@return oil.InternalEntry
M.create_and_store_entry = function(parent_url, name, type)
  local entry = M.create_entry(parent_url, name, type)
  M.store_entry(parent_url, entry)
  return entry
end

---@param parent_url string
M.begin_update_url = function(parent_url)
  parent_url = util.addslash(parent_url)
  tmp_url_directory[parent_url] = url_directory[parent_url]
  url_directory[parent_url] = {}
end

---@param parent_url string
M.end_update_url = function(parent_url)
  parent_url = util.addslash(parent_url)
  if not tmp_url_directory[parent_url] then
    return
  end
  for _, old_entry in pairs(tmp_url_directory[parent_url]) do
    local id = old_entry[FIELD_ID]
    parent_url_by_id[id] = nil
    entries_by_id[id] = nil
  end
  tmp_url_directory[parent_url] = nil
end

---@param id integer
---@return nil|oil.InternalEntry
M.get_entry_by_id = function(id)
  return entries_by_id[id]
end

---@param url string
---@return nil|oil.InternalEntry
M.get_entry_by_url = function(url)
  local scheme, path = util.parse_url(url)
  local parent_url = scheme .. vim.fn.fnamemodify(path, ":h")
  local basename = vim.fn.fnamemodify(path, ":t")
  return M.list_url(parent_url)[basename]
end

---@param id integer
---@return string
M.get_parent_url = function(id)
  local url = parent_url_by_id[id]
  if not url then
    error(string.format("Entry %d missing parent url", id))
  end
  return url
end

---@param url string
---@return table<string, oil.InternalEntry>
M.list_url = function(url)
  url = util.addslash(url)
  return url_directory[url] or {}
end

---@param action oil.Action
M.perform_action = function(action)
  if action.type == "create" then
    local scheme, path = util.parse_url(action.url)
    local parent_url = util.addslash(scheme .. vim.fn.fnamemodify(path, ":h"))
    local name = vim.fn.fnamemodify(path, ":t")
    M.create_and_store_entry(parent_url, name, action.entry_type)
  elseif action.type == "delete" then
    local scheme, path = util.parse_url(action.url)
    local parent_url = util.addslash(scheme .. vim.fn.fnamemodify(path, ":h"))
    local name = vim.fn.fnamemodify(path, ":t")
    local entry = url_directory[parent_url][name]
    url_directory[parent_url][name] = nil
    entries_by_id[entry[FIELD_ID]] = nil
    parent_url_by_id[entry[FIELD_ID]] = nil
  elseif action.type == "move" then
    local src_scheme, src_path = util.parse_url(action.src_url)
    local src_parent_url = util.addslash(src_scheme .. vim.fn.fnamemodify(src_path, ":h"))
    local src_name = vim.fn.fnamemodify(src_path, ":t")
    local entry = url_directory[src_parent_url][src_name]

    local dest_scheme, dest_path = util.parse_url(action.dest_url)
    local dest_parent_url = util.addslash(dest_scheme .. vim.fn.fnamemodify(dest_path, ":h"))
    local dest_name = vim.fn.fnamemodify(dest_path, ":t")

    url_directory[src_parent_url][src_name] = nil
    local dest_parent = url_directory[dest_parent_url]
    if not dest_parent then
      dest_parent = {}
      url_directory[dest_parent_url] = dest_parent
    end
    dest_parent[dest_name] = entry
    parent_url_by_id[entry[FIELD_ID]] = dest_parent_url
    entry[FIELD_NAME] = dest_name
    util.update_moved_buffers(action.entry_type, action.src_url, action.dest_url)
  elseif action.type == "copy" then
    local scheme, path = util.parse_url(action.dest_url)
    local parent_url = util.addslash(scheme .. vim.fn.fnamemodify(path, ":h"))
    local name = vim.fn.fnamemodify(path, ":t")
    M.create_and_store_entry(parent_url, name, action.entry_type)
  elseif action.type == "change" then
    -- Cache doesn't need to update
  else
    error(string.format("Bad action type: '%s'", action.type))
  end
end

return M
