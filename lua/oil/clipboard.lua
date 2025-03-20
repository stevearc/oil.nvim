local cache = require("oil.cache")
local columns = require("oil.columns")
local config = require("oil.config")
local fs = require("oil.fs")
local oil = require("oil")
local util = require("oil.util")
local view = require("oil.view")

local M = {}

---@return "wayland"|"x11"|nil
local function get_linux_session_type()
  local xdg_session_type = vim.env.XDG_SESSION_TYPE
  if not xdg_session_type then
    return
  end
  xdg_session_type = xdg_session_type:lower()
  if xdg_session_type:find("x11") then
    return "x11"
  elseif xdg_session_type:find("wayland") then
    return "wayland"
  else
    return nil
  end
end

---@return boolean
local function is_linux_desktop_gnome()
  local cur_desktop = vim.env.XDG_CURRENT_DESKTOP
  local session_desktop = vim.env.XDG_SESSION_DESKTOP
  local idx = session_desktop and session_desktop:lower():find("gnome")
    or cur_desktop and cur_desktop:lower():find("gnome")
  return idx ~= nil or cur_desktop == "X-Cinnamon" or cur_desktop == "XFCE"
end

---@param winid integer
---@param entry oil.InternalEntry
---@param column_defs oil.ColumnSpec[]
---@param adapter oil.Adapter
---@param bufnr integer
local function write_pasted(winid, entry, column_defs, adapter, bufnr)
  local col_width = {}
  for i in ipairs(column_defs) do
    col_width[i + 1] = 1
  end
  local line_table =
    { view.format_entry_cols(entry, column_defs, col_width, adapter, false, bufnr) }
  local lines, _ = util.render_table(line_table, col_width)
  local pos = vim.api.nvim_win_get_cursor(winid)
  vim.api.nvim_buf_set_lines(bufnr, pos[1], pos[1], true, lines)
end

---@param paths string[]
local function paste_paths(paths)
  local bufnr = vim.api.nvim_get_current_buf()
  local scheme = "oil://"
  local adapter = assert(config.get_adapter_by_scheme(scheme))
  local column_defs = columns.get_supported_columns(scheme)
  local winid = vim.api.nvim_get_current_win()

  local parent_urls = {}
  local pending_paths = {}

  for _, path in ipairs(paths) do
    -- Trim the trailing slash off directories
    if vim.endswith(path, "/") then
      path = path:sub(1, -2)
    end

    local ori_entry = cache.get_entry_by_url(scheme .. path)
    if ori_entry then
      write_pasted(winid, ori_entry, column_defs, adapter, bufnr)
    else
      local parent_url = scheme .. vim.fs.dirname(path)
      parent_urls[parent_url] = true
      table.insert(pending_paths, path)
    end
  end
  if #pending_paths == 0 then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(winid)
  local complete_loading = util.cb_collect(#vim.tbl_keys(parent_urls), function(err)
    if err then
      vim.notify(string.format("Error loading parent directory: %s", err), vim.log.levels.ERROR)
    else
      -- Something in this process moves the cursor to the top of the window, so have to restore it
      vim.api.nvim_win_set_cursor(winid, cursor)

      for _, path in ipairs(pending_paths) do
        local ori_entry = cache.get_entry_by_url(scheme .. path)
        if ori_entry then
          write_pasted(winid, ori_entry, column_defs, adapter, bufnr)
        else
          vim.notify(
            string.format("The pasted file '%s' could not be found", path),
            vim.log.levels.ERROR
          )
        end
      end
    end
  end)

  for parent_url, _ in pairs(parent_urls) do
    local new_bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(new_bufnr, parent_url)
    oil.load_oil_buffer(new_bufnr)
    util.run_after_load(new_bufnr, complete_loading)
  end
end

---@return integer start
---@return integer end
local function range_from_selection()
  -- [bufnum, lnum, col, off]; both row and column 1-indexed
  local start = vim.fn.getpos("v")
  local end_ = vim.fn.getpos(".")
  local start_row = start[2]
  local end_row = end_[2]

  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end

  return start_row, end_row
end

