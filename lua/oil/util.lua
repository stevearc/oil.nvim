local config = require("oil.config")
local constants = require("oil.constants")

local M = {}

local FIELD_ID = constants.FIELD_ID
local FIELD_NAME = constants.FIELD_NAME
local FIELD_TYPE = constants.FIELD_TYPE
local FIELD_META = constants.FIELD_META

---@alias oil.IconProvider fun(type: string, name: string, conf: table?): (icon: string, hl: string)

---@param url string
---@return nil|string
---@return nil|string
M.parse_url = function(url)
  return url:match("^(.*://)(.*)$")
end

---Escapes a filename for use in :edit
---@param filename string
---@return string
M.escape_filename = function(filename)
  local ret = vim.fn.fnameescape(filename)
  return ret
end

local _url_escape_to_char = {
  ["20"] = " ",
  ["22"] = "“",
  ["23"] = "#",
  ["24"] = "$",
  ["25"] = "%",
  ["26"] = "&",
  ["27"] = "‘",
  ["2B"] = "+",
  ["2C"] = ",",
  ["2F"] = "/",
  ["3A"] = ":",
  ["3B"] = ";",
  ["3C"] = "<",
  ["3D"] = "=",
  ["3E"] = ">",
  ["3F"] = "?",
  ["40"] = "@",
  ["5B"] = "[",
  ["5C"] = "\\",
  ["5D"] = "]",
  ["5E"] = "^",
  ["60"] = "`",
  ["7B"] = "{",
  ["7C"] = "|",
  ["7D"] = "}",
  ["7E"] = "~",
}
local _char_to_url_escape = {}
for k, v in pairs(_url_escape_to_char) do
  _char_to_url_escape[v] = "%" .. k
end
-- TODO this uri escape handling is very incomplete

---@param string string
---@return string
M.url_escape = function(string)
  return (string:gsub(".", _char_to_url_escape))
end

---@param string string
---@return string
M.url_unescape = function(string)
  return (
    string:gsub("%%([0-9A-Fa-f][0-9A-Fa-f])", function(seq)
      return _url_escape_to_char[seq:upper()] or ("%" .. seq)
    end)
  )
end

---@param bufnr integer
---@param silent? boolean
---@return nil|oil.Adapter
M.get_adapter = function(bufnr, silent)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local adapter = config.get_adapter_by_scheme(bufname)
  if not adapter and not silent then
    vim.notify_once(
      string.format("[oil] could not find adapter for buffer '%s://'", bufname),
      vim.log.levels.ERROR
    )
  end
  return adapter
end

---@param text string
---@param length nil|integer
---@return string
M.rpad = function(text, length)
  if not length then
    return text
  end
  local textlen = vim.api.nvim_strwidth(text)
  local delta = length - textlen
  if delta > 0 then
    return text .. string.rep(" ", delta)
  else
    return text
  end
end

---@param text string
---@param length nil|integer
---@return string
M.lpad = function(text, length)
  if not length then
    return text
  end
  local textlen = vim.api.nvim_strwidth(text)
  local delta = length - textlen
  if delta > 0 then
    return string.rep(" ", delta) .. text
  else
    return text
  end
end

---@generic T : any
---@param tbl T[]
---@param start_idx? number
---@param end_idx? number
---@return T[]
M.tbl_slice = function(tbl, start_idx, end_idx)
  local ret = {}
  if not start_idx then
    start_idx = 1
  end
  if not end_idx then
    end_idx = #tbl
  end
  for i = start_idx, end_idx do
    table.insert(ret, tbl[i])
  end
  return ret
end

---@param entry oil.InternalEntry
---@return oil.Entry
M.export_entry = function(entry)
  return {
    name = entry[FIELD_NAME],
    type = entry[FIELD_TYPE],
    id = entry[FIELD_ID],
    meta = entry[FIELD_META],
  }
end

