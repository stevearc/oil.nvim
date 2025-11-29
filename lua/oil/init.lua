local M = {}

---@class (exact) oil.Entry
---@field name string
---@field type oil.EntryType
---@field id nil|integer Will be nil if it hasn't been persisted to disk yet
---@field parsed_name nil|string
---@field meta nil|table

---@alias oil.EntryType uv.aliases.fs_types
---@alias oil.HlRange { [1]: string, [2]: integer, [3]: integer } A tuple of highlight group name, col_start, col_end
---@alias oil.HlTuple { [1]: string, [2]: string } A tuple of text, highlight group
---@alias oil.HlRangeTuple { [1]: string, [2]: oil.HlRange[] } A tuple of text, internal highlights
---@alias oil.TextChunk string|oil.HlTuple|oil.HlRangeTuple
---@alias oil.CrossAdapterAction "copy"|"move"

---@class (exact) oil.Adapter
---@field name string The unique name of the adapter (this will be set automatically)
---@field list fun(path: string, column_defs: string[], cb: fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())) Async function to list a directory.
---@field is_modifiable fun(bufnr: integer): boolean Return true if this directory is modifiable (allows for directories with read-only permissions).
---@field get_column fun(name: string): nil|oil.ColumnDefinition If the adapter has any adapter-specific columns, return them when fetched by name.
---@field get_parent? fun(bufname: string): string Get the parent url of the given buffer
---@field normalize_url fun(url: string, callback: fun(url: string)) Before oil opens a url it will be normalized. This allows for link following, path normalizing, and converting an oil file url to the actual path of a file.
---@field get_entry_path? fun(url: string, entry: oil.Entry, callback: fun(path: string)) Similar to normalize_url, but used when selecting an entry
---@field render_action? fun(action: oil.Action): string Render a mutation action for display in the preview window. Only needed if adapter is modifiable.
---@field perform_action? fun(action: oil.Action, cb: fun(err: nil|string)) Perform a mutation action. Only needed if adapter is modifiable.
---@field read_file? fun(bufnr: integer) Used for adapters that deal with remote/virtual files. Read the contents of the file into a buffer.
---@field write_file? fun(bufnr: integer) Used for adapters that deal with remote/virtual files. Write the contents of a buffer to the destination.
---@field supported_cross_adapter_actions? table<string, oil.CrossAdapterAction> Mapping of adapter name to enum for all other adapters that can be used as a src or dest for move/copy actions.
---@field filter_action? fun(action: oil.Action): boolean When present, filter out actions as they are created
---@field filter_error? fun(action: oil.ParseError): boolean When present, filter out errors from parsing a buffer

---Get the entry on a specific line (1-indexed)
---@param bufnr integer
---@param lnum integer
---@return nil|oil.Entry
M.get_entry_on_line = function(bufnr, lnum)
  local columns = require("oil.columns")
  local parser = require("oil.mutator.parser")
  local util = require("oil.util")
  if vim.bo[bufnr].filetype ~= "oil" then
    return nil
  end
  local adapter = util.get_adapter(bufnr)
  if not adapter then
    return nil
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
  if not line then
    return nil
  end
  local column_defs = columns.get_supported_columns(adapter)
  local result = parser.parse_line(adapter, line, column_defs)
  if result then
    if result.entry then
      local entry = util.export_entry(result.entry)
      entry.parsed_name = result.data.name
      return entry
    else
      return {
        id = result.data.id,
        name = result.data.name,
        type = result.data._type,
        parsed_name = result.data.name,
      }
    end
  end
  -- This is a NEW entry that hasn't been saved yet
  local name = vim.trim(line)
  local entry_type
  if vim.endswith(name, "/") then
    name = name:sub(1, name:len() - 1)
    entry_type = "directory"
  else
    entry_type = "file"
  end
  if name == "" then
    return nil
  else
    return {
      name = name,
      type = entry_type,
      parsed_name = name,
    }
  end
end

---Get the entry currently under the cursor
---@return nil|oil.Entry
M.get_cursor_entry = function()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return M.get_entry_on_line(0, lnum)
end

---Discard all changes made to oil buffers
M.discard_all_changes = function()
  local view = require("oil.view")
  for _, bufnr in ipairs(view.get_all_buffers()) do
    if vim.bo[bufnr].modified then
      view.render_buffer_async(bufnr, {}, function(err)
        if err then
          vim.notify(
            string.format(
              "Error rendering oil buffer %s: %s",
              vim.api.nvim_buf_get_name(bufnr),
              err
            ),
            vim.log.levels.ERROR
          )
        end
      end)
    end
  end
end

---Change the display columns for oil
---@param cols oil.ColumnSpec[]
M.set_columns = function(cols)
  require("oil.view").set_columns(cols)
end

---Change the sort order for oil
---@param sort oil.SortSpec[] List of columns plus direction. See :help oil-columns to see which ones are sortable.
---@example
--- require("oil").set_sort({ { "type", "asc" }, { "size", "desc" } })
M.set_sort = function(sort)
  require("oil.view").set_sort(sort)
end

---Change how oil determines if the file is hidden
---@param is_hidden_file fun(filename: string, bufnr: integer): boolean Return true if the file/dir should be hidden
M.set_is_hidden_file = function(is_hidden_file)
  require("oil.view").set_is_hidden_file(is_hidden_file)
end

---Toggle hidden files and directories
M.toggle_hidden = function()
  require("oil.view").toggle_hidden()
end

---Get the current directory
---@param bufnr? integer
---@return nil|string
M.get_current_dir = function(bufnr)
  local config = require("oil.config")
  local fs = require("oil.fs")
  local util = require("oil.util")
  local buf_name = vim.api.nvim_buf_get_name(bufnr or 0)
  local scheme, path = util.parse_url(buf_name)
  if config.adapters[scheme] == "files" then
    assert(path)
    return fs.posix_to_os_path(path)
  end
