local cache = require("oil.cache")
local columns = require("oil.columns")
local config = require("oil.config")
local keymap_util = require("oil.keymap_util")
local loading = require("oil.loading")
local util = require("oil.util")
local FIELD = require("oil.constants").FIELD
local M = {}

-- map of path->last entry under cursor
local last_cursor_entry = {}

---@param entry oil.InternalEntry
---@return boolean
M.should_display = function(entry)
  local name = entry[FIELD.name]
  if not config.view_options.show_hidden and vim.startswith(name, ".") then
    return false
  end
  return true
end

---@param bufname string
---@param name string
M.set_last_cursor = function(bufname, name)
  last_cursor_entry[bufname] = name
end

---@param bufname string
---@return nil|string
M.get_last_cursor = function(bufname)
  return last_cursor_entry[bufname]
end

local function are_any_modified()
  local view = require("oil.view")
  local buffers = view.get_all_buffers()
  for _, bufnr in ipairs(buffers) do
    if vim.bo[bufnr].modified then
      return true
    end
  end
  return false
end

M.toggle_hidden = function()
  local view = require("oil.view")
  local any_modified = are_any_modified()
  if any_modified then
    vim.notify("Cannot toggle hidden files when you have unsaved changes", vim.log.levels.WARN)
  else
    config.view_options.show_hidden = not config.view_options.show_hidden
    view.rerender_visible_and_cleanup({ refetch = false })
  end
end

M.set_columns = function(cols)
  local view = require("oil.view")
  local any_modified = are_any_modified()
  if any_modified then
    vim.notify("Cannot change columns when you have unsaved changes", vim.log.levels.WARN)
  else
    config.columns = cols
    -- TODO only refetch if we don't have all the necessary data for the columns
    view.rerender_visible_and_cleanup({ refetch = true })
  end
end

-- List of bufnrs
local session = {}

---@return integer[]
M.get_all_buffers = function()
  return vim.tbl_filter(vim.api.nvim_buf_is_loaded, vim.tbl_keys(session))
end

---@param opts table
---@note
--- This DISCARDS ALL MODIFICATIONS a user has made to oil buffers
M.rerender_visible_and_cleanup = function(opts)
  local buffers = M.get_all_buffers()
  local hidden_buffers = {}
  for _, bufnr in ipairs(buffers) do
    hidden_buffers[bufnr] = true
  end
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) then
      hidden_buffers[vim.api.nvim_win_get_buf(winid)] = nil
    end
  end
  for _, bufnr in ipairs(buffers) do
    if hidden_buffers[bufnr] then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    else
      M.render_buffer_async(bufnr, opts)
    end
  end
end

M.set_win_options = function()
  local winid = vim.api.nvim_get_current_win()
  for k, v in pairs(config.win_options) do
    if config.restore_win_options then
      local varname = "_oil_" .. k
      if not pcall(vim.api.nvim_win_get_var, winid, varname) then
        local prev_value = vim.wo[k]
        vim.api.nvim_win_set_var(winid, varname, prev_value)
      end
    end
    vim.api.nvim_win_set_option(winid, k, v)
  end
end

M.restore_win_options = function()
  local winid = vim.api.nvim_get_current_win()
  for k in pairs(config.win_options) do
    local varname = "_oil_" .. k
    local has_opt, opt = pcall(vim.api.nvim_win_get_var, winid, varname)
    if has_opt then
      vim.api.nvim_win_set_option(winid, k, opt)
    end
  end
end

---Delete hidden oil buffers and if none remain, clear the cache
M.cleanup = function()
  local buffers = M.get_all_buffers()
  local hidden_buffers = {}
  for _, bufnr in ipairs(buffers) do
    if vim.bo[bufnr].modified then
      return
    end
    hidden_buffers[bufnr] = true
  end
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) then
      hidden_buffers[vim.api.nvim_win_get_buf(winid)] = nil
    end
  end

  local any_remaining = false
  for _, bufnr in ipairs(buffers) do
    if hidden_buffers[bufnr] then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    else
      any_remaining = true
    end
  end
  if not any_remaining then
    cache.clear_everything()
  end