---@param src_bufnr integer|string Buffer number or name
---@param dest_buf_name string
---@return boolean True if the buffer was replaced instead of renamed
M.rename_buffer = function(src_bufnr, dest_buf_name)
  if type(src_bufnr) == "string" then
    src_bufnr = vim.fn.bufadd(src_bufnr)
    if not vim.api.nvim_buf_is_loaded(src_bufnr) then
      vim.api.nvim_buf_delete(src_bufnr, {})
      return false
    end
  end

  local bufname = vim.api.nvim_buf_get_name(src_bufnr)
  -- If this buffer is not literally a file on disk, then we can use the simple
  -- rename logic. The only reason we can't use nvim_buf_set_name on files is because vim will
  -- think that the new buffer conflicts with the file next time it tries to save.
  if not vim.loop.fs_stat(dest_buf_name) then
    ---@diagnostic disable-next-line: param-type-mismatch
    local altbuf = vim.fn.bufnr("#")
    -- This will fail if the dest buf name already exists
    local ok = pcall(vim.api.nvim_buf_set_name, src_bufnr, dest_buf_name)
    if ok then
      -- Renaming the buffer creates a new buffer with the old name.
      -- Find it and try to delete it, but don't if the buffer is in a context
      -- where Neovim doesn't allow buffer modifications.
      pcall(vim.api.nvim_buf_delete, vim.fn.bufadd(bufname), {})
      if altbuf and vim.api.nvim_buf_is_valid(altbuf) then
        vim.fn.setreg("#", altbuf)
      end

      return false
    end
  end

  local is_modified = vim.bo[src_bufnr].modified
  local dest_bufnr = vim.fn.bufadd(dest_buf_name)
  pcall(vim.fn.bufload, dest_bufnr)
  if vim.bo[src_bufnr].buflisted then
    vim.bo[dest_bufnr].buflisted = true
  end
  -- If the src_bufnr was marked as modified by the previous operation, we should undo that
  vim.bo[src_bufnr].modified = is_modified

  -- If we're renaming a buffer that we're about to enter, this may be called before the buffer is
  -- actually in the window. We need to wait to enter the buffer and _then_ replace it.
  vim.schedule(function()
    -- Find any windows with the old buffer and replace them
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(winid) then
        if vim.api.nvim_win_get_buf(winid) == src_bufnr then
          vim.api.nvim_win_set_buf(winid, dest_bufnr)
        end
      end
    end
    if vim.api.nvim_buf_is_valid(src_bufnr) then
      if vim.bo[src_bufnr].modified then
        local src_lines = vim.api.nvim_buf_get_lines(src_bufnr, 0, -1, true)
        vim.api.nvim_buf_set_lines(dest_bufnr, 0, -1, true, src_lines)
      end
      -- Try to delete, but don't if the buffer has changes
      pcall(vim.api.nvim_buf_delete, src_bufnr, {})
    end
    -- Renaming a buffer won't load the undo file, so we need to do that manually
    if vim.bo[dest_bufnr].undofile then
      vim.api.nvim_buf_call(dest_bufnr, function()
        vim.cmd.rundo({
          args = { vim.fn.undofile(dest_buf_name) },
          magic = { file = false, bar = false },
          mods = {
            emsg_silent = true,
          },
        })
      end)
    end
  end)
  return true
end

---@param count integer
---@param cb fun(err: nil|string)
M.cb_collect = function(count, cb)
  return function(err)
    if err then
      cb(err)
      cb = function() end
    else
      count = count - 1
      if count == 0 then
        cb()
      end
    end
  end
end

---@param url string
---@return string[]
local function get_possible_buffer_names_from_url(url)
  local fs = require("oil.fs")
  local scheme, path = M.parse_url(url)
  if config.adapters[scheme] == "files" then
    assert(path)
    return { fs.posix_to_os_path(path) }
  end
  return { url }
end

---@param entry_type oil.EntryType
---@param src_url string
---@param dest_url string
M.update_moved_buffers = function(entry_type, src_url, dest_url)
  local src_buf_names = get_possible_buffer_names_from_url(src_url)
  local dest_buf_name = get_possible_buffer_names_from_url(dest_url)[1]
  if entry_type ~= "directory" then
    for _, src_buf_name in ipairs(src_buf_names) do
      M.rename_buffer(src_buf_name, dest_buf_name)
    end
  else
    M.rename_buffer(M.addslash(src_url), M.addslash(dest_url))
    -- If entry type is directory, we need to rename this buffer, and then update buffers that are
    -- inside of this directory

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      if vim.startswith(bufname, src_url) then
        -- Handle oil directory buffers
        vim.api.nvim_buf_set_name(bufnr, dest_url .. bufname:sub(src_url:len() + 1))
      elseif bufname ~= "" and vim.bo[bufnr].buftype == "" then
        -- Handle regular buffers
        local scheme = M.parse_url(bufname)

        -- If the buffer is a local file, make sure we're using the absolute path
        if not scheme then
          bufname = vim.fn.fnamemodify(bufname, ":p")
        end

        for _, src_buf_name in ipairs(src_buf_names) do
          if vim.startswith(bufname, src_buf_name) then
            M.rename_buffer(bufnr, dest_buf_name .. bufname:sub(src_buf_name:len() + 1))
            break
          end
        end
      end
    end
  end