end

---Get the oil url for a given directory
---@private
---@param dir nil|string When nil, use the cwd
---@param use_oil_parent nil|boolean If in an oil buffer, return the parent (default true)
---@return string The parent url
---@return nil|string The basename (if present) of the file/dir we were just in
M.get_url_for_path = function(dir, use_oil_parent)
  if use_oil_parent == nil then
    use_oil_parent = true
  end
  local config = require("oil.config")
  local fs = require("oil.fs")
  local util = require("oil.util")
  if vim.bo.filetype == "netrw" and not dir then
    dir = vim.b.netrw_curdir
  end
  if dir then
    local scheme = util.parse_url(dir)
    if scheme then
      return dir
    end
    local abspath = vim.fn.fnamemodify(dir, ":p")
    local path = fs.os_to_posix_path(abspath)
    return config.adapter_to_scheme.files .. path
  else
    local bufname = vim.api.nvim_buf_get_name(0)
    return M.get_buffer_parent_url(bufname, use_oil_parent)
  end
end

---@private
---@param bufname string
---@param use_oil_parent boolean If in an oil buffer, return the parent
---@return string
---@return nil|string
M.get_buffer_parent_url = function(bufname, use_oil_parent)
  local config = require("oil.config")
  local fs = require("oil.fs")
  local pathutil = require("oil.pathutil")
  local util = require("oil.util")
  local scheme, path = util.parse_url(bufname)
  if not scheme then
    local parent, basename
    scheme = config.adapter_to_scheme.files
    if bufname == "" then
      parent = fs.os_to_posix_path(vim.fn.getcwd())
    else
      parent = fs.os_to_posix_path(vim.fn.fnamemodify(bufname, ":p:h"))
      basename = vim.fn.fnamemodify(bufname, ":t")
    end
    local parent_url = util.addslash(scheme .. parent)
    return parent_url, basename
  else
    assert(path)
    if scheme == "term://" then
      ---@type string
      path = vim.fn.expand(path:match("^(.*)//")) ---@diagnostic disable-line: assign-type-mismatch
      return config.adapter_to_scheme.files .. util.addslash(path)
    end

    -- This is some unknown buffer scheme
    if not config.adapters[scheme] then
      return vim.fn.getcwd()
    end

    if not use_oil_parent then
      return bufname
    end
    local adapter = assert(config.get_adapter_by_scheme(scheme))
    local parent_url
    if adapter and adapter.get_parent then
      local adapter_scheme = config.adapter_to_scheme[adapter.name]
      parent_url = adapter.get_parent(adapter_scheme .. path)
    else
      local parent = pathutil.parent(path)
      parent_url = scheme .. util.addslash(parent)
    end
    if parent_url == bufname then
      return parent_url
    else
      return util.addslash(parent_url), pathutil.basename(path)
    end
  end
end

---@class (exact) oil.OpenOpts
---@field preview? oil.OpenPreviewOpts When present, open the preview window after opening oil

---Open oil browser in a floating window
---@param dir? string When nil, open the parent of the current buffer, or the cwd if current buffer is not a file
---@param opts? oil.OpenOpts
---@param cb? fun() Called after the oil buffer is ready
M.open_float = function(dir, opts, cb)
  opts = opts or {}
  local config = require("oil.config")
  local layout = require("oil.layout")
  local util = require("oil.util")
  local view = require("oil.view")

  local parent_url, basename = M.get_url_for_path(dir)
  if basename then
    view.set_last_cursor(parent_url, basename)
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  local win_opts = layout.get_fullscreen_win_opts()

  local original_winid = vim.api.nvim_get_current_win()
  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  vim.w[winid].is_oil_win = true
  vim.w[winid].oil_original_win = original_winid
  for k, v in pairs(config.float.win_options) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
  end
  local autocmds = {}
  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("WinLeave", {
      desc = "Close floating oil window",
      group = "Oil",
      callback = vim.schedule_wrap(function()
        if util.is_floating_win() or vim.fn.win_gettype() == "command" then
          return
        end
        if vim.api.nvim_win_is_valid(winid) then
          vim.api.nvim_win_close(winid, true)
        end
        for _, id in ipairs(autocmds) do
          vim.api.nvim_del_autocmd(id)
        end
        autocmds = {}
      end),
      nested = true,
    })
  )

  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("BufWinEnter", {
      desc = "Reset local oil window options when buffer changes",
      pattern = "*",
      callback = function(params)
        local winbuf = params.buf
        if not vim.api.nvim_win_is_valid(winid) or vim.api.nvim_win_get_buf(winid) ~= winbuf then
          return
        end
        for k, v in pairs(config.float.win_options) do
          vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
        end

        -- Update the floating window title
        if vim.fn.has("nvim-0.9") == 1 and config.float.border ~= "none" then
          local cur_win_opts = vim.api.nvim_win_get_config(winid)
          vim.api.nvim_win_set_config(winid, {
            relative = "editor",
            row = cur_win_opts.row,
            col = cur_win_opts.col,
            width = cur_win_opts.width,
            height = cur_win_opts.height,
            title = util.get_title(winid),
          })
        end
      end,
    })
  )

  vim.cmd.edit({ args = { util.escape_filename(parent_url) }, mods = { keepalt = true } })
  -- :edit will set buflisted = true, but we may not want that
  if config.buf_options.buflisted ~= nil then
    vim.api.nvim_set_option_value("buflisted", config.buf_options.buflisted, { buf = 0 })
  end

  util.run_after_load(0, function()
    if opts.preview then
      M.open_preview(opts.preview, cb)
    elseif cb then
      cb()
    end
  end)

  if vim.fn.has("nvim-0.9") == 0 then
    util.add_title_to_win(winid)
  end