M.copy_to_system_clipboard = function()
  local dir = oil.get_current_dir()
  if not dir then
    vim.notify("System clipboard only works for local files", vim.log.levels.ERROR)
    return
  end

  local entries = {}
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" then
    if fs.is_mac then
      vim.notify(
        "Copying multiple paths to clipboard is not supported on mac",
        vim.log.levels.ERROR
      )
      return
    end
    local start_row, end_row = range_from_selection()
    for i = start_row, end_row do
      table.insert(entries, oil.get_entry_on_line(0, i))
    end

    -- leave visual mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
  else
    table.insert(entries, oil.get_cursor_entry())
  end

  -- This removes holes in the list-like table
  entries = vim.tbl_values(entries)

  if #entries == 0 then
    vim.notify("Could not find local file under cursor", vim.log.levels.WARN)
    return
  end
  local paths = {}
  for _, entry in ipairs(entries) do
    table.insert(paths, dir .. entry.name)
  end
  local cmd = {}
  local stdin
  if fs.is_mac then
    cmd = {
      "osascript",
      "-e",
      "on run args",
      "-e",
      "set the clipboard to POSIX file (first item of args)",
      "-e",
      "end run",
      paths[1],
    }
  elseif fs.is_linux then
    local xdg_session_type = get_linux_session_type()
    if xdg_session_type == "x11" then
      vim.list_extend(cmd, { "xclip", "-i", "-selection", "clipboard" })
    elseif xdg_session_type == "wayland" then
      table.insert(cmd, "wl-copy")
    else
      vim.notify("System clipboard not supported, check $XDG_SESSION_TYPE", vim.log.levels.ERROR)
      return
    end
    local urls = {}
    for _, path in ipairs(paths) do
      table.insert(urls, "file://" .. path)
    end
    if is_linux_desktop_gnome() then
      stdin = string.format("copy\n%s\0", table.concat(urls, "\n"))
      vim.list_extend(cmd, { "-t", "x-special/gnome-copied-files" })
    else
      stdin = table.concat(urls, "\n") .. "\n"
      vim.list_extend(cmd, { "-t", "text/uri-list" })
    end
  else
    vim.notify("System clipboard not supported on Windows", vim.log.levels.ERROR)
    return
  end

  if vim.fn.executable(cmd[1]) == 0 then
    vim.notify(string.format("Could not find executable '%s'", cmd[1]), vim.log.levels.ERROR)
    return
  end
  local stderr = ""
  local jid = vim.fn.jobstart(cmd, {
    stderr_buffered = true,
    on_stderr = function(_, data)
      stderr = table.concat(data, "\n")
    end,
    on_exit = function(j, exit_code)
      if exit_code ~= 0 then
        vim.notify(
          string.format("Error copying '%s' to system clipboard\n%s", vim.inspect(paths), stderr),
          vim.log.levels.ERROR
        )
      else
        if #paths == 1 then
          vim.notify(string.format("Copied '%s' to system clipboard", paths[1]))
        else
          vim.notify(string.format("Copied %d files to system clipboard", #paths))
        end
      end
    end,
  })
  assert(jid > 0, "Failed to start job")
  if stdin then
    vim.api.nvim_chan_send(jid, stdin)
    vim.fn.chanclose(jid, "stdin")
  end
end

---@param lines string[]
---@return string[]
local function handle_paste_output_mac(lines)
  local ret = {}
  for _, line in ipairs(lines) do
    if not line:match("^%s*$") then
      table.insert(ret, line)
    end
  end
  return ret
end

---@param lines string[]
---@return string[]
local function handle_paste_output_linux(lines)
  local ret = {}
  for _, line in ipairs(lines) do
    local path = line:match("^file://(.+)$")
    if path then
      table.insert(ret, util.url_unescape(path))
    end
  end
  return ret
end

M.paste_from_system_clipboard = function()
  local dir = oil.get_current_dir()
  if not dir then
    return
  end
  local cmd = {}
  local handle_paste_output
  if fs.is_mac then
    cmd = {
      "osascript",
      "-e",
      "on run",
      "-e",
      "POSIX path of (the clipboard as «class furl»)",
      "-e",
      "end run",
    }
    handle_paste_output = handle_paste_output_mac
  elseif fs.is_linux then
    local xdg_session_type = get_linux_session_type()
    if xdg_session_type == "x11" then
      vim.list_extend(cmd, { "xclip", "-o", "-selection", "clipboard" })
    elseif xdg_session_type == "wayland" then
      table.insert(cmd, "wl-paste")
    else
      vim.notify("System clipboard not supported, check $XDG_SESSION_TYPE", vim.log.levels.ERROR)
      return
    end
    if is_linux_desktop_gnome() then
      vim.list_extend(cmd, { "-t", "x-special/gnome-copied-files" })
    else
      vim.list_extend(cmd, { "-t", "text/uri-list" })
    end
    handle_paste_output = handle_paste_output_linux
  else
    vim.notify("System clipboard not supported on Windows", vim.log.levels.ERROR)
    return
  end
  local paths
  local stderr = ""
  if vim.fn.executable(cmd[1]) == 0 then
    vim.notify(string.format("Could not find executable '%s'", cmd[1]), vim.log.levels.ERROR)
    return
  end
  local jid = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(j, data)
      local lines = vim.split(table.concat(data, "\n"), "\r?\n")
      paths = handle_paste_output(lines)
    end,
    on_stderr = function(_, data)
      stderr = table.concat(data, "\n")
    end,
    on_exit = function(j, exit_code)
      if exit_code ~= 0 or not paths then
        vim.notify(
          string.format("Error pasting from system clipboard: %s", stderr),
          vim.log.levels.ERROR
        )
      elseif #paths == 0 then
        vim.notify("No valid files found in system clipboard", vim.log.levels.WARN)
      else
        paste_paths(paths)
      end
    end,
  })
  assert(jid > 0, "Failed to start job")
end

return M