end

---@param name_or_config string|table
---@return string
---@return table|nil
M.split_config = function(name_or_config)
  if type(name_or_config) == "string" then
    return name_or_config, nil
  else
    if not name_or_config[1] and name_or_config["1"] then
      -- This was likely loaded from json, so the first element got coerced to a string key
      name_or_config[1] = name_or_config["1"]
      name_or_config["1"] = nil
    end
    return name_or_config[1], name_or_config
  end
end

---@param lines oil.TextChunk[][]
---@param col_width integer[]
---@return string[]
---@return any[][] List of highlights {group, lnum, col_start, col_end}
M.render_table = function(lines, col_width)
  local str_lines = {}
  local highlights = {}
  for _, cols in ipairs(lines) do
    local col = 0
    local pieces = {}
    for i, chunk in ipairs(cols) do
      local text, hl
      if type(chunk) == "table" then
        text = chunk[1]
        hl = chunk[2]
      else
        text = chunk
      end
      text = M.rpad(text, col_width[i])
      table.insert(pieces, text)
      local col_end = col + text:len() + 1
      if hl then
        if type(hl) == "table" then
          -- hl has the form { [1]: hl_name, [2]: col_start, [3]: col_end }[]
          -- Notice that col_start and col_end are relative position inside
          -- that col, so we need to add the offset to them
          for _, sub_hl in ipairs(hl) do
            table.insert(highlights, {
              sub_hl[1],
              #str_lines,
              col + sub_hl[2],
              col + sub_hl[3],
            })
          end
        else
          table.insert(highlights, { hl, #str_lines, col, col_end })
        end
      end
      col = col_end
    end
    table.insert(str_lines, table.concat(pieces, " "))
  end
  return str_lines, highlights
end

---@param bufnr integer
---@param highlights any[][] List of highlights {group, lnum, col_start, col_end}
M.set_highlights = function(bufnr, highlights)
  local ns = vim.api.nvim_create_namespace("Oil")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    local group, line, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_set_extmark(bufnr, ns, line, col_start, {
      end_col = col_end,
      hl_group = group,
      strict = false,
    })
  end
end

---@param path string
---@param os_slash? boolean use os filesystem slash instead of posix slash
---@return string
M.addslash = function(path, os_slash)
  local slash = "/"
  if os_slash and require("oil.fs").is_windows then
    slash = "\\"
  end

  local endslash = path:match(slash .. "$")
  if not endslash then
    return path .. slash
  else
    return path
  end
end

---@param winid nil|integer
---@return boolean
M.is_floating_win = function(winid)
  return vim.api.nvim_win_get_config(winid or 0).relative ~= ""
end

---Recalculate the window title for the current buffer
---@param winid nil|integer
---@return string
M.get_title = function(winid)
  if config.float.get_win_title ~= nil then
    return config.float.get_win_title(winid or 0)
  end

  local src_buf = vim.api.nvim_win_get_buf(winid or 0)
  local title = vim.api.nvim_buf_get_name(src_buf)
  local scheme, path = M.parse_url(title)

  if config.adapters[scheme] == "files" then
    assert(path)
    local fs = require("oil.fs")
    title = vim.fn.fnamemodify(fs.posix_to_os_path(path), ":~")
  end
  return title
end

local winid_map = {}
M.add_title_to_win = function(winid, opts)
  opts = opts or {}
  opts.align = opts.align or "left"
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  -- HACK to force the parent window to position itself
  -- See https://github.com/neovim/neovim/issues/13403
  vim.cmd.redraw()
  local title = M.get_title(winid)
  local width = math.min(vim.api.nvim_win_get_width(winid) - 4, 2 + vim.api.nvim_strwidth(title))
  local title_winid = winid_map[winid]
  local bufnr
  if title_winid and vim.api.nvim_win_is_valid(title_winid) then
    vim.api.nvim_win_set_width(title_winid, width)
    bufnr = vim.api.nvim_win_get_buf(title_winid)
  else
    bufnr = vim.api.nvim_create_buf(false, true)
    local col = 1
    if opts.align == "center" then
      col = math.floor((vim.api.nvim_win_get_width(winid) - width) / 2)
    elseif opts.align == "right" then
      col = vim.api.nvim_win_get_width(winid) - 1 - width
    elseif opts.align ~= "left" then
      vim.notify(
        string.format("Unknown oil window title alignment: '%s'", opts.align),
        vim.log.levels.ERROR
      )
    end
    title_winid = vim.api.nvim_open_win(bufnr, false, {
      relative = "win",
      win = winid,
      width = width,
      height = 1,
      row = -1,
      col = col,
      focusable = false,
      zindex = 151,
      style = "minimal",
      noautocmd = true,
    })
    winid_map[winid] = title_winid
    vim.api.nvim_set_option_value(
      "winblend",
      vim.wo[winid].winblend,
      { scope = "local", win = title_winid }
    )
    vim.bo[bufnr].bufhidden = "wipe"

    local update_autocmd = vim.api.nvim_create_autocmd("BufWinEnter", {
      desc = "Update oil floating window title when buffer changes",
      pattern = "*",
      callback = function(params)
        local winbuf = params.buf
        if vim.api.nvim_win_get_buf(winid) ~= winbuf then
          return
        end
        local new_title = M.get_title(winid)
        local new_width =
          math.min(vim.api.nvim_win_get_width(winid) - 4, 2 + vim.api.nvim_strwidth(new_title))
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { " " .. new_title .. " " })
        vim.bo[bufnr].modified = false
        vim.api.nvim_win_set_width(title_winid, new_width)
        local new_col = 1
        if opts.align == "center" then
          new_col = math.floor((vim.api.nvim_win_get_width(winid) - new_width) / 2)
        elseif opts.align == "right" then
          new_col = vim.api.nvim_win_get_width(winid) - 1 - new_width
        end
        vim.api.nvim_win_set_config(title_winid, {
          relative = "win",
          win = winid,
          row = -1,
          col = new_col,
          width = new_width,
          height = 1,
        })
      end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
      desc = "Close oil floating window title when floating window closes",
      pattern = tostring(winid),
      callback = function()
        if title_winid and vim.api.nvim_win_is_valid(title_winid) then
          vim.api.nvim_win_close(title_winid, true)
        end
        winid_map[winid] = nil
        vim.api.nvim_del_autocmd(update_autocmd)
      end,
      once = true,
      nested = true,
    })
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { " " .. title .. " " })
  vim.bo[bufnr].modified = false
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:FloatTitle,NormalFloat:FloatTitle",
    { scope = "local", win = title_winid }
  )