end

---Open oil browser in a floating window, or close it if open
---@param dir nil|string When nil, open the parent of the current buffer, or the cwd if current buffer is not a file
M.toggle_float = function(dir)
  if vim.w.is_oil_win then
    M.close()
  else
    M.open_float(dir)
  end
end

---@param oil_bufnr? integer
local function update_preview_window(oil_bufnr)
  oil_bufnr = oil_bufnr or 0
  local util = require("oil.util")
  util.run_after_load(oil_bufnr, function()
    local cursor_entry = M.get_cursor_entry()
    local preview_win_id = util.get_preview_win()
    if
      cursor_entry
      and preview_win_id
      and cursor_entry.id ~= vim.w[preview_win_id].oil_entry_id
    then
      M.open_preview()
    end
  end)
end

---Open oil browser for a directory
---@param dir? string When nil, open the parent of the current buffer, or the cwd if current buffer is not a file
---@param opts? oil.OpenOpts
---@param cb? fun() Called after the oil buffer is ready
M.open = function(dir, opts, cb)
  opts = opts or {}
  local config = require("oil.config")
  local util = require("oil.util")
  local view = require("oil.view")
  local parent_url, basename = M.get_url_for_path(dir)
  if basename then
    view.set_last_cursor(parent_url, basename)
  end
  vim.cmd.edit({ args = { util.escape_filename(parent_url) }, mods = { keepalt = true } })
  -- :edit will set buflisted = true, but we may not want that
  if config.buf_options.buflisted ~= nil then
    vim.api.nvim_set_option_value("buflisted", config.buf_options.buflisted, { buf = 0 })
  end

  util.run_after_load(0, function()
    if opts.preview then
      M.open_preview(opts.preview, cb)
    elseif cb then
      cb()
    end
  end)

  -- If preview window exists, update its content
  update_preview_window()
end

---@class oil.CloseOpts
---@field exit_if_last_buf? boolean Exit vim if this oil buffer is the last open buffer

---Restore the buffer that was present when oil was opened
---@param opts? oil.CloseOpts
M.close = function(opts)
  opts = opts or {}
  -- If we're in a floating oil window, close it and try to restore focus to the original window
  if vim.w.is_oil_win then
    local original_winid = vim.w.oil_original_win
    vim.api.nvim_win_close(0, true)
    if original_winid and vim.api.nvim_win_is_valid(original_winid) then
      vim.api.nvim_set_current_win(original_winid)
    end
    return
  end
  local ok, bufnr = pcall(vim.api.nvim_win_get_var, 0, "oil_original_buffer")
  if ok and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_win_set_buf(0, bufnr)
    if vim.w.oil_original_view then
      vim.fn.winrestview(vim.w.oil_original_view)
    end
    return
  end

  -- Deleting the buffer closes all windows with that buffer open, so navigate to a different
  -- buffer first
  local oilbuf = vim.api.nvim_get_current_buf()
  ok = pcall(vim.cmd.bprev)
  -- If `bprev` failed, there are no buffers open
  if not ok then
    -- either exit or create a new blank buffer
    if opts.exit_if_last_buf then
      vim.cmd.quit()
    else
      vim.cmd.enew()
    end
  end
  vim.api.nvim_buf_delete(oilbuf, { force = true })
end

---@class oil.OpenPreviewOpts
---@field vertical? boolean Open the buffer in a vertical split
---@field horizontal? boolean Open the buffer in a horizontal split
---@field split? "aboveleft"|"belowright"|"topleft"|"botright" Split modifier

