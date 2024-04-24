-- integration with git operations
local fs = require("oil.fs")

local M = {}

---@param path string
---@return string|nil
M.get_root = function(path)
  local git_dir = vim.fs.find(".git", { upward = true, path = path })[1]
  if git_dir then
    return vim.fs.dirname(git_dir)
  else
    return nil
  end
end

---@param path string
---@param cb fun(err: nil|string)
M.add = function(path, cb)
  local root = M.get_root(path)
  if not root then
    return cb()
  end

  local stderr = ""
  local jid = vim.fn.jobstart({ "git", "add", path }, {
    cwd = root,
    stderr_buffered = true,
    on_stderr = function(_, data)
      stderr = table.concat(data, "\n")
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        cb("Error in git add: " .. stderr)
      else
        cb()
      end
    end,
  })
  if jid <= 0 then
    cb()
  end
end

---@param path string
---@param cb fun(err: nil|string)
M.rm = function(path, cb)
  local root = M.get_root(path)
  if not root then
    return cb()
  end

  local stderr = ""
  local jid = vim.fn.jobstart({ "git", "rm", "-r", path }, {
    cwd = root,
    stderr_buffered = true,
    on_stderr = function(_, data)
      stderr = table.concat(data, "\n")
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        stderr = vim.trim(stderr)
        if stderr:match("^fatal: pathspec '.*' did not match any files$") then
          cb()
        else
          cb("Error in git rm: " .. stderr)
        end
      else
        cb()
      end
    end,
  })
  if jid <= 0 then
    cb()
  end
end

---@param entry_type oil.EntryType
---@param src_path string
---@param dest_path string
---@param cb fun(err: nil|string)
M.mv = function(entry_type, src_path, dest_path, cb)
  local src_git = M.get_root(src_path)
  if not src_git or src_git ~= M.get_root(dest_path) then
    fs.recursive_move(entry_type, src_path, dest_path, cb)
    return
  end

  local stderr = ""
  local jid = vim.fn.jobstart({ "git", "mv", src_path, dest_path }, {
    cwd = src_git,
    stderr_buffered = true,
    on_stderr = function(_, data)
      stderr = table.concat(data, "\n")
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        stderr = vim.trim(stderr)
        if
          stderr:match("^fatal: not under version control")
          or stderr:match("^fatal: source directory is empty")
        then
          fs.recursive_move(entry_type, src_path, dest_path, cb)
        else
          cb("Error in git mv: " .. stderr)
        end
      else
        cb()
      end
    end,
  })
  if jid <= 0 then
    -- Failed to run git, fall back to normal filesystem operations
    fs.recursive_move(entry_type, src_path, dest_path, cb)
  end
end

return M