end

---@param action oil.Action
---@return oil.Adapter
---@return nil|oil.CrossAdapterAction
M.get_adapter_for_action = function(action)
  local adapter = assert(config.get_adapter_by_scheme(action.url or action.src_url))
  if action.dest_url then
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if adapter ~= dest_adapter then
      if
        adapter.supported_cross_adapter_actions
        and adapter.supported_cross_adapter_actions[dest_adapter.name]
      then
        return adapter, adapter.supported_cross_adapter_actions[dest_adapter.name]
      elseif
        dest_adapter.supported_cross_adapter_actions
        and dest_adapter.supported_cross_adapter_actions[adapter.name]
      then
        return dest_adapter, dest_adapter.supported_cross_adapter_actions[adapter.name]
      else
        error(
          string.format(
            "Cannot copy files from %s -> %s; no cross-adapter transfer method found",
            action.src_url,
            action.dest_url
          )
        )
      end
    end
  end
  return adapter
end

---@param str string
---@param align "left"|"right"|"center"
---@param width integer
---@return string
---@return integer
M.h_align = function(str, align, width)
  if align == "center" then
    local padding = math.floor((width - vim.api.nvim_strwidth(str)) / 2)
    return string.rep(" ", padding) .. str, padding
  elseif align == "right" then
    local padding = width - vim.api.nvim_strwidth(str)
    return string.rep(" ", padding) .. str, padding
  else
    return str, 0
  end
end

