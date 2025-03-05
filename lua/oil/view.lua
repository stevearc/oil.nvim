local uv = vim.uv or vim.loop
local cache = require("oil.cache")
local columns = require("oil.columns")
local config = require("oil.config")
local constants = require("oil.constants")
local fs = require("oil.fs")
local keymap_util = require("oil.keymap_util")
local loading = require("oil.loading")
local util = require("oil.util")
local M = {}

local FIELD_ID = constants.FIELD_ID
local FIELD_NAME = constants.FIELD_NAME
local FIELD_TYPE = constants.FIELD_TYPE
local FIELD_META = constants.FIELD_META

-- map of path->last entry under cursor
local last_cursor_entry = {}

---@param name string
---@param bufnr integer
---@return boolean display
---@return boolean is_hidden Whether the file is classified as a hidden file
M.should_display = function(name, bufnr)
  if config.view_options.is_always_hidden(name, bufnr) then
    return false, true
  else
    local is_hidden = config.view_options.is_hidden_file(name, bufnr)
    local display = config.view_options.show_hidden or not is_hidden
    return display, is_hidden
  end
end

---@param bufname string
---@param name nil|string
M.set_last_cursor = function(bufname, name)
  last_cursor_entry[bufname] = name
end

---Set the cursor to the last_cursor_entry if one exists
M.maybe_set_cursor = function()
  local oil = require("oil")
  local bufname = vim.api.nvim_buf_get_name(0)
  local entry_name = last_cursor_entry[bufname]
  if not entry_name then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(0)
  for lnum = 1, line_count do
    local entry = oil.get_entry_on_line(0, lnum)
    if entry and entry.name == entry_name then
      local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
      local id_str = line:match("^/(%d+)")
      local col = line:find(entry_name, 1, true) or (id_str:len() + 1)
      vim.api.nvim_win_set_cursor(0, { lnum, col - 1 })
      M.set_last_cursor(bufname, nil)
      break
    end
  end
end

---@param bufname string
---@return nil|string
M.get_last_cursor = function(bufname)
  return last_cursor_entry[bufname]
end

local function are_any_modified()
  local buffers = M.get_all_buffers()
  for _, bufnr in ipairs(buffers) do
    if vim.bo[bufnr].modified then
      return true
    end
  end
  return false
end

M.toggle_hidden = function()
  local any_modified = are_any_modified()
  if any_modified then
    vim.notify("Cannot toggle hidden files when you have unsaved changes", vim.log.levels.WARN)
  else
    config.view_options.show_hidden = not config.view_options.show_hidden
    M.rerender_all_oil_buffers({ refetch = false })
  end
end

---@param is_hidden_file fun(filename: string, bufnr: integer): boolean
M.set_is_hidden_file = function(is_hidden_file)
  local any_modified = are_any_modified()
  if any_modified then
    vim.notify("Cannot change is_hidden_file when you have unsaved changes", vim.log.levels.WARN)
  else
    config.view_options.is_hidden_file = is_hidden_file
    M.rerender_all_oil_buffers({ refetch = false })
  end
end

M.set_columns = function(cols)
  local any_modified = are_any_modified()
  if any_modified then
    vim.notify("Cannot change columns when you have unsaved changes", vim.log.levels.WARN)
  else
    config.columns = cols
    -- TODO only refetch if we don't have all the necessary data for the columns
    M.rerender_all_oil_buffers({ refetch = true })
  end
end

M.set_sort = function(new_sort)
  local any_modified = are_any_modified()
  if any_modified then
    vim.notify("Cannot change sorting when you have unsaved changes", vim.log.levels.WARN)
  else
    config.view_options.sort = new_sort
    -- TODO only refetch if we don't have all the necessary data for the columns
    M.rerender_all_oil_buffers({ refetch = true })
  end
end

---@class oil.ViewData
---@field fs_event? any uv_fs_event_t

-- List of bufnrs
---@type table<integer, oil.ViewData>
local session = {}

---@return integer[]
M.get_all_buffers = function()
  return vim.tbl_filter(vim.api.nvim_buf_is_loaded, vim.tbl_keys(session))
end

local buffers_locked = false
---Make all oil buffers nomodifiable
M.lock_buffers = function()
  buffers_locked = true
  for bufnr in pairs(session) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      vim.bo[bufnr].modifiable = false
    end
  end
end