---Preview the entry under the cursor in a split
---@param opts? oil.OpenPreviewOpts
---@param callback? fun(err: nil|string) Called once the preview window has been opened
M.open_preview = function(opts, callback)
  opts = opts or {}
  local config = require("oil.config")
  local layout = require("oil.layout")
  local util = require("oil.util")

  local function finish(err)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    if callback then
      callback(err)
    end
  end

  if not opts.horizontal and opts.vertical == nil then
    opts.vertical = true
  end
  if not opts.split then
    if opts.horizontal then
      opts.split = vim.o.splitbelow and "belowright" or "aboveleft"
    else
      opts.split = vim.o.splitright and "belowright" or "aboveleft"
    end
  end

  local preview_win = util.get_preview_win({ include_not_owned = true })
  local prev_win = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()

  local entry = M.get_cursor_entry()
  if not entry then
    return finish("Could not find entry under cursor")
  end
  local entry_title = entry.name
  if entry.type == "directory" then
    entry_title = entry_title .. "/"
  end

  if util.is_floating_win() then
    if preview_win == nil then
      local root_win_opts, preview_win_opts =
        layout.split_window(0, config.float.preview_split, config.float.padding)

      local win_opts_oil = {
        relative = "editor",
        width = root_win_opts.width,
        height = root_win_opts.height,
        row = root_win_opts.row,
        col = root_win_opts.col,
        border = config.float.border,
        zindex = 45,
      }
      vim.api.nvim_win_set_config(0, win_opts_oil)
      local win_opts = {
        relative = "editor",
        width = preview_win_opts.width,
        height = preview_win_opts.height,
        row = preview_win_opts.row,
        col = preview_win_opts.col,
        border = config.float.border,
        zindex = 45,
        focusable = false,
        noautocmd = true,
        style = "minimal",
      }

      if vim.fn.has("nvim-0.9") == 1 then
        win_opts.title = entry_title
      end

      preview_win = vim.api.nvim_open_win(bufnr, true, win_opts)
      vim.api.nvim_set_option_value("previewwindow", true, { scope = "local", win = preview_win })
      vim.api.nvim_win_set_var(preview_win, "oil_preview", true)
      vim.api.nvim_set_current_win(prev_win)
    elseif vim.fn.has("nvim-0.9") == 1 then
      vim.api.nvim_win_set_config(preview_win, { title = entry_title })
    end
  end

  local cmd = preview_win and "buffer" or "sbuffer"
  local mods = {
    vertical = opts.vertical,
    horizontal = opts.horizontal,
    split = opts.split,
  }

  -- HACK Switching windows takes us out of visual mode.
  -- Switching with nvim_set_current_win causes the previous visual selection (as used by `gv`) to
  -- not get set properly. So we have to switch windows this way instead.
  local hack_set_win = function(winid)
    local winnr = vim.api.nvim_win_get_number(winid)
    vim.cmd.wincmd({ args = { "w" }, count = winnr })
  end

  util.get_edit_path(bufnr, entry, function(normalized_url)
    local is_visual_mode = util.is_visual_mode()
    if preview_win then
      if is_visual_mode then
        hack_set_win(preview_win)
      else
        vim.api.nvim_set_current_win(preview_win)
      end
    end

    local entry_is_file = not vim.endswith(normalized_url, "/")
    local filebufnr
    if entry_is_file then
      if config.preview_win.disable_preview(normalized_url) then
        filebufnr = vim.api.nvim_create_buf(false, true)
        vim.bo[filebufnr].bufhidden = "wipe"
        vim.bo[filebufnr].buftype = "nofile"
        util.render_text(filebufnr, "Preview disabled", { winid = preview_win })
      elseif
        config.preview_win.preview_method ~= "load"
        and not util.file_matches_bufreadcmd(normalized_url)
      then
        filebufnr =
          util.read_file_to_scratch_buffer(normalized_url, config.preview_win.preview_method)
      end
    end

    if not filebufnr then
      filebufnr = vim.fn.bufadd(normalized_url)
      if entry_is_file and vim.fn.bufloaded(filebufnr) == 0 then
        vim.bo[filebufnr].bufhidden = "wipe"
        vim.b[filebufnr].oil_preview_buffer = true
      end
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, err = pcall(vim.cmd, {
      cmd = cmd,
      args = { filebufnr },
      mods = mods,
    })
    -- Ignore swapfile errors
    if not ok and err and not err:match("^Vim:E325:") then
      vim.api.nvim_echo({ { err, "Error" } }, true, {})
    end

    -- If we called open_preview during an autocmd, then the edit command may not trigger the
    -- BufReadCmd to load the buffer. So we need to do it manually.
    if util.is_oil_bufnr(filebufnr) then
      M.load_oil_buffer(filebufnr)
    end

    vim.api.nvim_set_option_value("previewwindow", true, { scope = "local", win = 0 })
    vim.api.nvim_win_set_var(0, "oil_preview", true)
    for k, v in pairs(config.preview_win.win_options) do
      vim.api.nvim_set_option_value(k, v, { scope = "local", win = preview_win })
    end
    vim.w.oil_entry_id = entry.id
    vim.w.oil_source_win = prev_win
    if is_visual_mode then
      hack_set_win(prev_win)
      -- Restore the visual selection
      vim.cmd.normal({ args = { "gv" }, bang = true })
    else
      vim.api.nvim_set_current_win(prev_win)
    end
    finish()
  end)
end

---@class (exact) oil.SelectOpts
---@field vertical? boolean Open the buffer in a vertical split
---@field horizontal? boolean Open the buffer in a horizontal split
---@field split? "aboveleft"|"belowright"|"topleft"|"botright" Split modifier
---@field tab? boolean Open the buffer in a new tab
---@field close? boolean Close the original oil buffer once selection is made

