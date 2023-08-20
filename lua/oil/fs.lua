local M = {}

local uv = vim.uv or vim.loop

---@type boolean
M.is_windows = uv.os_uname().version:match("Windows")

M.is_mac = uv.os_uname().sysname == "Darwin"

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

---@param path string
---@return string
M.posix_to_os_path = function(path)
  if M.is_windows then
    if vim.startswith(path, "/") then
      local drive, rem = path:match("^/([^/]+)/(.*)$")
      return string.format("%s:\\%s", drive, rem:gsub("/", "\\"))
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
---@return string
M.shorten_path = function(path)
  local cwd = vim.fn.getcwd()
  if vim.startswith(path, cwd) then
    local relative = path:sub(cwd:len() + 2)
    if relative == "" then
      relative = "."
    end
    return relative
  end
  if vim.startswith(path, home_dir) then
    return "~" .. path:sub(home_dir:len() + 1)
  end
  return path
end

M.mkdirp = function(dir)
  local mod = ""
  local path = dir
  while vim.fn.isdirectory(path) == 0 do
    mod = mod .. ":h"
    path = vim.fn.fnamemodify(dir, mod)
  end
  while mod ~= "" do
    mod = mod:sub(3)
    path = vim.fn.fnamemodify(dir, mod)
    uv.fs_mkdir(path, 493)
  end
end

---@param dir string
---@param cb fun(err: nil|string, entries: nil|{type: oil.EntryType, name: string})
M.listdir = function(dir, cb)
  ---@diagnostic disable-next-line: param-type-mismatch
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
  end, 100) -- TODO do some testing for this
end

---@param entry_type oil.EntryType
---@param path string
---@param cb fun(err: nil|string)
M.recursive_delete = function(entry_type, path, cb)
  if entry_type ~= "directory" then
    return uv.fs_unlink(path, cb)
  end
  ---@diagnostic disable-next-line: param-type-mismatch
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
      ---@diagnostic disable-next-line: param-type-mismatch
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
      cb()
    end
  end)
end

return M