---@param bufnr integer
---@param text string|string[]
---@param opts nil|table
---    h_align nil|"left"|"right"|"center"
---    v_align nil|"top"|"bottom"|"center"
---    actions nil|string[]
---    winid nil|integer
M.render_text = function(bufnr, text, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    h_align = "center",
    v_align = "center",
  })
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if type(text) == "string" then
    text = { text }
  end
  local height = 40
  local width = 30

  -- If no winid passed in, find the first win that displays this buffer
  if not opts.winid then
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
        opts.winid = winid
        break
      end
    end
  end
  if opts.winid then
    height = vim.api.nvim_win_get_height(opts.winid)
    width = vim.api.nvim_win_get_width(opts.winid)
  end
  local lines = {}

  -- Add vertical spacing for vertical alignment
  if opts.v_align == "center" then
    for _ = 1, (height / 2) - (#text / 2) do
      table.insert(lines, "")
    end
  elseif opts.v_align == "bottom" then
    local num_lines = height
    if opts.actions then
      num_lines = num_lines - 2
    end
    while #lines + #text < num_lines do
      table.insert(lines, "")
    end
  end

  -- Add the lines of text
  for _, line in ipairs(text) do
    line = M.h_align(line, opts.h_align, width)
    table.insert(lines, line)
  end

  -- Render the actions (if any) at the bottom
  local highlights = {}
  if opts.actions then
    while #lines < height - 1 do
      table.insert(lines, "")
    end
    local last_line, padding = M.h_align(table.concat(opts.actions, "    "), "center", width)
    local col = padding
    for _, action in ipairs(opts.actions) do
      table.insert(highlights, { "Special", #lines, col, col + 3 })
      col = padding + action:len() + 4
    end
    table.insert(lines, last_line)
  end

  vim.bo[bufnr].modifiable = true
  pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  M.set_highlights(bufnr, highlights)
end

---Run a function in the context of a full-editor window
---@param bufnr nil|integer
---@param callback fun()
M.run_in_fullscreen_win = function(bufnr, callback)
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].bufhidden = "wipe"
  end
  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    noautocmd = true,
  })
  local winnr = vim.api.nvim_win_get_number(winid)
  vim.cmd.wincmd({ count = winnr, args = { "w" }, mods = { noautocmd = true } })
  callback()
  vim.cmd.close({ count = winnr, mods = { noautocmd = true, emsg_silent = true } })
end

---@param bufnr integer
---@return boolean
M.is_oil_bufnr = function(bufnr)
  local filetype = vim.bo[bufnr].filetype
  if filetype == "oil" then
    return true
  elseif filetype ~= "" then
    -- If the filetype is set and is NOT "oil", then it's not an oil buffer
    return false
  end
  local scheme = M.parse_url(vim.api.nvim_buf_get_name(bufnr))
  return config.adapters[scheme] or config.adapter_aliases[scheme]
end

---This is a hack so we don't end up in insert mode after starting a task
---@param prev_mode string The vim mode we were in before opening a terminal
M.hack_around_termopen_autocmd = function(prev_mode)
  -- It's common to have autocmds that enter insert mode when opening a terminal
  vim.defer_fn(function()
    local new_mode = vim.api.nvim_get_mode().mode
    if new_mode ~= prev_mode then
      if string.find(new_mode, "i") == 1 then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
        if string.find(prev_mode, "v") == 1 or string.find(prev_mode, "V") == 1 then
          vim.cmd.normal({ bang = true, args = { "gv" } })
        end
      end
    end
  end, 10)
end

---@param opts? {include_not_owned?: boolean}
---@return nil|integer
M.get_preview_win = function(opts)
  opts = opts or {}

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if
      vim.api.nvim_win_is_valid(winid)
      and vim.wo[winid].previewwindow
      and (opts.include_not_owned or vim.w[winid]["oil_preview"])
    then
      return winid
    end
  end
end

---@return fun() restore Function that restores the cursor
M.hide_cursor = function()
  vim.api.nvim_set_hl(0, "OilPreviewCursor", { nocombine = true, blend = 100 })
  local original_guicursor = vim.go.guicursor
  vim.go.guicursor = "a:OilPreviewCursor/OilPreviewCursor"

  return function()
    -- HACK: see https://github.com/neovim/neovim/issues/21018
    vim.go.guicursor = "a:"
    vim.cmd.redrawstatus()
    vim.go.guicursor = original_guicursor
  end