---Restore normal modifiable settings for oil buffers
M.unlock_buffers = function()
  buffers_locked = false
  for bufnr in pairs(session) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local adapter = util.get_adapter(bufnr, true)
      if adapter then
        vim.bo[bufnr].modifiable = adapter.is_modifiable(bufnr)
      end
    end
  end
end

---@param opts? table
---@param callback? fun(err: nil|string)
---@note
--- This DISCARDS ALL MODIFICATIONS a user has made to oil buffers
M.rerender_all_oil_buffers = function(opts, callback)
  opts = opts or {}
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
  local cb = util.cb_collect(#buffers, callback or function() end)
  for _, bufnr in ipairs(buffers) do
    if hidden_buffers[bufnr] then
      vim.b[bufnr].oil_dirty = opts
      -- We also need to mark this as nomodified so it doesn't interfere with quitting vim
      vim.bo[bufnr].modified = false
      vim.schedule(cb)
    else
      M.render_buffer_async(bufnr, opts, cb)
    end
  end
end

M.set_win_options = function()
  local winid = vim.api.nvim_get_current_win()

  -- work around https://github.com/neovim/neovim/pull/27422
  vim.api.nvim_set_option_value("foldmethod", "manual", { scope = "local", win = winid })

  for k, v in pairs(config.win_options) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
  end
  if vim.wo[winid].previewwindow then -- apply preview window options last
    for k, v in pairs(config.preview_win.win_options) do
      vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
    end
  end
end

---Get a list of visible oil buffers and a list of hidden oil buffers
---@note
--- If any buffers are modified, return values are nil
---@return nil|integer[] visible
---@return nil|integer[] hidden
local function get_visible_hidden_buffers()
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
  local visible_buffers = vim.tbl_filter(function(bufnr)
    return not hidden_buffers[bufnr]
  end, buffers)
  return visible_buffers, vim.tbl_keys(hidden_buffers)
end

---Delete unmodified, hidden oil buffers and if none remain, clear the cache
M.delete_hidden_buffers = function()
  local visible_buffers, hidden_buffers = get_visible_hidden_buffers()
  if
    not visible_buffers
    or not hidden_buffers
    or not vim.tbl_isempty(visible_buffers)
    or vim.fn.win_gettype() == "command"
  then
    return
  end
  for _, bufnr in ipairs(hidden_buffers) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  cache.clear_everything()
end

---@param adapter oil.Adapter
---@param ranges table<string, integer[]>
---@return integer
local function get_first_mutable_column_col(adapter, ranges)
  local min_col = ranges.name[1]
  for col_name, start_len in pairs(ranges) do
    local start = start_len[1]
    local col_spec = columns.get_column(adapter, col_name)
    local is_col_mutable = col_spec and col_spec.perform_action ~= nil
    if is_col_mutable and start < min_col then
      min_col = start
    end
  end
  return min_col
end

---Force cursor to be after hidden/immutable columns
---@param bufnr integer
---@param mode false|"name"|"editable"
local function constrain_cursor(bufnr, mode)
  if not mode then
    return
  end
  if bufnr ~= vim.api.nvim_get_current_buf() then
    return
  end
  local parser = require("oil.mutator.parser")

  local adapter = util.get_adapter(bufnr, true)
  if not adapter then
    return
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(bufnr, cur[1] - 1, cur[1], true)[1]
  local column_defs = columns.get_supported_columns(adapter)
  local result = parser.parse_line(adapter, line, column_defs)
  if result and result.ranges then
    local min_col
    if mode == "editable" then
      min_col = get_first_mutable_column_col(adapter, result.ranges)
    elseif mode == "name" then
      min_col = result.ranges.name[1]
    else
      error(string.format('Unexpected value "%s" for option constrain_cursor', mode))
    end
    if cur[2] < min_col then
      vim.api.nvim_win_set_cursor(0, { cur[1], min_col })
    end
  end
end

---Redraw original path virtual text for trash buffer
---@param bufnr integer
local function redraw_trash_virtual_text(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local parser = require("oil.mutator.parser")
  local adapter = util.get_adapter(bufnr, true)
  if not adapter or adapter.name ~= "trash" then
    return
  end
  local _, buf_path = util.parse_url(vim.api.nvim_buf_get_name(bufnr))
  local os_path = fs.posix_to_os_path(assert(buf_path))
  local ns = vim.api.nvim_create_namespace("OilVtext")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local column_defs = columns.get_supported_columns(adapter)
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)) do
    local result = parser.parse_line(adapter, line, column_defs)
    local entry = result and result.entry
    if entry then
      local meta = entry[FIELD_META]
      ---@type nil|oil.TrashInfo
      local trash_info = meta and meta.trash_info
      if trash_info then
        vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, 0, {
          virt_text = {
            {
              "➜ " .. fs.shorten_path(trash_info.original_path, os_path),
              "OilTrashSourcePath",
            },
          },
        })
      end
    end
  end