---Select the entry under the cursor
---@param opts nil|oil.SelectOpts
---@param callback nil|fun(err: nil|string) Called once all entries have been opened
M.select = function(opts, callback)
  local cache = require("oil.cache")
  local config = require("oil.config")
  local constants = require("oil.constants")
  local util = require("oil.util")
  local FIELD_META = constants.FIELD_META
  opts = vim.tbl_extend("keep", opts or {}, {})

  local function finish(err)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    if callback then
      callback(err)
    end
  end
  if not opts.split and (opts.horizontal or opts.vertical) then
    if opts.horizontal then
      opts.split = vim.o.splitbelow and "belowright" or "aboveleft"
    else
      opts.split = vim.o.splitright and "belowright" or "aboveleft"
    end
  end
  if opts.tab and opts.split then
    return finish("Cannot use split=true when tab = true")
  end
  local adapter = util.get_adapter(0)
  if not adapter then
    return finish("Not an oil buffer")
  end

  local visual_range = util.get_visual_range()

  ---@type oil.Entry[]
  local entries = {}
  if visual_range then
    for i = visual_range.start_lnum, visual_range.end_lnum do
      local entry = M.get_entry_on_line(0, i)
      if entry then
        table.insert(entries, entry)
      end
    end
  else
    local entry = M.get_cursor_entry()
    if entry then
      table.insert(entries, entry)
    end
  end
  if vim.tbl_isempty(entries) then
    return finish("Could not find entry under cursor")
  end

  -- Check if any of these entries are moved from their original location
  local bufname = vim.api.nvim_buf_get_name(0)
  local any_moved = false
  for _, entry in ipairs(entries) do
    -- Ignore entries with ID 0 (typically the "../" entry)
    if entry.id ~= 0 then
      local is_new_entry = entry.id == nil
      local is_moved_from_dir = entry.id and cache.get_parent_url(entry.id) ~= bufname
      local is_renamed = entry.parsed_name ~= entry.name
      local internal_entry = entry.id and cache.get_entry_by_id(entry.id)
      if internal_entry then
        local meta = internal_entry[FIELD_META]
        if meta and meta.display_name then
          is_renamed = entry.parsed_name ~= meta.display_name
        end
      end
      if is_new_entry or is_moved_from_dir or is_renamed then
        any_moved = true
        break
      end
    end
  end
  if any_moved and config.prompt_save_on_select_new_entry then
    local ok, choice = pcall(vim.fn.confirm, "Save changes?", "Yes\nNo", 1)
    if not ok then
      return finish()
    elseif choice == 1 then
      M.save()
      return finish()
    end
  end

  local prev_win = vim.api.nvim_get_current_win()
  local oil_bufnr = vim.api.nvim_get_current_buf()

  -- Async iter over entries so we can normalize the url before opening
  local i = 1
  local function open_next_entry(cb)
    local entry = entries[i]
    i = i + 1
    if not entry then
      return cb()
    end
    if util.is_directory(entry) then
      -- If this is a new directory BUT we think we already have an entry with this name, disallow
      -- entry. This prevents the case of MOVE /foo -> /bar + CREATE /foo.
      -- If you enter the new /foo, it will show the contents of the old /foo.
      if not entry.id and cache.list_url(bufname)[entry.name] then
        return cb("Please save changes before entering new directory")
      end
    else
      -- Close floating window before opening a file
      if vim.w.is_oil_win then
        M.close()
      end
    end

    -- Normalize the url before opening to prevent needing to rename them inside the BufReadCmd
    -- Renaming buffers during opening can lead to missed autocmds
    util.get_edit_path(oil_bufnr, entry, function(normalized_url)
      local mods = {
        vertical = opts.vertical,
        horizontal = opts.horizontal,
        split = opts.split,
        keepalt = false,
      }
      local filebufnr = vim.fn.bufadd(normalized_url)
      local entry_is_file = not vim.endswith(normalized_url, "/")

      -- The :buffer command doesn't set buflisted=true
      -- So do that for normal files or for oil dirs if config set buflisted=true
      if entry_is_file or config.buf_options.buflisted then
        vim.bo[filebufnr].buflisted = true
      end

      local cmd = "buffer"
      if opts.tab then
        vim.cmd.tabnew({ mods = mods })
        -- Make sure the new buffer from tabnew gets cleaned up
        vim.bo.bufhidden = "wipe"
      elseif opts.split then
        cmd = "sbuffer"
      end
      ---@diagnostic disable-next-line: param-type-mismatch
      local ok, err = pcall(vim.cmd, {
        cmd = cmd,
        args = { filebufnr },
        mods = mods,
      })
      -- Ignore swapfile errors
      if not ok and err and not err:match("^Vim:E325:") then
        vim.api.nvim_echo({ { err, "Error" } }, true, {})
      end

      open_next_entry(cb)
    end)
  end

  open_next_entry(function(err)
    if err then
      return finish(err)
    end
    if
      opts.close
      and vim.api.nvim_win_is_valid(prev_win)
      and prev_win ~= vim.api.nvim_get_current_win()
    then
      vim.api.nvim_win_call(prev_win, function()
        M.close()
      end)
    end

    update_preview_window()

    finish()
  end)
end

---@param bufnr integer
---@return boolean
local function maybe_hijack_directory_buffer(bufnr)
  local config = require("oil.config")
  local fs = require("oil.fs")
  local util = require("oil.util")
  if not config.default_file_explorer then
    return false
  end
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" then
    return false
  end
  if util.parse_url(bufname) or vim.fn.isdirectory(bufname) == 0 then
    return false
  end
  local new_name = util.addslash(
    config.adapter_to_scheme.files .. fs.os_to_posix_path(vim.fn.fnamemodify(bufname, ":p"))
  )
  local replaced = util.rename_buffer(bufnr, new_name)
  return not replaced
end

---@private
M._get_highlights = function()
  return {
    {
      name = "OilHidden",
      link = "Comment",
      desc = "Hidden entry in an oil buffer",
    },
    {
      name = "OilDir",
      link = "Directory",
      desc = "Directory names in an oil buffer",
    },
    {
      name = "OilDirHidden",
      link = "OilHidden",
      desc = "Hidden directory names in an oil buffer",
    },
    {
      name = "OilDirIcon",
      link = "OilDir",
      desc = "Icon for directories",
    },
    {
      name = "OilSocket",
      link = "Keyword",
      desc = "Socket files in an oil buffer",
    },
    {
      name = "OilSocketHidden",
      link = "OilHidden",
      desc = "Hidden socket files in an oil buffer",
    },
    {
      name = "OilLink",
      link = nil,
      desc = "Soft links in an oil buffer",
    },
    {
      name = "OilOrphanLink",
      link = nil,
      desc = "Orphaned soft links in an oil buffer",
    },
    {
      name = "OilLinkHidden",
      link = "OilHidden",
      desc = "Hidden soft links in an oil buffer",
    },
    {
      name = "OilOrphanLinkHidden",
      link = "OilLinkHidden",
      desc = "Hidden orphaned soft links in an oil buffer",
    },
    {
      name = "OilLinkTarget",
      link = "Comment",
      desc = "The target of a soft link",
    },
    {
      name = "OilOrphanLinkTarget",
      link = "DiagnosticError",
      desc = "The target of an orphaned soft link",
    },
    {
      name = "OilLinkTargetHidden",
      link = "OilHidden",
      desc = "The target of a hidden soft link",
    },
    {
      name = "OilOrphanLinkTargetHidden",
      link = "OilOrphanLinkTarget",
      desc = "The target of an hidden orphaned soft link",
    },
    {
      name = "OilFile",
      link = nil,
      desc = "Normal files in an oil buffer",
    },
    {
      name = "OilFileHidden",
      link = "OilHidden",
      desc = "Hidden normal files in an oil buffer",
    },
    {
      name = "OilCreate",
      link = "DiagnosticInfo",
      desc = "Create action in the oil preview window",
    },
    {
      name = "OilDelete",
      link = "DiagnosticError",
      desc = "Delete action in the oil preview window",
    },
    {
      name = "OilMove",
      link = "DiagnosticWarn",
      desc = "Move action in the oil preview window",
    },
    {
      name = "OilCopy",
      link = "DiagnosticHint",
      desc = "Copy action in the oil preview window",
    },
    {
      name = "OilChange",
      link = "Special",
      desc = "Change action in the oil preview window",
    },
    {
      name = "OilRestore",
      link = "OilCreate",
      desc = "Restore (from the trash) action in the oil preview window",
    },
    {
      name = "OilPurge",
      link = "OilDelete",
      desc = "Purge (Permanently delete a file from trash) action in the oil preview window",
    },
    {
      name = "OilTrash",
      link = "OilDelete",
      desc = "Trash (delete a file to trash) action in the oil preview window",
    },
    {
      name = "OilTrashSourcePath",
      link = "Comment",
      desc = "Virtual text that shows the original path of file in the trash",
    },
  }
