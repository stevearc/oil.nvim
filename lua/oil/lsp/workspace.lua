local fs = require("oil.fs")
local ms = require("vim.lsp.protocol").Methods
if vim.fn.has("nvim-0.10") == 0 then
  ms = {
    workspace_willCreateFiles = "workspace/willCreateFiles",
    workspace_didCreateFiles = "workspace/didCreateFiles",
    workspace_willDeleteFiles = "workspace/willDeleteFiles",
    workspace_didDeleteFiles = "workspace/didDeleteFiles",
    workspace_willRenameFiles = "workspace/willRenameFiles",
    workspace_didRenameFiles = "workspace/didRenameFiles",
  }
end

local M = {}

---@param method string
---@return vim.lsp.Client[]
local function get_clients(method)
  if vim.fn.has("nvim-0.10") == 1 then
    return vim.lsp.get_clients({ method = method })
  else
    ---@diagnostic disable-next-line: deprecated
    local clients = vim.lsp.get_active_clients()
    return vim.tbl_filter(function(client)
      return client.supports_method(method)
    end, clients)
  end
end

---@param glob string|vim.lpeg.Pattern
---@param path string
---@return boolean
local function match_glob(glob, path)
  -- nvim-0.10 will have vim.glob.to_lpeg, so this will be a LPeg pattern
  if type(glob) ~= "string" then
    return glob:match(path) ~= nil
  end

  -- older versions fall back to glob2regpat
  local pat = vim.fn.glob2regpat(glob)
  local ignorecase = vim.o.ignorecase
  vim.o.ignorecase = false
  local ok, match = pcall(vim.fn.match, path, pat)
  vim.o.ignorecase = ignorecase
  if not ok then
    error(match)
  end
  return match >= 0
end

---@param client vim.lsp.Client
---@param filters nil|lsp.FileOperationFilter[]
---@param paths string[]
---@return nil|string[]
local function get_matching_paths(client, filters, paths)
  if not filters then
    return nil
  end

  local match_fns = {}
  for _, filter in ipairs(filters) do
    if filter.scheme == nil or filter.scheme == "file" then
      local pattern = filter.pattern
      local glob = pattern.glob
      local ignore_case = pattern.options and pattern.options.ignoreCase
      if ignore_case then
        glob = glob:lower()
      end

      -- Some language servers use forward slashes as path separators on Windows (LuaLS)
      -- We no longer need this after 0.12: https://github.com/neovim/neovim/commit/322a6d305d088420b23071c227af07b7c1beb41a
      if vim.fn.has("nvim-0.12") == 0 and fs.is_windows then
        glob = glob:gsub("/", "\\")
      end

      ---@type string|vim.lpeg.Pattern
      local glob_to_match = glob
      if vim.glob and vim.glob.to_lpeg then
        -- HACK around https://github.com/neovim/neovim/issues/28931
        -- find alternations and sort them by length to try to match the longest first
        if vim.fn.has("nvim-0.11") == 0 then
          glob = glob:gsub("{(.*)}", function(s)
            local pieces = vim.split(s, ",")
            table.sort(pieces, function(a, b)
              return a:len() > b:len()
            end)
            return "{" .. table.concat(pieces, ",") .. "}"
          end)
        end

        glob_to_match = vim.glob.to_lpeg(glob)
      end
      local matches = pattern.matches
      table.insert(match_fns, function(path)
        local is_dir = vim.fn.isdirectory(path) == 1
        if matches and ((matches == "file" and is_dir) or (matches == "folder" and not is_dir)) then
          return false
        end

        if ignore_case then
          path = path:lower()
        end
        return match_glob(glob_to_match, path)
      end)
    end
  end
  local function match_any_pattern(workspace, path)
    local relative_path = path:sub(workspace:len() + 2)
    for _, match_fn in ipairs(match_fns) do
      -- The glob pattern might be relative to workspace OR absolute
      if match_fn(relative_path) or match_fn(path) then
        return true
      end
    end
    return false
  end

  local workspace_folders = vim.tbl_map(function(folder)
    return vim.uri_to_fname(folder.uri)
  end, client.workspace_folders or {})
  local function get_matching_workspace(path)
    for _, workspace in ipairs(workspace_folders) do
      if fs.is_subpath(workspace, path) then
        return workspace
      end
    end
  end

  local ret = {}
  for _, path in ipairs(paths) do
    local workspace = get_matching_workspace(path)
    if workspace and match_any_pattern(workspace, path) then
      table.insert(ret, path)
    end
  end
  if vim.tbl_isempty(ret) then
    return nil
  else
    return ret
  end
end

---@param method string The method to call
---@param capability_name string The name of the fileOperations server capability
---@param files string[] The files and folders that will be created
---@param options table|nil
---@return nil|{edit: lsp.WorkspaceEdit, offset_encoding: string}[]
---@return nil|string|lsp.ResponseError err
local function will_file_operation(method, capability_name, files, options)
  options = options or {}
  local clients = get_clients(method)

  local edits = {}
  for _, client in ipairs(clients) do
    local filters = vim.tbl_get(
      client.server_capabilities,
      "workspace",
      "fileOperations",
      capability_name,
      "filters"
    )
    local matching_files = get_matching_paths(client, filters, files)
    if matching_files then
      local params = {
        files = vim.tbl_map(function(file)
          return {
            uri = vim.uri_from_fname(file),
          }
        end, matching_files),
      }
      local result, err
      if vim.fn.has("nvim-0.11") == 1 then
        result, err = client:request_sync(method, params, options.timeout_ms or 1000, 0)
      else
        ---@diagnostic disable-next-line: param-type-mismatch
        result, err = client.request_sync(method, params, options.timeout_ms or 1000, 0)
      end
      if result and result.result then
        if options.apply_edits ~= false then
          vim.lsp.util.apply_workspace_edit(result.result, client.offset_encoding)
        end
        table.insert(edits, { edit = result.result, offset_encoding = client.offset_encoding })
      else
        return nil, err or result and result.err
      end
    end
  end
  return edits