end

---@param bufnr integer
M.initialize = function(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_clear_autocmds({
    buffer = bufnr,
    group = "Oil",
  })
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].syntax = "oil"
  vim.bo[bufnr].filetype = "oil"
  vim.b[bufnr].EditorConfig_disable = 1
  session[bufnr] = session[bufnr] or {}
  for k, v in pairs(config.buf_options) do
    vim.bo[bufnr][k] = v
  end
  vim.api.nvim_buf_call(bufnr, M.set_win_options)

  vim.api.nvim_create_autocmd("BufHidden", {
    desc = "Delete oil buffers when no longer in use",
    group = "Oil",
    nested = true,
    buffer = bufnr,
    callback = function()
      -- First wait a short time (100ms) for the buffer change to settle
      vim.defer_fn(function()
        local visible_buffers = get_visible_hidden_buffers()
        -- Only delete oil buffers if none of them are visible
        if visible_buffers and vim.tbl_isempty(visible_buffers) then
          -- Check if cleanup is enabled
          if type(config.cleanup_delay_ms) == "number" then
            if config.cleanup_delay_ms > 0 then
              vim.defer_fn(function()
                M.delete_hidden_buffers()
              end, config.cleanup_delay_ms)
            else
              M.delete_hidden_buffers()
            end
          end
        end
      end, 100)
    end,
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    group = "Oil",
    nested = true,
    once = true,
    buffer = bufnr,
    callback = function()
      local view_data = session[bufnr]
      session[bufnr] = nil
      if view_data and view_data.fs_event then
        view_data.fs_event:stop()
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = "Oil",
    buffer = bufnr,
    callback = function(args)
      local opts = vim.b[args.buf].oil_dirty
      if opts then
        vim.b[args.buf].oil_dirty = nil
        M.render_buffer_async(args.buf, opts)
      end
    end,
  })
  local timer
  vim.api.nvim_create_autocmd("InsertEnter", {
    desc = "Constrain oil cursor position",
    group = "Oil",
    buffer = bufnr,
    callback = function()
      -- For some reason the cursor bounces back to its original position,
      -- so we have to defer the call
      vim.schedule_wrap(constrain_cursor)(bufnr, config.constrain_cursor)
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
    desc = "Update oil preview window",
    group = "Oil",
    buffer = bufnr,
    callback = function()
      local oil = require("oil")
      if vim.wo.previewwindow then
        return
      end

      constrain_cursor(bufnr, config.constrain_cursor)

      if config.preview_win.update_on_cursor_moved then
        -- Debounce and update the preview window
        if timer then
          timer:again()
          return
        end
        timer = uv.new_timer()
        if not timer then
          return
        end
        timer:start(10, 100, function()
          timer:stop()
          timer:close()
          timer = nil
          vim.schedule(function()
            if vim.api.nvim_get_current_buf() ~= bufnr then
              return
            end
            local entry = oil.get_cursor_entry()
            -- Don't update in visual mode. Visual mode implies editing not browsing,
            -- and updating the preview can cause flicker and stutter.
            if entry and not util.is_visual_mode() then
              local winid = util.get_preview_win()
              if winid then
                if entry.id ~= vim.w[winid].oil_entry_id then
                  oil.open_preview()
                end
              end
            end
          end)
        end)
      end
    end,
  })

  local adapter = util.get_adapter(bufnr, true)

  -- Set up a watcher that will refresh the directory
  if
    adapter
    and adapter.name == "files"
    and config.watch_for_changes
    and not session[bufnr].fs_event
  then
    local fs_event = assert(uv.new_fs_event())
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local _, dir = util.parse_url(bufname)
    fs_event:start(
      assert(dir),
      {},
      vim.schedule_wrap(function(err, filename, events)
        if not vim.api.nvim_buf_is_valid(bufnr) then
          local sess = session[bufnr]
          if sess then
            sess.fs_event = nil
          end
          fs_event:stop()
          return
        end
        local mutator = require("oil.mutator")
        if err or vim.bo[bufnr].modified or vim.b[bufnr].oil_dirty or mutator.is_mutating() then
          return
        end

        -- If the buffer is currently visible, rerender
        for _, winid in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
            M.render_buffer_async(bufnr)
            return
          end
        end

        -- If it is not currently visible, mark it as dirty
        vim.b[bufnr].oil_dirty = {}
      end)
    )
    session[bufnr].fs_event = fs_event
  end

  -- Watch for TextChanged and update the trash original path extmarks
  if adapter and adapter.name == "trash" then
    local debounce_timer = assert(uv.new_timer())
    local pending = false
    vim.api.nvim_create_autocmd("TextChanged", {
      desc = "Update oil virtual text of original path",
      buffer = bufnr,
      callback = function()
        -- Respond immediately to prevent flickering, the set the timer for a "cooldown period"
        -- If this is called again during the cooldown window, we will rerender after cooldown.
        if debounce_timer:is_active() then
          pending = true
        else
          redraw_trash_virtual_text(bufnr)
        end
        debounce_timer:start(
          50,
          0,
          vim.schedule_wrap(function()
            if pending then
              pending = false
              redraw_trash_virtual_text(bufnr)
            end
          end)
        )
      end,
    })
  end
  M.render_buffer_async(bufnr, {}, function(err)
    if err then
      vim.notify(
        string.format("Error rendering oil buffer %s: %s", vim.api.nvim_buf_get_name(bufnr), err),
        vim.log.levels.ERROR
      )
    else
      vim.b[bufnr].oil_ready = true
      vim.api.nvim_exec_autocmds(
        "User",
        { pattern = "OilEnter", modeline = false, data = { buf = bufnr } }
      )
    end
  end)
  keymap_util.set_keymaps(config.keymaps, bufnr)
