local fs = require("oil.fs")
local util = require("oil.util")

local M = {}

---@alias oil.Path string
---@alias oil.PathPair {src: string, dest: string}

---@param filepath string
---@param pattern lsp.FileOperationPattern
---@return boolean
local function file_matches(filepath, pattern)
  local is_dir = vim.fn.isdirectory(filepath) == 1
  if pattern.matches then
    if (pattern.matches == "file" and is_dir) or (pattern.matches == "folder" and not is_dir) then
      return false
    end
  end

  if vim.lsp._watchfiles then
    local glob = pattern.glob
    local path = filepath
    if vim.tbl_get(pattern, "options", "ignoreCase") then
      glob, path = glob:lower(), path:lower()
    end
    return vim.lsp._watchfiles._match(glob, path)
  end

  local pat = vim.fn.glob2regpat(pattern.glob)
  if vim.tbl_get(pattern, "options", "ignoreCase") then
    pat = "\\c" .. pat
  end

  local ignorecase = vim.o.ignorecase
  vim.o.ignorecase = false
  local match = vim.fn.match(filepath, pat) >= 0
  vim.o.ignorecase = ignorecase
  return match
end

---@param filepath string
---@param filters lsp.FileOperationFilter[]
---@return boolean
local function any_match(filepath, filters)
  for _, filter in ipairs(filters) do
    local scheme_match = not filter.scheme or filter.scheme == "file"
    if scheme_match and file_matches(filepath, filter.pattern) then
      return true
    end
  end
  return false
end

---@return nil|oil.Path[]|oil.PathPair[]
local function get_matching_paths(client, file_op, path_pairs)
  local filters =
    vim.tbl_get(client.server_capabilities, "workspace", "fileOperations", file_op, "filters")
  if not filters then
    return nil
  end
  local ret = {}
  for _, pair in ipairs(path_pairs) do
    local path = type(pair) == "string" and pair or pair.src -- differentiate between oil.Path and oil.PathPair
    if fs.is_subpath(client.config.root_dir, path) then
      local relative_file = path:sub(client.config.root_dir:len() + 2)
      if any_match(path, filters) or any_match(relative_file, filters) then
        table.insert(ret, pair)
      end
    end
  end
  if vim.tbl_isempty(ret) then
    return nil
  else
    return ret
  end
end

---@param actions oil.MoveAction[]
---@return oil.PathPair[]
local parse_pairs = function(actions)
  ---@type oil.PathPair[]
  local path_pairs = {}
  for _, action in ipairs(actions) do
    local _, src_path = util.parse_url(action.src_url)
    assert(src_path)
    local src_file = fs.posix_to_os_path(src_path)
    local _, dest_path = util.parse_url(action.dest_url)
    assert(dest_path)
    local dest_file = fs.posix_to_os_path(dest_path)
    table.insert(path_pairs, { src = src_file, dest = dest_file })
  end
  return path_pairs
end

---@param actions oil.DeleteAction[]|oil.CreateAction[]
---@return oil.Path[]
local parse_paths = function(actions)
  ---@type oil.Path[]
  local paths = {}
  for _, action in ipairs(actions) do
    local _, path = util.parse_url(action.url)
    assert(path)
    local file = fs.posix_to_os_path(path)
    table.insert(paths, file)
  end
  return paths
end

local file_operation_request = function(operation, files, file_map)
  local clients = vim.lsp.get_active_clients()
  for _, client in ipairs(clients) do
    local filtered = get_matching_paths(client, operation, files)
    if filtered then
      client.request(
        ("workspace/%sFiles"):format(operation),
        { files = vim.tbl_map(file_map, filtered) },
        function(_, result)
          if result then
            vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
          end
        end
      )
    end
  end
end

local file_operation_notify = function(operation, files, file_map)
  local clients = vim.lsp.get_active_clients()
  for _, client in ipairs(clients) do
    local filtered = get_matching_paths(client, operation, files)
    if filtered then
      client.notify(
        ("workspace/%sFiles"):format(operation),
        { files = vim.tbl_map(file_map, filtered) }
      )
    end
  end
end

local path_pair_file_map = function(pair)
  return { oldUri = vim.uri_from_fname(pair.src), newUri = vim.uri_from_fname(pair.dest) }
end

local path_file_map = function(path)
  return { uri = vim.uri_from_fname(path) }
end

---Process LSP will rename in the background
---@param actions oil.MoveAction[]
M.will_rename_files = function(actions)
  file_operation_request("willRename", parse_pairs(actions), path_pair_file_map)
end

---Emit LSP did rename notification
---@param actions oil.MoveAction[]
M.did_rename_files = function(actions)
  file_operation_notify("didRename", parse_pairs(actions), path_pair_file_map)
end

---Process LSP will create in the background
---@param actions oil.CreateAction[]
M.will_create_files = function(actions)
  file_operation_request("willCreate", parse_paths(actions), path_file_map)
end

---Emit LSP did create notification
---@param actions oil.CreateAction[]
M.did_create_files = function(actions)
  file_operation_notify("didCreate", parse_paths(actions), path_file_map)
end

---Process LSP will delete in the background
---@param actions oil.DeleteAction[]
M.will_delete_files = function(actions)
  file_operation_request("willDelete", parse_paths(actions), path_file_map)
end

---Emit LSP did delete notification
---@param actions oil.DeleteAction[]
M.did_delete_files = function(actions)
  file_operation_notify("didDelete", parse_paths(actions), path_file_map)
end

-- LSP types from core Neovim

---A filter to describe in which file operation requests or notifications
---the server is interested in receiving.
---
---@since 3.16.0
---@class lsp.FileOperationFilter
---A Uri scheme like `file` or `untitled`.
---@field scheme? string
---The actual file operation pattern.
---@field pattern lsp.FileOperationPattern

---A pattern to describe in which file operation requests or notifications
---the server is interested in receiving.
---
---@since 3.16.0
---@class lsp.FileOperationPattern
---The glob pattern to match. Glob patterns can have the following syntax:
---- `*` to match one or more characters in a path segment
---- `?` to match on one character in a path segment
---- `**` to match any number of path segments, including none
---- `{}` to group sub patterns into an OR expression. (e.g. `**​/*.{ts,js}` matches all TypeScript and JavaScript files)
---- `[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
---- `[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)
---@field glob string
---Whether to match files or folders with this pattern.
---
---Matches both if undefined.
---@field matches? lsp.FileOperationPatternKind
---Additional options used during matching.
---@field options? lsp.FileOperationPatternOptions

---A pattern kind describing if a glob pattern matches a file a folder or
---both.
---
---@since 3.16.0
---@alias lsp.FileOperationPatternKind
---| "file" # file
---| "folder" # folder

---Matching options for the file operation pattern.
---
---@since 3.16.0
---@class lsp.FileOperationPatternOptions
---The pattern should be matched ignoring casing.
---@field ignoreCase? boolean

return M
