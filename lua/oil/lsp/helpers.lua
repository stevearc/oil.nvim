local config = require("oil.config")
local fs = require("oil.fs")
local util = require("oil.util")
local workspace = require("oil.lsp.workspace")

local M = {}

---@param actions oil.Action[]
---@return fun() did_perform Call this function when the file operations have been completed
M.will_perform_file_operations = function(actions)
  local moves = {}
  local creates = {}
  local deletes = {}
  for _, action in ipairs(actions) do
    if action.type == "move" then
      local src_scheme, src_path = util.parse_url(action.src_url)
      assert(src_path)
      local src_adapter = assert(config.get_adapter_by_scheme(src_scheme))
      local dest_scheme, dest_path = util.parse_url(action.dest_url)
      local dest_adapter = assert(config.get_adapter_by_scheme(dest_scheme))
      src_path = fs.posix_to_os_path(src_path)
      dest_path = fs.posix_to_os_path(assert(dest_path))
      if src_adapter.name == "files" and dest_adapter.name == "files" then
        moves[src_path] = dest_path
      elseif src_adapter.name == "files" then
        table.insert(deletes, src_path)
      elseif dest_adapter.name == "files" then
        table.insert(creates, src_path)
      end
    elseif action.type == "create" then
      local scheme, path = util.parse_url(action.url)
      path = fs.posix_to_os_path(assert(path))
      local adapter = assert(config.get_adapter_by_scheme(scheme))
      if adapter.name == "files" then
        table.insert(creates, path)
      end
    elseif action.type == "delete" then
      local scheme, path = util.parse_url(action.url)
      path = fs.posix_to_os_path(assert(path))
      local adapter = assert(config.get_adapter_by_scheme(scheme))
      if adapter.name == "files" then
        table.insert(deletes, path)
      end
    elseif action.type == "copy" then
      local scheme, path = util.parse_url(action.dest_url)
      path = fs.posix_to_os_path(assert(path))
      local adapter = assert(config.get_adapter_by_scheme(scheme))
      if adapter.name == "files" then
        table.insert(creates, path)
      end
    end
  end

  local buf_was_modified = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    buf_was_modified[bufnr] = vim.bo[bufnr].modified
  end

  local edited_uris = {}
  local final_err = nil
  ---@param edits nil|{edit: lsp.WorkspaceEdit, client_offset: string}[]
  local function accum(edits, err)
    final_err = final_err or err
    if edits then
      for _, edit in ipairs(edits) do
        if edit.edit.changes then
          for uri in pairs(edit.edit.changes) do
            edited_uris[uri] = true
          end
        end
        if edit.edit.documentChanges then
          for _, change in ipairs(edit.edit.documentChanges) do
            if change.textDocument then
              edited_uris[change.textDocument.uri] = true
            end
          end
        end
      end
    end
  end
  local timeout_ms = config.lsp_file_methods.timeout_ms
  accum(workspace.will_create_files(creates, { timeout_ms = timeout_ms }))
  accum(workspace.will_delete_files(deletes, { timeout_ms = timeout_ms }))
  accum(workspace.will_rename_files(moves, { timeout_ms = timeout_ms }))
  if final_err then
    vim.notify(
      string.format("[lsp] file operation error: %s", vim.inspect(final_err)),
      vim.log.levels.WARN
    )
  end

  return function()
    workspace.did_create_files(creates)
    workspace.did_delete_files(deletes)
    workspace.did_rename_files(moves)

    local autosave = config.lsp_file_methods.autosave_changes
    if autosave == false then
      return
    end
    for uri, _ in pairs(edited_uris) do
      local bufnr = vim.uri_to_bufnr(uri)
      local was_open = buf_was_modified[bufnr] ~= nil
      local was_modified = buf_was_modified[bufnr]
      local should_save = autosave == true or (autosave == "unmodified" and not was_modified)
      -- Autosave changed buffers if they were not modified before
      if should_save then
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd.update({ mods = { emsg_silent = true, noautocmd = true } })
        end)

        -- Delete buffers that weren't open before
        if not was_open then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end
  end
end

return M