end

---@param bufnr integer
M.initialize = function(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  session[bufnr] = true
  for k, v in pairs(config.buf_options) do
    vim.api.nvim_buf_set_option(bufnr, k, v)
  end
  M.set_win_options()
  vim.api.nvim_create_autocmd("BufHidden", {
    callback = function()
      vim.defer_fn(M.cleanup, 2000)
    end,
    nested = true,
    buffer = bufnr,
  })
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function()
      session[bufnr] = nil
    end,
    nested = true,
    once = true,
    buffer = bufnr,
  })
  M.render_buffer_async(bufnr, {}, function(err)
    if err then
      vim.notify(
        string.format("Error rendering oil buffer %s: %s", vim.api.nvim_buf_get_name(bufnr), err),
        vim.log.levels.ERROR
      )
    end
  end)
  keymap_util.set_keymaps("", config.keymaps, bufnr)
end

---@param bufnr integer
---@param opts nil|table
---    jump boolean
---    jump_first boolean
---@return boolean
local function render_buffer(bufnr, opts)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  opts = vim.tbl_extend("keep", opts or {}, {
    jump = false,
    jump_first = false,
  })
  local scheme = util.parse_url(bufname)
  local adapter = util.get_adapter(bufnr)
  if not adapter then
    return false
  end
  local entries = cache.list_url(bufname)
  local entry_list = vim.tbl_values(entries)

  table.sort(entry_list, function(a, b)
    local a_isdir = a[FIELD.type] == "directory"
    local b_isdir = b[FIELD.type] == "directory"
    if a_isdir ~= b_isdir then
      return a_isdir
    end
    return a[FIELD.name] < b[FIELD.name]
  end)

  local jump_idx
  if opts.jump_first then
    jump_idx = 1
  end
  local seek_after_render_found = false
  local seek_after_render = M.get_last_cursor(bufname)
  local column_defs = columns.get_supported_columns(scheme)
  local line_table = {}
  local col_width = {}
  for i in ipairs(column_defs) do
    col_width[i + 1] = 1
  end
  local virt_text = {}
  for _, entry in ipairs(entry_list) do
    if not M.should_display(entry) then
      goto continue
    end
    local cols = M.format_entry_cols(entry, column_defs, col_width, adapter)
    table.insert(line_table, cols)

    local name = entry[FIELD.name]
    if seek_after_render == name then
      seek_after_render_found = true
      jump_idx = #line_table
    end
    ::continue::
  end

  local lines, highlights = util.render_table(line_table, col_width)

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  util.set_highlights(bufnr, highlights)
  local ns = vim.api.nvim_create_namespace("Oil")
  for _, v in ipairs(virt_text) do
    local lnum, col, ext_opts = unpack(v)
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, col, ext_opts)
  end
  if opts.jump then
    -- TODO why is the schedule necessary?
    vim.schedule(function()
      for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
          -- If we're not jumping to a specific lnum, use the current lnum so we can adjust the col
          local lnum = jump_idx or vim.api.nvim_win_get_cursor(winid)[1]
          local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
          local id_str = line:match("^/(%d+)")
          local id = tonumber(id_str)
          if id then
            local entry = cache.get_entry_by_id(id)
            if entry then
              local name = entry[FIELD.name]
              local col = line:find(name, 1, true) or (id_str:len() + 1)
              vim.api.nvim_win_set_cursor(winid, { lnum, col - 1 })
            end
          end
        end
      end
    end)
  end
  return seek_after_render_found
end