end

---@param method string The method to call
---@param capability_name string The name of the fileOperations server capability
---@param files string[] The files and folders that will be created
local function did_file_operation(method, capability_name, files)
  local clients = get_clients(method)
  for _, client in ipairs(clients) do
    local filters = vim.tbl_get(
      client.server_capabilities,
      "workspace",
      "fileOperations",
      capability_name,
      "filters"
    )
    local matching_files = get_matching_paths(client, filters, files)
    if matching_files then
      local params = {
        files = vim.tbl_map(function(file)
          return {
            uri = vim.uri_from_fname(file),
          }
        end, matching_files),
      }
      if vim.fn.has("nvim-0.11") == 1 then
        client:notify(method, params)
      else
        ---@diagnostic disable-next-line: param-type-mismatch
        client.notify(method, params)
      end
    end
  end
end

--- Notify the server that the client is about to create files.
---@param files string[] The files and folders that will be created
---@param options table|nil Optional table which holds the following optional fields:
---    - timeout_ms (integer|nil, default 1000):
---        Time in milliseconds to block for rename requests.
---    - apply_edits (boolean|nil, default true):
---        Apply any workspace edits from these file operations.
---@return nil|{edit: lsp.WorkspaceEdit, offset_encoding: string}[]
---@return nil|string|lsp.ResponseError err
function M.will_create_files(files, options)
  return will_file_operation(ms.workspace_willCreateFiles, "willCreate", files, options)
end

--- Notify the server that files were created from within the client.
---@param files string[] The files and folders that will be created
function M.did_create_files(files)
  did_file_operation(ms.workspace_didCreateFiles, "didCreate", files)
end

--- Notify the server that the client is about to delete files.
---@param files string[] The files and folders that will be deleted
---@param options table|nil Optional table which holds the following optional fields:
---    - timeout_ms (integer|nil, default 1000):
---        Time in milliseconds to block for rename requests.
---    - apply_edits (boolean|nil, default true):
---        Apply any workspace edits from these file operations.
---@return nil|{edit: lsp.WorkspaceEdit, offset_encoding: string}[]
---@return nil|string|lsp.ResponseError err
function M.will_delete_files(files, options)
  return will_file_operation(ms.workspace_willDeleteFiles, "willDelete", files, options)
end

--- Notify the server that files were deleted from within the client.
---@param files string[] The files and folders that were deleted
function M.did_delete_files(files)
  did_file_operation(ms.workspace_didDeleteFiles, "didDelete", files)
end

--- Notify the server that the client is about to rename files.
---@param files table<string, string> Mapping of old_path -> new_path
---@param options table|nil Optional table which holds the following optional fields:
---    - timeout_ms (integer|nil, default 1000):
---        Time in milliseconds to block for rename requests.
---    - apply_edits (boolean|nil, default true):
---        Apply any workspace edits from these file operations.
---@return nil|{edit: lsp.WorkspaceEdit, offset_encoding: string}[]
---@return nil|string|lsp.ResponseError err
function M.will_rename_files(files, options)
  options = options or {}
  local clients = get_clients(ms.workspace_willRenameFiles)

  local edits = {}
  for _, client in ipairs(clients) do
    local filters = vim.tbl_get(
      client.server_capabilities,
      "workspace",
      "fileOperations",
      "willRename",
      "filters"
    )
    local matching_files = get_matching_paths(client, filters, vim.tbl_keys(files))
    if matching_files then
      local params = {
        files = vim.tbl_map(function(src_file)
          return {
            oldUri = vim.uri_from_fname(src_file),
            newUri = vim.uri_from_fname(files[src_file]),
          }
        end, matching_files),
      }
      local result, err
      if vim.fn.has("nvim-0.11") == 1 then
        result, err =
          client:request_sync(ms.workspace_willRenameFiles, params, options.timeout_ms or 1000, 0)
      else
        result, err =
          ---@diagnostic disable-next-line: param-type-mismatch
          client.request_sync(ms.workspace_willRenameFiles, params, options.timeout_ms or 1000, 0)
      end
      if result and result.result then
        if options.apply_edits ~= false then
          vim.lsp.util.apply_workspace_edit(result.result, client.offset_encoding)
        end
        table.insert(edits, { edit = result.result, offset_encoding = client.offset_encoding })
      else
        return nil, err or result and result.err
      end
    end
  end
  return edits
end

--- Notify the server that files were renamed from within the client.
---@param files table<string, string> Mapping of old_path -> new_path
function M.did_rename_files(files)
  local clients = get_clients(ms.workspace_didRenameFiles)
  for _, client in ipairs(clients) do
    local filters =
      vim.tbl_get(client.server_capabilities, "workspace", "fileOperations", "didRename", "filters")
    local matching_files = get_matching_paths(client, filters, vim.tbl_keys(files))
    if matching_files then
      local params = {
        files = vim.tbl_map(function(src_file)
          return {
            oldUri = vim.uri_from_fname(src_file),
            newUri = vim.uri_from_fname(files[src_file]),
          }
        end, matching_files),
      }
      if vim.fn.has("nvim-0.11") == 1 then
        client:notify(ms.workspace_didRenameFiles, params)
      else
        ---@diagnostic disable-next-line: param-type-mismatch
        client.notify(ms.workspace_didRenameFiles, params)
      end
    end
  end
end

return M
