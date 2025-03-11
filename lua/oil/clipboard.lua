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
  local xdg_session_type = vim.env.XDG_SESSION_TYPE:lower()
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
  local idx = vim.env.XDG_SESSION_DESKTOP:lower():find("gnome") or cur_desktop:lower():find("gnome")
  return idx ~= nil or cur_desktop == "X-Cinnamon" or cur_desktop == "XFCE"
end

---@param entry oil.InternalEntry
---@param column_defs oil.ColumnSpec[]
---@param adapter oil.Adapter
---@param bufnr integer
local function write_pasted(entry, column_defs, adapter, bufnr)
  local col_width = {}
  for i in ipairs(column_defs) do
    col_width[i + 1] = 1
  end
  local line_table =
    { view.format_entry_cols(entry, column_defs, col_width, adapter, false, bufnr) }
  local lines, _ = util.render_table(line_table, col_width)
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_lines(bufnr, pos[1], pos[1], true, lines)
end

---@param path string
local function paste_path(path)
  local bufnr = vim.api.nvim_get_current_buf()
  local scheme = "oil://"
  local adapter = assert(config.get_adapter_by_scheme(scheme))
  local column_defs = columns.get_supported_columns(scheme)

  local ori_entry = cache.get_entry_by_url(scheme .. path)
  if ori_entry then
    write_pasted(ori_entry, column_defs, adapter, bufnr)
    return
  end

  local new_bufnr = vim.api.nvim_create_buf(false, false)
  local parent_url = scheme .. vim.fs.dirname(path)
  vim.api.nvim_buf_set_name(new_bufnr, parent_url)
  oil.load_oil_buffer(new_bufnr)
  util.run_after_load(new_bufnr, function()
    ori_entry = cache.get_entry_by_url(scheme .. path)
    if ori_entry then
      write_pasted(ori_entry, column_defs, adapter, bufnr)
    else
      vim.notify(
        string.format("The pasted file '%s' could not be found", path),
        vim.log.levels.ERROR
      )
    end
  end)
end

M.copy_to_system_clipboard = function()
  local dir = oil.get_current_dir()
  local entry = oil.get_cursor_entry()
  if not dir or not entry then
    return
  end
  local path = dir .. entry.name
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
      path,
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
    if is_linux_desktop_gnome() then
      stdin = string.format("copy\nfile://%s\0", path)
      vim.list_extend(cmd, { "-t", "x-special/gnome-copied-files" })
    else
      stdin = string.format("file://%s\n", path)
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
        vim.schedule_wrap(vim.notify)(
          string.format("Error copying '%s' to system clipboard\n%s", path, stderr),
          vim.log.levels.ERROR
        )
      else
        vim.schedule_wrap(vim.notify)(string.format("Copied '%s' to system clipboard", path))
      end
    end,
  })
  assert(jid > 0, "Failed to start job")
  if stdin then
    vim.api.nvim_chan_send(jid, stdin)
    vim.fn.chanclose(jid, "stdin")
  end
end

M.paste_from_system_clipboard = function()
  local dir = oil.get_current_dir()
  if not dir then
    return
  end
  local cmd = {}
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
  else
    vim.notify("System clipboard not supported on Windows", vim.log.levels.ERROR)
    return
  end
  local path
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
      for _, line in ipairs(lines) do
        local uri_path = line:match("^files?://(.+)$")
        if uri_path then
          path = util.url_unescape(uri_path)
          break
        end
      end
    end,
    on_stderr = function(_, data)
      stderr = table.concat(data, "\n")
    end,
    on_exit = function(j, exit_code)
      if exit_code ~= 0 or path == nil then
        vim.schedule_wrap(vim.notify)(
          string.format("Error pasting '%s' from system clipboard\n%s", path, stderr),
          vim.log.levels.ERROR
        )
      else
        paste_path(path)
      end
    end,
  })
  assert(jid > 0, "Failed to start job")
end

return M
