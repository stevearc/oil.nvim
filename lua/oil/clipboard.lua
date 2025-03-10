local uv = vim.uv or vim.loop
local cache = require("oil.cache")
local columns = require("oil.columns")
local config = require("oil.config")
local constants = require("oil.constants")
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
  vim.api.nvim_buf_set_lines(0, pos[1], pos[1], true, lines)
end

---@param path string
local function paste_path(path)
  local bufnr = vim.api.nvim_get_current_buf()
  local scheme = "oil://"
  local parent_url = scheme .. vim.fs.dirname(path)
  local adapter = assert(config.get_adapter_by_scheme(parent_url))
  local column_defs = columns.get_supported_columns(scheme)

  local ori_entry = cache.get_entry_by_url(scheme .. path)
  if ori_entry then
    write_pasted(ori_entry, column_defs, adapter, bufnr)
    return
  end

  cache.begin_update_url(parent_url)
  adapter.list(
    parent_url,
    column_defs,
    vim.schedule_wrap(function(err, entries, fetch_more)
      if err then
        cache.end_update_url(parent_url)
        util.render_text(bufnr, { "Error: " .. err })
        return
      end
      if entries then
        for _, entry in ipairs(entries) do
          cache.store_entry(parent_url, entry)
          if entry[constants.FIELD_NAME] == vim.fs.basename(path) then
            cache.end_update_url(parent_url)
            write_pasted(entry, column_defs, adapter, bufnr)
            return
          end
        end
      end
      if fetch_more then
        vim.defer_fn(fetch_more, 4)
      else
        cache.end_update_url(parent_url)
        vim.notify(
          string.format("The requested file is not found under '%s'", parent_url),
          vim.log.levels.ERROR
        )
      end
    end)
  )
end

M.copy_to_system_clipboard = function()
  local dir = oil.get_current_dir()
  local entry = oil.get_cursor_entry()
  if not dir or not entry then
    return
  end
  local path = dir .. entry.name
  local cmd
  if fs.is_mac then
    cmd =
      "osascript -e 'on run args' -e 'set the clipboard to POSIX file (first item of args)' -e 'end run' '%s'"
  elseif fs.is_linux then
    local content, program, mime_type
    local xdg_session_type = get_linux_session_type()
    if xdg_session_type == "x11" then
      program = "xclip -i -selection clipboard"
    elseif xdg_session_type == "wayland" then
      program = "wl-copy"
    else
      vim.notify("System clipboard not supported, check $XDG_SESSION_TYPE", vim.log.levels.ERROR)
      return
    end
    if is_linux_desktop_gnome() then
      content = "copy\\nfile://%s\\0"
      mime_type = "x-special/gnome-copied-files"
    else
      content = "%s\\n"
      mime_type = "text/uri-list"
    end
    cmd = string.format("echo -en '%s' | %s -t %s", content, program, mime_type)
  else
    vim.notify("System clipboard not supported on Windows", vim.log.levels.ERROR)
    return
  end

  local stderr = ""
  local jid = vim.fn.jobstart(string.format(cmd, path), {
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
end

M.paste_from_system_clipboard = function()
  local dir = oil.get_current_dir()
  if not dir then
    return
  end
  local cmd
  if fs.is_mac then
    cmd = "osascript -e 'on run' -e 'POSIX path of (the clipboard as «class furl»)' -e 'end run'"
  elseif fs.is_linux then
    local program, mime_type
    local xdg_session_type = get_linux_session_type()
    if xdg_session_type == "x11" then
      program = "xclip -o -selection clipboard"
    elseif xdg_session_type == "wayland" then
      program = "wl-paste"
    else
      vim.notify("System clipboard not supported, check $XDG_SESSION_TYPE", vim.log.levels.ERROR)
      return
    end
    if is_linux_desktop_gnome() then
      mime_type = "x-special/gnome-copied-files | grep --text --color=never file://"
    else
      mime_type = "text/uri-list"
    end
    cmd = string.format("%s -t %s", program, mime_type)
  else
    vim.notify("System clipboard not supported on Windows", vim.log.levels.ERROR)
    return
  end
  local path
  local stderr = ""
  local jid = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(j, output)
      if #output > 1 then
        local sub_scheme = output[1]:gsub("^files?://", "")
        path = uv.fs_realpath(fs.posix_to_os_path(sub_scheme))
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