end

local function set_colors()
  for _, conf in ipairs(M._get_highlights()) do
    if conf.link then
      vim.api.nvim_set_hl(0, conf.name, { default = true, link = conf.link })
    end
  end
  -- TODO can remove this call once we drop support for Neovim 0.8. FloatTitle was introduced as a
  -- built-in highlight group in 0.9, and we can start to rely on colorschemes setting it.
  ---@diagnostic disable-next-line: deprecated
  if vim.fn.has("nvim-0.9") == 0 and not pcall(vim.api.nvim_get_hl_by_name, "FloatTitle", true) then
    ---@diagnostic disable-next-line: deprecated
    local border = vim.api.nvim_get_hl_by_name("FloatBorder", true)
    ---@diagnostic disable-next-line: deprecated
    local normal = vim.api.nvim_get_hl_by_name("Normal", true)
    vim.api.nvim_set_hl(
      0,
      "FloatTitle",
      { fg = normal.foreground, bg = border.background or normal.background }
    )
  end
end

---Save all changes
---@param opts nil|table
---    confirm nil|boolean Show confirmation when true, never when false, respect skip_confirm_for_simple_edits if nil
---@param cb? fun(err: nil|string) Called when mutations complete.
---@note
--- If you provide your own callback function, there will be no notification for errors.
M.save = function(opts, cb)
  opts = opts or {}
  if not cb then
    cb = function(err)
      if err and err ~= "Canceled" then
        vim.notify(err, vim.log.levels.ERROR)
      end
    end
  end
  local mutator = require("oil.mutator")
  mutator.try_write_changes(opts.confirm, cb)
end

local function restore_alt_buf()
  if vim.bo.filetype == "oil" then
    require("oil.view").set_win_options()
    vim.api.nvim_win_set_var(0, "oil_did_enter", true)
  elseif vim.w.oil_did_enter then
    vim.api.nvim_win_del_var(0, "oil_did_enter")
    -- We are entering a non-oil buffer *after* having been in an oil buffer
    local has_orig, orig_buffer = pcall(vim.api.nvim_win_get_var, 0, "oil_original_buffer")
    if has_orig and vim.api.nvim_buf_is_valid(orig_buffer) then
      if vim.api.nvim_get_current_buf() ~= orig_buffer then
        -- If we are editing a new file after navigating around oil, set the alternate buffer
        -- to be the last buffer we were in before opening oil
        vim.fn.setreg("#", orig_buffer)
      else
        -- If we are editing the same buffer that we started oil from, set the alternate to be
        -- what it was before we opened oil
        local has_orig_alt, alt_buffer =
          pcall(vim.api.nvim_win_get_var, 0, "oil_original_alternate")
        if has_orig_alt and vim.api.nvim_buf_is_valid(alt_buffer) then
          vim.fn.setreg("#", alt_buffer)
        end
      end
    end
  end
end

---@private
---@param bufnr integer
M.load_oil_buffer = function(bufnr)
  local config = require("oil.config")
  local keymap_util = require("oil.keymap_util")
  local loading = require("oil.loading")
  local util = require("oil.util")
  local view = require("oil.view")
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local scheme, path = util.parse_url(bufname)
  if config.adapter_aliases[scheme] then
    scheme = config.adapter_aliases[scheme]
    bufname = scheme .. path
    util.rename_buffer(bufnr, bufname)
  end

  -- Early return if we're already loading or have already loaded this buffer
  if loading.is_loading(bufnr) or vim.b[bufnr].filetype ~= nil then
    return
  end

  local adapter = assert(config.get_adapter_by_scheme(scheme))

  if vim.endswith(bufname, "/") then
    -- This is a small quality-of-life thing. If the buffer name ends with a `/`, we know it's a
    -- directory, and can set the filetype early. This is helpful for adapters with a lot of latency
    -- (e.g. ssh) because it will set up the filetype keybinds at the *beginning* of the loading
    -- process.
    vim.bo[bufnr].filetype = "oil"
    keymap_util.set_keymaps(config.keymaps, bufnr)
  end
  loading.set_loading(bufnr, true)
  local winid = vim.api.nvim_get_current_win()
  local function finish(new_url)
    -- If the buffer was deleted while we were normalizing the name, early return
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    -- Since this was async, we may have left the window with this buffer. People often write
    -- BufReadPre/Post autocmds with the expectation that the current window is the one that
    -- contains the buffer. Let's then do our best to make sure that that assumption isn't violated.
    winid = util.buf_get_win(bufnr, winid) or vim.api.nvim_get_current_win()
    vim.api.nvim_win_call(winid, function()
      if new_url ~= bufname then
        if util.rename_buffer(bufnr, new_url) then
          -- If the buffer was replaced then don't initialize it. It's dead. The replacement will
          -- have BufReadCmd called for it
          return
        end

        -- If the renamed buffer doesn't have a scheme anymore, this is a normal file.
        -- Finish setting it up as a normal buffer.
        local new_scheme = util.parse_url(new_url)
        if not new_scheme then
          loading.set_loading(bufnr, false)
          vim.cmd.doautocmd({ args = { "BufReadPre", new_url }, mods = { emsg_silent = true } })
          vim.cmd.doautocmd({ args = { "BufReadPost", new_url }, mods = { emsg_silent = true } })
          return
        end

        bufname = new_url
      end
      if vim.endswith(bufname, "/") then
        vim.cmd.doautocmd({ args = { "BufReadPre", bufname }, mods = { emsg_silent = true } })
        view.initialize(bufnr)
        vim.cmd.doautocmd({ args = { "BufReadPost", bufname }, mods = { emsg_silent = true } })
      else
        vim.bo[bufnr].buftype = "acwrite"
        adapter.read_file(bufnr)
      end
      restore_alt_buf()
    end)
  end

  adapter.normalize_url(bufname, finish)