end

---@param adapter oil.Adapter
---@param num_entries integer
---@return fun(a: oil.InternalEntry, b: oil.InternalEntry): boolean
local function get_sort_function(adapter, num_entries)
  local idx_funs = {}
  local sort_config = config.view_options.sort

  -- If empty, default to type + name sorting
  if vim.tbl_isempty(sort_config) then
    sort_config = { { "type", "asc" }, { "name", "asc" } }
  end

  for _, sort_pair in ipairs(sort_config) do
    local col_name, order = unpack(sort_pair)
    if order ~= "asc" and order ~= "desc" then
      vim.notify_once(
        string.format(
          "Column '%s' has invalid sort order '%s'. Should be either 'asc' or 'desc'",
          col_name,
          order
        ),
        vim.log.levels.WARN
      )
    end
    local col = columns.get_column(adapter, col_name)
    if col and col.create_sort_value_factory then
      table.insert(idx_funs, { col.create_sort_value_factory(num_entries), order })
    elseif col and col.get_sort_value then
      table.insert(idx_funs, { col.get_sort_value, order })
    else
      vim.notify_once(
        string.format("Column '%s' does not support sorting", col_name),
        vim.log.levels.WARN
      )
    end
  end
  return function(a, b)
    for _, sort_fn in ipairs(idx_funs) do
      local get_sort_value, order = unpack(sort_fn)
      local a_val = get_sort_value(a)
      local b_val = get_sort_value(b)
      if a_val ~= b_val then
        if order == "desc" then
          return a_val > b_val
        else
          return a_val < b_val
        end
      end
    end
    return a[FIELD_NAME] < b[FIELD_NAME]
  end
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
  local adapter = util.get_adapter(bufnr, true)
  if not scheme or not adapter then
    return false
  end
  local entries = cache.list_url(bufname)
  local entry_list = vim.tbl_values(entries)

  -- Only sort the entries once we have them all
  if not vim.b[bufnr].oil_rendering then
    table.sort(entry_list, get_sort_function(adapter, #entry_list))
  end

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

  if M.should_display("..", bufnr) then
    local cols =
      M.format_entry_cols({ 0, "..", "directory" }, column_defs, col_width, adapter, true, bufnr)
    table.insert(line_table, cols)
  end

  for _, entry in ipairs(entry_list) do
    local should_display, is_hidden = M.should_display(entry[FIELD_NAME], bufnr)
    if should_display then
      local cols = M.format_entry_cols(entry, column_defs, col_width, adapter, is_hidden, bufnr)
      table.insert(line_table, cols)

      local name = entry[FIELD_NAME]
      if seek_after_render == name then
        seek_after_render_found = true
        jump_idx = #line_table
      end
    end
  end

  local lines, highlights = util.render_table(line_table, col_width)

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  util.set_highlights(bufnr, highlights)

  if opts.jump then
    -- TODO why is the schedule necessary?
    vim.schedule(function()
      for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
          if jump_idx then
            local lnum = jump_idx
            local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
            local id_str = line:match("^/(%d+)")
            local id = tonumber(id_str)
            if id then
              local entry = cache.get_entry_by_id(id)
              if entry then
                local name = entry[FIELD_NAME]
                local col = line:find(name, 1, true) or (id_str:len() + 1)
                vim.api.nvim_win_set_cursor(winid, { lnum, col - 1 })
                return
              end
            end
          end

          constrain_cursor(bufnr, "name")
        end
      end
    end)
  end
  return seek_after_render_found
end

---@param name string
---@param meta? table
---@return string filename
---@return string|nil link_target
local function get_link_text(name, meta)
  local link_text
  if meta then
    if meta.link_stat and meta.link_stat.type == "directory" then
      name = name .. "/"
    end

    if meta.link then
      link_text = "-> " .. meta.link
      if meta.link_stat and meta.link_stat.type == "directory" then
        link_text = util.addslash(link_text)
      end
    end
  end

  return name, link_text
end

---@private
---@param entry oil.InternalEntry
---@param column_defs table[]
---@param col_width integer[]
---@param adapter oil.Adapter
---@param is_hidden boolean
---@param bufnr integer
---@return oil.TextChunk[]
M.format_entry_cols = function(entry, column_defs, col_width, adapter, is_hidden, bufnr)
  local name = entry[FIELD_NAME]
  local meta = entry[FIELD_META]
  local hl_suffix = ""
  if is_hidden then
    hl_suffix = "Hidden"
  end
  if meta and meta.display_name then
    name = meta.display_name
  end
  -- We can't handle newlines in filenames (and shame on you for doing that)
  name = name:gsub("\n", "")
  -- First put the unique ID
  local cols = {}
  local id_key = cache.format_id(entry[FIELD_ID])
  col_width[1] = id_key:len()
  table.insert(cols, id_key)
  -- Then add all the configured columns
  for i, column in ipairs(column_defs) do
    local chunk = columns.render_col(adapter, column, entry, bufnr)
    local text = type(chunk) == "table" and chunk[1] or chunk
    ---@cast text string
    col_width[i + 1] = math.max(col_width[i + 1], vim.api.nvim_strwidth(text))
    table.insert(cols, chunk)
  end
  -- Always add the entry name at the end
  local entry_type = entry[FIELD_TYPE]

  local get_custom_hl = config.view_options.highlight_filename
  local link_name, link_name_hl, link_target, link_target_hl
  if get_custom_hl then
    local external_entry = util.export_entry(entry)

    if entry_type == "link" then
      link_name, link_target = get_link_text(name, meta)
      local is_orphan = not (meta and meta.link_stat)
      link_name_hl = get_custom_hl(external_entry, is_hidden, false, is_orphan, bufnr)

      if link_target then
        link_target_hl = get_custom_hl(external_entry, is_hidden, true, is_orphan, bufnr)
      end

      -- intentional fallthrough
    else
      local hl = get_custom_hl(external_entry, is_hidden, false, false, bufnr)
      if hl then
        -- Add the trailing / if this is a directory, this is important
        if entry_type == "directory" then
          name = name .. "/"
        end
        table.insert(cols, { name, hl })
        return cols
      end
    end
  end

  if entry_type == "directory" then
    table.insert(cols, { name .. "/", "OilDir" .. hl_suffix })
  elseif entry_type == "socket" then
    table.insert(cols, { name, "OilSocket" .. hl_suffix })
  elseif entry_type == "link" then
    if not link_name then
      link_name, link_target = get_link_text(name, meta)
    end
    local is_orphan = not (meta and meta.link_stat)
    if not link_name_hl then
      link_name_hl = (is_orphan and "OilOrphanLink" or "OilLink") .. hl_suffix
    end
    table.insert(cols, { link_name, link_name_hl })

    if link_target then
      if not link_target_hl then
        link_target_hl = (is_orphan and "OilOrphanLinkTarget" or "OilLinkTarget") .. hl_suffix
      end
      table.insert(cols, { link_target, link_target_hl })
    end
  else
    table.insert(cols, { name, "OilFile" .. hl_suffix })
  end

  return cols
end

---Get the column names that are used for view and sort
---@return string[]
local function get_used_columns()
  local cols = {}
  for _, def in ipairs(config.columns) do
    local name = util.split_config(def)
    table.insert(cols, name)
  end
  for _, sort_pair in ipairs(config.view_options.sort) do
    local name = sort_pair[1]
    table.insert(cols, name)
  end
  return cols
end

---@type table<integer, fun(message: string)[]>
local pending_renders = {}

---@param bufnr integer
---@param opts nil|table
---    refetch nil|boolean Defaults to true
---@param callback nil|fun(err: nil|string)
M.render_buffer_async = function(bufnr, opts, callback)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    refetch = true,
  })
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- If we're already rendering, queue up another rerender after it's complete
  if vim.b[bufnr].oil_rendering then
    if not pending_renders[bufnr] then
      pending_renders[bufnr] = { callback }
    elseif callback then
      table.insert(pending_renders[bufnr], callback)
    end
    return
  end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  vim.b[bufnr].oil_rendering = true
  local _, dir = util.parse_url(bufname)
  -- Undo should not return to a blank buffer
  -- Method taken from :h clear-undo
  vim.bo[bufnr].undolevels = -1
  local handle_error = vim.schedule_wrap(function(message)
    vim.b[bufnr].oil_rendering = false
    vim.bo[bufnr].undolevels = vim.api.nvim_get_option_value("undolevels", { scope = "global" })
    util.render_text(bufnr, { "Error: " .. message })
    if pending_renders[bufnr] then
      for _, cb in ipairs(pending_renders[bufnr]) do
        cb(message)
      end
      pending_renders[bufnr] = nil
    end
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
  local adapter = util.get_adapter(bufnr, true)
  if not adapter then
    handle_error(string.format("[oil] no adapter for buffer '%s'", bufname))
    return
  end
  local start_ms = uv.hrtime() / 1e6
  local seek_after_render_found = false
  local first = true
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  loading.set_loading(bufnr, true)

  local finish = vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    vim.b[bufnr].oil_rendering = false
    loading.set_loading(bufnr, false)
    render_buffer(bufnr, { jump = true })
    M.set_last_cursor(bufname, nil)
    vim.bo[bufnr].undolevels = vim.api.nvim_get_option_value("undolevels", { scope = "global" })
    vim.bo[bufnr].modifiable = not buffers_locked and adapter.is_modifiable(bufnr)
    if callback then
      callback()
    end

    -- If there were any concurrent calls to render this buffer, process them now
    if pending_renders[bufnr] then
      local all_cbs = pending_renders[bufnr]
      pending_renders[bufnr] = nil
      local new_cb = function(...)
        for _, cb in ipairs(all_cbs) do
          cb(...)
        end
      end
      M.render_buffer_async(bufnr, {}, new_cb)
    end
  end)
  if not opts.refetch then
    finish()
    return
  end

  cache.begin_update_url(bufname)
  local num_iterations = 0
  adapter.list(bufname, get_used_columns(), function(err, entries, fetch_more)
    loading.set_loading(bufnr, false)
    if err then
      cache.end_update_url(bufname)
      handle_error(err)
      return
    end
    if entries then
      for _, entry in ipairs(entries) do
        cache.store_entry(bufname, entry)
      end
    end
    if fetch_more then
      local now = uv.hrtime() / 1e6
      local delta = now - start_ms
      -- If we've been chugging for more than 40ms, go ahead and render what we have
      if (delta > 25 and num_iterations < 1) or delta > 500 then
        num_iterations = num_iterations + 1
        start_ms = now
        vim.schedule(function()
          seek_after_render_found =
            render_buffer(bufnr, { jump = not seek_after_render_found, jump_first = first })
          start_ms = uv.hrtime() / 1e6
        end)
      end
      first = false
      vim.defer_fn(fetch_more, 4)
    else
      cache.end_update_url(bufname)
      -- done iterating
      finish()
    end
  end)
end

return M
