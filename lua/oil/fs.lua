local log = require("oil.log")
local M = {}

local uv = vim.uv or vim.loop

---@type boolean
M.is_windows = uv.os_uname().version:match("Windows")

M.is_mac = uv.os_uname().sysname == "Darwin"

M.is_linux = not M.is_windows and not M.is_mac

---@type string
M.sep = M.is_windows and "\\" or "/"

---@param ... string
M.join = function(...)
  return table.concat({ ... }, M.sep)
end

---Check if OS path is absolute
---@param dir string
---@return boolean
M.is_absolute = function(dir)
  if M.is_windows then
    return dir:match("^%a:\\")
  else
    return vim.startswith(dir, "/")
  end
end

M.abspath = function(path)
  if not M.is_absolute(path) then
    path = vim.fn.fnamemodify(path, ":p")
  end
  return path
end

---@param path string
---@param cb fun(err: nil|string)
M.touch = function(path, cb)
  uv.fs_open(path, "a", 420, function(err, fd) -- 0644
    if err then
      cb(err)
    else
      assert(fd)
      uv.fs_close(fd, cb)
    end
  end)
end

--- Returns true if candidate is a subpath of root, or if they are the same path.
---@param root string
---@param candidate string
---@return boolean
M.is_subpath = function(root, candidate)
  if candidate == "" then
    return false
  end
  root = vim.fs.normalize(M.abspath(root))
  -- Trim trailing "/" from the root
  if root:find("/", -1) then
    root = root:sub(1, -2)
  end
  candidate = vim.fs.normalize(M.abspath(candidate))
  if M.is_windows then
    root = root:lower()
    candidate = candidate:lower()
  end
  if root == candidate then
    return true
  end
  local prefix = candidate:sub(1, root:len())
  if prefix ~= root then
    return false
  end

  local candidate_starts_with_sep = candidate:find("/", root:len() + 1, true) == root:len() + 1
  local root_ends_with_sep = root:find("/", root:len(), true) == root:len()

  return candidate_starts_with_sep or root_ends_with_sep
end

---@param path string
---@return string
M.posix_to_os_path = function(path)
  if M.is_windows then
    if vim.startswith(path, "/") then
      local drive = path:match("^/(%a+)")
      local rem = path:sub(drive:len() + 2)
      return string.format("%s:%s", drive, rem:gsub("/", "\\"))
    else
      local newpath = path:gsub("/", "\\")
      return newpath
    end
  else
    return path
  end
end

---@param path string
---@return string
M.os_to_posix_path = function(path)
  if M.is_windows then
    if M.is_absolute(path) then
      local drive, rem = path:match("^([^:]+):\\(.*)$")
      return string.format("/%s/%s", drive:upper(), rem:gsub("\\", "/"))
    else
      local newpath = path:gsub("\\", "/")
      return newpath
    end
  else
    return path
  end
end

local home_dir = assert(uv.os_homedir())

---@param path string
---@param relative_to? string Shorten relative to this path (default cwd)
---@return string
M.shorten_path = function(path, relative_to)
  if not relative_to then
    relative_to = vim.fn.getcwd()
  end
  local relpath
  if M.is_subpath(relative_to, path) then
    local idx = relative_to:len() + 1
    -- Trim the dividing slash if it's not included in relative_to
    if not vim.endswith(relative_to, "/") and not vim.endswith(relative_to, "\\") then
      idx = idx + 1
    end
    relpath = path:sub(idx)
    if relpath == "" then
      relpath = "."
    end
  end
  if M.is_subpath(home_dir, path) then
    local homepath = "~" .. path:sub(home_dir:len() + 1)
    if not relpath or homepath:len() < relpath:len() then
      return homepath
    end
  end
  return relpath or path
end

---@param dir string
---@param mode? integer
M.mkdirp = function(dir, mode)
  mode = mode or 493
  local mod = ""
  local path = dir
  while vim.fn.isdirectory(path) == 0 do
    mod = mod .. ":h"
    path = vim.fn.fnamemodify(dir, mod)
  end
  while mod ~= "" do
    mod = mod:sub(3)
    path = vim.fn.fnamemodify(dir, mod)
    uv.fs_mkdir(path, mode)
  end
end