end

---@param bufnr integer
---@param preferred_win nil|integer
---@return nil|integer
M.buf_get_win = function(bufnr, preferred_win)
  if
    preferred_win
    and vim.api.nvim_win_is_valid(preferred_win)
    and vim.api.nvim_win_get_buf(preferred_win) == bufnr
  then
    return preferred_win
  end
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      return winid
    end
  end
  return nil
end

---@param adapter oil.Adapter
---@param url string
---@param opts {columns?: string[], no_cache?: boolean}
---@param callback fun(err: nil|string, entries: nil|oil.InternalEntry[])
M.adapter_list_all = function(adapter, url, opts, callback)
  local cache = require("oil.cache")
  if not opts.no_cache then
    local entries = cache.list_url(url)
    if not vim.tbl_isempty(entries) then
      return callback(nil, vim.tbl_values(entries))
    end
  end
  local ret = {}
  adapter.list(url, opts.columns or {}, function(err, entries, fetch_more)
    if err then
      callback(err)
      return
    end
    if entries then
      vim.list_extend(ret, entries)
    end
    if fetch_more then
      vim.defer_fn(fetch_more, 4)
    else
      callback(nil, ret)
    end
  end)
end

---Send files from the current oil directory to quickfix
---based on the provided options.
---@param opts {target?: "qflist"|"loclist", action?: "r"|"a", only_matching_search?: boolean}
M.send_to_quickfix = function(opts)
  if type(opts) ~= "table" then
    opts = {}
  end
  local oil = require("oil")
  local dir = oil.get_current_dir()
  if type(dir) ~= "string" then
    return
  end
  local range = M.get_visual_range()
  if not range then
    range = { start_lnum = 1, end_lnum = vim.fn.line("$") }
  end
  local match_all = not opts.only_matching_search
  local qf_entries = {}
  for i = range.start_lnum, range.end_lnum do
    local entry = oil.get_entry_on_line(0, i)
    if entry and entry.type == "file" and (match_all or M.is_matching(entry)) then
      local qf_entry = {
        filename = dir .. entry.name,
        lnum = 1,
        col = 1,
        text = entry.name,
      }
      table.insert(qf_entries, qf_entry)
    end
  end
  if #qf_entries == 0 then
    vim.notify("[oil] No entries found to send to quickfix", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
  local qf_title = "oil files"
  local action = opts.action == "a" and "a" or "r"
  if opts.target == "loclist" then
    vim.fn.setloclist(0, {}, action, { title = qf_title, items = qf_entries })
  else
    vim.fn.setqflist({}, action, { title = qf_title, items = qf_entries })
  end
  vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
  vim.cmd.copen()
end

---@return boolean
M.is_visual_mode = function()
  local mode = vim.api.nvim_get_mode().mode
  return mode:match("^[vV]") ~= nil
end

---Get the current visual selection range. If not in visual mode, return nil.
---@return {start_lnum: integer, end_lnum: integer}?
M.get_visual_range = function()
  if not M.is_visual_mode() then
    return
  end
  -- This is the best way to get the visual selection at the moment
  -- https://github.com/neovim/neovim/pull/13896
  local _, start_lnum, _, _ = unpack(vim.fn.getpos("v"))
  local _, end_lnum, _, _, _ = unpack(vim.fn.getcurpos())
  if start_lnum > end_lnum then
    start_lnum, end_lnum = end_lnum, start_lnum
  end
  return { start_lnum = start_lnum, end_lnum = end_lnum }
end

---@param entry oil.Entry
---@return boolean
M.is_matching = function(entry)
  -- if search highlightig is not enabled, all files are considered to match
  local search_highlighting_is_off = (vim.v.hlsearch == 0)
  if search_highlighting_is_off then
    return true
  end
  local pattern = vim.fn.getreg("/")
  local position_of_match = vim.fn.match(entry.name, pattern)
  return position_of_match ~= -1
end

---@param bufnr integer
---@param callback fun()
M.run_after_load = function(bufnr, callback)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if vim.b[bufnr].oil_ready then
    callback()
  else
    vim.api.nvim_create_autocmd("User", {
      pattern = "OilEnter",
      callback = function(args)
        if args.data.buf == bufnr then
          vim.api.nvim_buf_call(bufnr, callback)
          return true
        end
      end,
    })
  end
end

---@param entry oil.Entry
---@return boolean
M.is_directory = function(entry)
  local is_directory = entry.type == "directory"
    or (
      entry.type == "link"
      and entry.meta
      and entry.meta.link_stat
      and entry.meta.link_stat.type == "directory"
    )
  return is_directory == true
end

---Get the :edit path for an entry
---@param bufnr integer The oil buffer that contains the entry
---@param entry oil.Entry
---@param callback fun(normalized_url: string)
M.get_edit_path = function(bufnr, entry, callback)
  local pathutil = require("oil.pathutil")

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local scheme, dir = M.parse_url(bufname)
  local adapter = M.get_adapter(bufnr, true)
  assert(scheme and dir and adapter)

  local url = scheme .. dir .. entry.name
  if M.is_directory(entry) then
    url = url .. "/"
  end

  if entry.name == ".." then
    callback(scheme .. pathutil.parent(dir))
  elseif adapter.get_entry_path then
    adapter.get_entry_path(url, entry, callback)
  else
    adapter.normalize_url(url, callback)
  end
end

--- Check for an icon provider and return a common icon provider API
---@return (oil.IconProvider)?
M.get_icon_provider = function()
  -- prefer mini.icons
  local _, mini_icons = pcall(require, "mini.icons")
  ---@diagnostic disable-next-line: undefined-field
  if _G.MiniIcons then -- `_G.MiniIcons` is a better check to see if the module is setup
    return function(type, name)
      return mini_icons.get(type == "directory" and "directory" or "file", name)
    end
  end

  -- fallback to `nvim-web-devicons`
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")
  if has_devicons then
    return function(type, name, conf)
      if type == "directory" then
        return conf and conf.directory or "", "OilDirIcon"
      else
        local icon, hl = devicons.get_icon(name)
        icon = icon or (conf and conf.default_file or "")
        return icon, hl
      end
    end
  end
end

---Read a buffer into a scratch buffer and apply syntactic highlighting when possible
---@param path string The path to the file to read
---@param preview_method oil.PreviewMethod
---@return nil|integer
M.read_file_to_scratch_buffer = function(path, preview_method)
  local bufnr = vim.api.nvim_create_buf(false, true)
  if bufnr == 0 then
    return
  end

  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "nofile"

  local max_lines = preview_method == "fast_scratch" and vim.o.lines or nil
  local has_lines, read_res = pcall(vim.fn.readfile, path, "", max_lines)
  local lines = has_lines and vim.split(table.concat(read_res, "\n"), "\n") or {}

  local ok = pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
  if not ok then
    return
  end
  local ft = vim.filetype.match({ filename = path, buf = bufnr })
  if ft and ft ~= "" and vim.treesitter.language.get_lang then
    local lang = vim.treesitter.language.get_lang(ft)
    if not pcall(vim.treesitter.start, bufnr, lang) then
      vim.bo[bufnr].syntax = ft
    else
    end
  end

  -- Replace the scratch buffer with a real buffer if we enter it
  vim.api.nvim_create_autocmd("BufEnter", {
    desc = "oil.nvim replace scratch buffer with real buffer",
    buffer = bufnr,
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      -- Have to schedule this so all the FileType, etc autocmds will fire
      vim.schedule(function()
        if vim.api.nvim_get_current_win() == winid then
          vim.cmd.edit({ args = { path } })

          -- If we're still in a preview window, make sure this buffer still gets treated as a
          -- preview
          if vim.wo.previewwindow then
            vim.bo.bufhidden = "wipe"
            vim.b.oil_preview_buffer = true
          end
        end
      end)
    end,
  })

  return bufnr
end

local _regcache = {}
---Check if a file matches a BufReadCmd autocmd
---@param filename string
---@return boolean
M.file_matches_bufreadcmd = function(filename)
  local autocmds = vim.api.nvim_get_autocmds({
    event = "BufReadCmd",
  })
  for _, au in ipairs(autocmds) do
    local pat = _regcache[au.pattern]
    if not pat then
      pat = vim.fn.glob2regpat(au.pattern)
      _regcache[au.pattern] = pat
    end

    if vim.fn.match(filename, pat) >= 0 then
      return true
    end
  end
  return false
end

return M