---@private
---@param adapter oil.Adapter
---@param entry oil.InternalEntry
---@param column_defs table[]
---@param col_width integer[]
---@param adapter oil.Adapter
---@return oil.TextChunk[]
M.format_entry_cols = function(entry, column_defs, col_width, adapter)
  local name = entry[FIELD.name]
  -- First put the unique ID
  local cols = {}
  local id_key = cache.format_id(entry[FIELD.id])
  col_width[1] = id_key:len()
  table.insert(cols, id_key)
  -- Then add all the configured columns
  for i, column in ipairs(column_defs) do
    local chunk = columns.render_col(adapter, column, entry)
    local text = type(chunk) == "table" and chunk[1] or chunk
    col_width[i + 1] = math.max(col_width[i + 1], vim.api.nvim_strwidth(text))
    table.insert(cols, chunk)
  end
  -- Always add the entry name at the end
  local entry_type = entry[FIELD.type]
  if entry_type == "directory" then
    table.insert(cols, { name .. "/", "OilDir" })
  elseif entry_type == "socket" then
    table.insert(cols, { name, "OilSocket" })
  elseif entry_type == "link" then
    local meta = entry[FIELD.meta]
    local link_text
    if meta then
      if meta.link_stat and meta.link_stat.type == "directory" then
        name = name .. "/"
      end

      if meta.link then
        link_text = "->" .. " " .. meta.link
        if meta.link_stat and meta.link_stat.type == "directory" then
          link_text = util.addslash(link_text)
        end
      end
    end

    table.insert(cols, { name, "OilLink" })
    if link_text then
      table.insert(cols, { link_text, "Comment" })
    end
  else
    table.insert(cols, { name, "OilFile" })
  end
  return cols
end

---@param bufnr integer
---@param opts nil|table
---    preserve_undo nil|boolean
---    refetch nil|boolean Defaults to true
---@param callback nil|fun(err: nil|string)
M.render_buffer_async = function(bufnr, opts, callback)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    preserve_undo = false,
    refetch = true,
  })
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local scheme, dir = util.parse_url(bufname)
  local preserve_undo = opts.preserve_undo and config.adapters[scheme] == "files"
  if not preserve_undo then
    -- Undo should not return to a blank buffer
    -- Method taken from :h clear-undo
    vim.bo[bufnr].undolevels = -1
  end
  local handle_error = vim.schedule_wrap(function(message)
    if not preserve_undo then
      vim.bo[bufnr].undolevels = vim.api.nvim_get_option("undolevels")
    end
    util.render_centered_text(bufnr, { "Error: " .. message })
    if callback then
      callback(message)
    else
      error(message)
    end
  end)
  if not dir then
    handle_error(string.format("Could not parse oil url '%s'", bufname))
    return
  end
  local adapter = util.get_adapter(bufnr)
  if not adapter then
    handle_error(string.format("[oil] no adapter for buffer '%s'", bufname))
    return
  end
  local start_ms = vim.loop.hrtime() / 1e6
  local seek_after_render_found = false
  local first = true
  vim.bo[bufnr].modifiable = false
  loading.set_loading(bufnr, true)

  local finish = vim.schedule_wrap(function()
    loading.set_loading(bufnr, false)
    render_buffer(bufnr, { jump = true })
    if not preserve_undo then
      vim.bo[bufnr].undolevels = vim.api.nvim_get_option("undolevels")
    end
    vim.bo[bufnr].modifiable = adapter.is_modifiable(bufnr)
    if callback then
      callback()
    end
  end)
  if not opts.refetch then
    finish()
    return
  end

  adapter.list(bufname, config.columns, function(err, has_more)
    loading.set_loading(bufnr, false)
    if err then
      handle_error(err)
      return
    elseif has_more then
      local now = vim.loop.hrtime() / 1e6
      local delta = now - start_ms
      -- If we've been chugging for more than 40ms, go ahead and render what we have
      if delta > 40 then
        start_ms = now
        vim.schedule(function()
          seek_after_render_found =
            render_buffer(bufnr, { jump = not seek_after_render_found, jump_first = first })
        end)
      end
      first = false
    else
      -- done iterating
      finish()
    end
  end)
end

return M