---@param dir string
---@param cb fun(err: nil|string, entries: nil|{type: oil.EntryType, name: string})
M.listdir = function(dir, cb)
  ---@diagnostic disable-next-line: param-type-mismatch, discard-returns
  uv.fs_opendir(dir, function(open_err, fd)
    if open_err then
      return cb(open_err)
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
          ---@diagnostic disable-next-line: param-type-mismatch
          cb(nil, entries)
          read_next()
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

---@param entry_type oil.EntryType
---@param path string
---@param cb fun(err: nil|string)
M.recursive_delete = function(entry_type, path, cb)
  if entry_type ~= "directory" then
    return uv.fs_unlink(path, cb)
  end
  ---@diagnostic disable-next-line: param-type-mismatch, discard-returns
  uv.fs_opendir(path, function(open_err, fd)
    if open_err then
      return cb(open_err)
    end
    local poll
    poll = function(inner_cb)
      uv.fs_readdir(fd, function(err, entries)
        if err then
          return inner_cb(err)
        elseif entries then
          local waiting = #entries
          local complete
          complete = function(err2)
            if err then
              complete = function() end
              return inner_cb(err2)
            end
            waiting = waiting - 1
            if waiting == 0 then
              poll(inner_cb)
            end
          end
          for _, entry in ipairs(entries) do
            M.recursive_delete(entry.type, path .. M.sep .. entry.name, complete)
          end
        else
          inner_cb()
        end
      end)
    end
    poll(function(err)
      uv.fs_closedir(fd)
      if err then
        return cb(err)
      end
      uv.fs_rmdir(path, cb)
    end)
    ---@diagnostic disable-next-line: param-type-mismatch
  end, 10000)
end

---Move the undofile for the file at src_path to dest_path
---@param src_path string
---@param dest_path string
---@param copy boolean
local move_undofile = vim.schedule_wrap(function(src_path, dest_path, copy)
  local undofile = vim.fn.undofile(src_path)
  uv.fs_stat(
    undofile,
    vim.schedule_wrap(function(stat_err)
      if stat_err then
        -- undofile doesn't exist
        return
      end
      local dest_undofile = vim.fn.undofile(dest_path)
      if copy then
        uv.fs_copyfile(src_path, dest_path, function(err)
          if err then
            log.warn("Error copying undofile %s: %s", undofile, err)
          end
        end)
      else
        uv.fs_rename(undofile, dest_undofile, function(err)
          if err then
            log.warn("Error moving undofile %s: %s", undofile, err)
          end
        end)
      end
    end)
  )
end)

---@param entry_type oil.EntryType
---@param src_path string
---@param dest_path string
---@param cb fun(err: nil|string)
M.recursive_copy = function(entry_type, src_path, dest_path, cb)
  if entry_type == "link" then
    uv.fs_readlink(src_path, function(link_err, link)
      if link_err then
        return cb(link_err)
      end
      assert(link)
      uv.fs_symlink(link, dest_path, 0, cb)
    end)
    return
  end
  if entry_type ~= "directory" then
    uv.fs_copyfile(src_path, dest_path, { excl = true }, cb)
    move_undofile(src_path, dest_path, true)
    return
  end
  uv.fs_stat(src_path, function(stat_err, src_stat)
    if stat_err then
      return cb(stat_err)
    end
    assert(src_stat)
    uv.fs_mkdir(dest_path, src_stat.mode, function(mkdir_err)
      if mkdir_err then
        return cb(mkdir_err)
      end
      ---@diagnostic disable-next-line: param-type-mismatch, discard-returns
      uv.fs_opendir(src_path, function(open_err, fd)
        if open_err then
          return cb(open_err)
        end
        local poll
        poll = function(inner_cb)
          uv.fs_readdir(fd, function(err, entries)
            if err then
              return inner_cb(err)
            elseif entries then
              local waiting = #entries
              local complete
              complete = function(err2)
                if err then
                  complete = function() end
                  return inner_cb(err2)
                end
                waiting = waiting - 1
                if waiting == 0 then
                  poll(inner_cb)
                end
              end
              for _, entry in ipairs(entries) do
                M.recursive_copy(
                  entry.type,
                  src_path .. M.sep .. entry.name,
                  dest_path .. M.sep .. entry.name,
                  complete
                )
              end
            else
              inner_cb()
            end
          end)
        end
        poll(cb)
        ---@diagnostic disable-next-line: param-type-mismatch
      end, 10000)
    end)
  end)
end

---@param entry_type oil.EntryType
---@param src_path string
---@param dest_path string
---@param cb fun(err: nil|string)
M.recursive_move = function(entry_type, src_path, dest_path, cb)
  uv.fs_rename(src_path, dest_path, function(err)
    if err then
      -- fs_rename fails for cross-partition or cross-device operations.
      -- We then fall back to a copy + delete
      M.recursive_copy(entry_type, src_path, dest_path, function(err2)
        if err2 then
          cb(err2)
        else
          M.recursive_delete(entry_type, src_path, cb)
        end
      end)
    else
      if entry_type ~= "directory" then
        move_undofile(src_path, dest_path, false)
      end
      cb()
    end
  end)
end

return M
