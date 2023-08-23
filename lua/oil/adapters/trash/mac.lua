local cache = require("oil.cache")
local fs = require("oil.fs")
local util = require("oil.util")

local uv = vim.uv or vim.loop

local M = {}

local function touch_dir(path)
  uv.fs_mkdir(path, 448) -- 0700
end

---Gets the location of the home trash dir, creating it if necessary
---@return string
local function get_trash_dir()
  local trash_dir = fs.join(assert(uv.os_homedir()), ".Trash")
  touch_dir(trash_dir)
  return trash_dir
end

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  local scheme, path = util.parse_url(url)
  assert(path)
  callback(scheme .. "/")
end

---@param url string
---@param column_defs string[]
---@param cb fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, cb)
  cb = vim.schedule_wrap(cb)
  local _, path = util.parse_url(url)
  assert(path)
  local trash_dir = get_trash_dir()
  ---@diagnostic disable-next-line: param-type-mismatch
  uv.fs_opendir(trash_dir, function(open_err, fd)
    if open_err then
      if open_err:match("^ENOENT: no such file or directory") then
        -- If the directory doesn't exist, treat the list as a success. We will be able to traverse
        -- and edit a not-yet-existing directory.
        return cb()
      else
        return cb(open_err)
      end
    end
    local read_next
    read_next = function()
      uv.fs_readdir(fd, function(err, entries)
        if err then
          uv.fs_closedir(fd, function()
            cb(err)
          end)
          return
        elseif entries then
          local internal_entries = {}
          local poll = util.cb_collect(#entries, function(inner_err)
            if inner_err then
              cb(inner_err)
            else
              cb(nil, internal_entries, read_next)
            end
          end)

          for _, entry in ipairs(entries) do
            -- TODO: read .DS_Store and filter by original dir dir
            local cache_entry = cache.create_entry(url, entry.name, entry.type)
            table.insert(internal_entries, cache_entry)
            poll()
          end
        else
          uv.fs_closedir(fd, function(close_err)
            if close_err then
              cb(close_err)
            else
              cb()
            end
          end)
        end
      end)
    end
    read_next()
    ---@diagnostic disable-next-line: param-type-mismatch
  end, 10000)
end

---@param bufnr integer
---@return boolean
M.is_modifiable = function(bufnr)
  return true
end

---@param name string
---@return nil|oil.ColumnDefinition
M.get_column = function(name)
  return nil
end

M.supported_adapters_for_copy = { files = true }

---@param action oil.Action
---@return string
M.render_action = function(action)
  -- FIXME
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
  -- FIXME
  if action.type == "create" then
    cb(string.format("Creating files in trash is not supported: %s", action.url))
  elseif action.type == "delete" then
    -- FIXME how are we going to specify a unique path with just the url? We could dedupe the url
    -- like we are above, but then how to we recover the trash_info?
    cb()
  elseif action.type == "move" then
    cb()
  elseif action.type == "copy" then
    cb()
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

-- FIXME add keyboard shortcuts for this?

M.restore_file = function()
  -- FIXME
end

---@param path string
---@param cb fun(err?: string)
M.delete_to_trash = function(path, cb)
  -- FIXME
end

return M