end

local function close_preview_window_if_not_in_oil()
  local util = require("oil.util")
  local preview_win_id = util.get_preview_win()
  if not preview_win_id or not vim.w[preview_win_id].oil_entry_id then
    return
  end

  local oil_source_win = vim.w[preview_win_id].oil_source_win
  if oil_source_win and vim.api.nvim_win_is_valid(oil_source_win) then
    local src_buf = vim.api.nvim_win_get_buf(oil_source_win)
    if util.is_oil_bufnr(src_buf) then
      return
    end
  end

  -- This can fail if it's the last window open
  pcall(vim.api.nvim_win_close, preview_win_id, true)
end

local _on_key_ns = 0
---Initialize oil
---@param opts oil.setupOpts|nil
M.setup = function(opts)
  local Ringbuf = require("oil.ringbuf")
  local config = require("oil.config")

  config.setup(opts)
  set_colors()
  vim.api.nvim_create_user_command("Oil", function(args)
    local util = require("oil.util")
    if args.smods.tab == 1 then
      vim.cmd.tabnew()
    end
    local float = false
    local trash = false
    local preview = false
    local i = 1
    while i <= #args.fargs do
      local v = args.fargs[i]
      if v == "--float" then
        float = true
        table.remove(args.fargs, i)
      elseif v == "--trash" then
        trash = true
        table.remove(args.fargs, i)
      elseif v == "--preview" then
        -- In the future we may want to support specifying options for the preview window (e.g.
        -- vertical/horizontal), but if you want that level of control maybe just use the API
        preview = true
        table.remove(args.fargs, i)
      elseif v == "--progress" then
        local mutator = require("oil.mutator")
        if mutator.is_mutating() then
          mutator.show_progress()
        else
          vim.notify("No mutation in progress", vim.log.levels.WARN)
        end
        return
      else
        i = i + 1
      end
    end

    if not float and (args.smods.vertical or args.smods.split ~= "") then
      if args.smods.vertical then
        vim.cmd.vsplit({ mods = { split = args.smods.split } })
      else
        vim.cmd.split({ mods = { split = args.smods.split } })
      end
    end

    local method = float and "open_float" or "open"
    local path = args.fargs[1]
    local open_opts = {}
    if trash then
      local url = M.get_url_for_path(path, false)
      local _, new_path = util.parse_url(url)
      path = "oil-trash://" .. new_path
    end
    if preview then
      open_opts.preview = {}
    end
    M[method](path, open_opts)
  end, { desc = "Open oil file browser on a directory", nargs = "*", complete = "dir" })
  local aug = vim.api.nvim_create_augroup("Oil", {})

  if config.default_file_explorer then
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    -- If netrw was already loaded, clear this augroup
    if vim.fn.exists("#FileExplorer") then
      vim.api.nvim_create_augroup("FileExplorer", { clear = true })
    end
  end

  local patterns = {}
  local filetype_patterns = {}
  for scheme in pairs(config.adapters) do
    table.insert(patterns, scheme .. "*")
    filetype_patterns[scheme .. ".*"] = { "oil", { priority = 10 } }
  end
  for scheme in pairs(config.adapter_aliases) do
    table.insert(patterns, scheme .. "*")
    filetype_patterns[scheme .. ".*"] = { "oil", { priority = 10 } }
  end
  local scheme_pattern = table.concat(patterns, ",")
  -- We need to add these patterns to the filetype matcher so the filetype doesn't get overridden
  -- by other patterns. See https://github.com/stevearc/oil.nvim/issues/47
  vim.filetype.add({
    pattern = filetype_patterns,
  })

  local keybuf = Ringbuf.new(7)
  if _on_key_ns == 0 then
    _on_key_ns = vim.on_key(function(char)
      keybuf:push(char)
    end, _on_key_ns)
  end
  vim.api.nvim_create_autocmd("ColorScheme", {
    desc = "Set default oil highlights",
    group = aug,
    pattern = "*",
    callback = set_colors,
  })
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = aug,
    pattern = scheme_pattern,
    nested = true,
    callback = function(params)
      M.load_oil_buffer(params.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = aug,
    pattern = scheme_pattern,
    nested = true,
    callback = function(params)
      local last_keys = keybuf:as_str()
      local winid = vim.api.nvim_get_current_win()
      -- If the user issued a :wq or similar, we should quit after saving
      local quit_after_save = vim.endswith(last_keys, ":wq\r")
        or vim.endswith(last_keys, ":x\r")
        or vim.endswith(last_keys, "ZZ")
      local quit_all = vim.endswith(last_keys, ":wqa\r")
        or vim.endswith(last_keys, ":wqal\r")
        or vim.endswith(last_keys, ":wqall\r")
      local bufname = vim.api.nvim_buf_get_name(params.buf)
      if vim.endswith(bufname, "/") then
        vim.cmd.doautocmd({ args = { "BufWritePre", params.file }, mods = { silent = true } })
        M.save(nil, function(err)
          if err then
            if err ~= "Canceled" then
              vim.notify(err, vim.log.levels.ERROR)
            end
          elseif winid == vim.api.nvim_get_current_win() then
            if quit_after_save then
              vim.cmd.quit()
            elseif quit_all then
              vim.cmd.quitall()
            end
          end
        end)
        vim.cmd.doautocmd({ args = { "BufWritePost", params.file }, mods = { silent = true } })
      else
        local adapter = assert(config.get_adapter_by_scheme(bufname))
        adapter.write_file(params.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    desc = "Save alternate buffer for later",
    group = aug,
    pattern = "*",
    callback = function()
      local util = require("oil.util")
      if not util.is_oil_bufnr(0) then
        vim.w.oil_original_buffer = vim.api.nvim_get_current_buf()
        vim.w.oil_original_view = vim.fn.winsaveview()
        ---@diagnostic disable-next-line: param-type-mismatch
        vim.w.oil_original_alternate = vim.fn.bufnr("#")
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    desc = "Set/unset oil window options and restore alternate buffer",
    group = aug,
    pattern = "*",
    callback = function()
      local util = require("oil.util")
      local bufname = vim.api.nvim_buf_get_name(0)
      local scheme = util.parse_url(bufname)
      if scheme and config.adapters[scheme] then
        local view = require("oil.view")
        view.maybe_set_cursor()
        -- While we are in an oil buffer, set the alternate file to the buffer we were in prior to
        -- opening oil
        local has_orig, orig_buffer = pcall(vim.api.nvim_win_get_var, 0, "oil_original_buffer")
        if has_orig and vim.api.nvim_buf_is_valid(orig_buffer) then
          vim.fn.setreg("#", orig_buffer)
        end
        view.set_win_options()
        vim.w.oil_did_enter = true
      elseif vim.fn.isdirectory(bufname) == 0 then
        -- Only run this logic if we are *not* in an oil buffer (and it's not a directory, which
        -- will be replaced by an oil:// url)
        -- Oil buffers have to run it in BufReadCmd after confirming they are a directory or a file
        restore_alt_buf()
      end

      close_preview_window_if_not_in_oil()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew", "WinEnter" }, {
    desc = "Reset bufhidden when entering a preview buffer",
    group = aug,
    pattern = "*",
    callback = function()
      -- If we have entered a "preview" buffer in a non-preview window, reset bufhidden
      if vim.b.oil_preview_buffer and not vim.wo.previewwindow then
        vim.bo.bufhidden = vim.api.nvim_get_option_value("bufhidden", { scope = "global" })
        vim.b.oil_preview_buffer = nil
      end
    end,
  })
  if not config.silence_scp_warning then
    vim.api.nvim_create_autocmd("BufNew", {
      desc = "Warn about scp:// usage",
      group = aug,
      pattern = "scp://*",
      once = true,
      callback = function()
        vim.notify(
          "If you are trying to browse using Oil, use oil-ssh:// instead of scp://\nSet `silence_scp_warning = true` in oil.setup() to disable this message.\nSee https://github.com/stevearc/oil.nvim/issues/27 for more information.",
          vim.log.levels.WARN
        )
      end,
    })
  end
  vim.api.nvim_create_autocmd("WinNew", {
    desc = "Restore window options when splitting an oil window",
    group = aug,
    pattern = "*",
    nested = true,
    callback = function(params)
      local util = require("oil.util")
      if not util.is_oil_bufnr(params.buf) or vim.w.oil_did_enter then
        return
      end
      -- This new window is a split off of an oil window. We need to transfer the window
      -- variables. First, locate the parent window
      local parent_win
      -- First search windows in this tab, then search all windows
      local winids = vim.list_extend(vim.api.nvim_tabpage_list_wins(0), vim.api.nvim_list_wins())
      for _, winid in ipairs(winids) do
        if vim.api.nvim_win_is_valid(winid) then
          if vim.w[winid].oil_did_enter then
            parent_win = winid
            break
          end
        end
      end
      if not parent_win then
        vim.notify(
          "Oil split could not find parent window. Please try to replicate whatever you just did and report a bug on github",
          vim.log.levels.WARN
        )
        return
      end

      -- Then transfer over the relevant window vars
      vim.w.oil_did_enter = true
      vim.w.oil_original_buffer = vim.w[parent_win].oil_original_buffer
      vim.w.oil_original_view = vim.w[parent_win].oil_original_view
      vim.w.oil_original_alternate = vim.w[parent_win].oil_original_alternate
    end,
  })
  vim.api.nvim_create_autocmd("BufAdd", {
    desc = "Detect directory buffer and open oil file browser",
    group = aug,
    pattern = "*",
    nested = true,
    callback = function(params)
      maybe_hijack_directory_buffer(params.buf)
    end,
  })
  -- mksession doesn't save oil buffers in a useful way. We have to manually load them after a
  -- session finishes loading. See https://github.com/stevearc/oil.nvim/issues/29
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    desc = "Load oil buffers after a session is loaded",
    group = aug,
    pattern = "*",
    callback = function(params)
      if vim.g.SessionLoad ~= 1 then
        return
      end
      local util = require("oil.util")
      local scheme = util.parse_url(params.file)
      if config.adapters[scheme] and vim.api.nvim_buf_line_count(params.buf) == 1 then
        M.load_oil_buffer(params.buf)
      end
    end,
  })

  local bufnr = vim.api.nvim_get_current_buf()
  if maybe_hijack_directory_buffer(bufnr) and vim.v.vim_did_enter == 1 then
    -- manually call load on a hijacked directory buffer if vim has already entered
    -- (the BufReadCmd will not trigger)
    M.load_oil_buffer(bufnr)
  end
end

return M
