local config = require("oil.config")
local fs = require("oil.fs")
local util = require("oil.util")

local M = {}

---@class oil.BufferCleanupOptions
---@field delete boolean
---@field move boolean
---@field force boolean

local function normalize_path(path)
  path = vim.fs.normalize(fs.abspath(path))
  if fs.is_windows then
    path = path:lower()
  end
  return path
end

local function get_local_paths_from_url(url)
  local scheme, path = util.parse_url(url)
  if not scheme or config.adapters[scheme] ~= "files" then
    return nil
  end
  assert(path)
  local os_path = fs.posix_to_os_path(path)
  return os_path, normalize_path(os_path)
end

local function get_local_paths_from_buf(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end
  local scheme, path = util.parse_url(name)
  if scheme and config.adapters[scheme] ~= "files" then
    return nil
  elseif scheme then
    assert(path)
    local os_path = fs.posix_to_os_path(path)
    return os_path, normalize_path(os_path)
  else
    return name, normalize_path(name)
  end
end

local function get_cleanup_opts()
  local cleanup = config.buffer_cleanup
  if cleanup == nil or cleanup == false then
    return nil
  end
  if cleanup == true then
    cleanup = { delete = true, move = true }
  end
  if type(cleanup) ~= "table" then
    return nil
  end
  local opts = {
    delete = not not cleanup.delete,
    move = not not cleanup.move,
    force = not not cleanup.force,
  }
  if not opts.delete and not opts.move then
    return nil
  end
  return opts
end

local function should_skip_buffer(bufnr)
  return not vim.api.nvim_buf_is_valid(bufnr)
    or vim.bo[bufnr].buftype ~= ""
    or vim.api.nvim_buf_get_name(bufnr) == ""
end

local function wipe_buffer(bufnr, opts)
  if should_skip_buffer(bufnr) then
    return
  end
  if not opts.force and vim.bo[bufnr].modified then
    return
  end
  local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = opts.force })
  if not ok then
    vim.notify_once(string.format("[oil] failed to delete buffer %d: %s", bufnr, err), vim.log.levels.WARN)
  end
end

local function handle_delete(action, opts)
  local os_path, normalized = get_local_paths_from_url(action.url)
  if os_path then
    local is_directory = action.entry_type == "directory"
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if should_skip_buffer(bufnr) then
        goto continue
      end
      local buf_os, buf_norm = get_local_paths_from_buf(bufnr)
      if not buf_os then
        goto continue
      end
      if is_directory then
        if fs.is_subpath(os_path, buf_os) then
          wipe_buffer(bufnr, opts)
        end
      else
        if buf_norm == normalized then
          wipe_buffer(bufnr, opts)
        end
      end
      ::continue::
    end
    return
  end

  local target = action.url
  local prefix = util.addslash(target)
  local is_directory = action.entry_type == "directory"
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if should_skip_buffer(bufnr) then
      goto continue
    end
    local name = vim.api.nvim_buf_get_name(bufnr)
    local scheme = util.parse_url(name)
    if not scheme or config.adapters[scheme] == "files" then
      goto continue
    end
    if is_directory then
      if vim.startswith(util.addslash(name), prefix) then
        wipe_buffer(bufnr, opts)
      end
    elseif name == target then
      wipe_buffer(bufnr, opts)
    end
    ::continue::
  end
end

local function reload_moved_buffer(action, opts)
  if not opts.move or action.entry_type ~= "file" then
    return
  end
  local dest_os, dest_norm = get_local_paths_from_url(action.dest_url)
  if not dest_os then
    return
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if should_skip_buffer(bufnr) then
      goto continue
    end
    local _, buf_norm = get_local_paths_from_buf(bufnr)
    if buf_norm and buf_norm == dest_norm then
      if opts.force or not vim.bo[bufnr].modified then
        pcall(vim.api.nvim_buf_call, bufnr, function()
          vim.cmd({ cmd = "edit", bang = opts.force })
        end)
      end
    end
    ::continue::
  end
end

---@param action oil.Action
M.handle_action = function(action)
  local opts = get_cleanup_opts()
  if not opts then
    return
  end
  if action.type == "delete" then
    handle_delete(action, opts)
  elseif action.type == "move" then
    reload_moved_buffer(action, opts)
  end
end

return M

