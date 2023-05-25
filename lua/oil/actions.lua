local oil = require("oil")
local util = require("oil.util")

local M = {}

M.show_help = {
  desc = "Show default keymaps",
  callback = function()
    local config = require("oil.config")
    require("oil.keymap_util").show_help(config.keymaps)
  end,
}

M.select = {
  desc = "Open the entry under the cursor",
  callback = oil.select,
}

M.select_vsplit = {
  desc = "Open the entry under the cursor in a vertical split",
  callback = function()
    oil.select({ vertical = true })
  end,
}

M.select_split = {
  desc = "Open the entry under the cursor in a horizontal split",
  callback = function()
    oil.select({ horizontal = true })
  end,
}

M.select_tab = {
  desc = "Open the entry under the cursor in a new tab",
  callback = function()
    oil.select({ tab = true })
  end,
}

M.preview = {
  desc = "Open the entry under the cursor in a preview window, or close the preview window if already open",
  callback = function()
    local entry = oil.get_cursor_entry()
    if not entry then
      vim.notify("Could not find entry under cursor", vim.log.levels.ERROR)
      return
    end
    local winid = util.get_preview_win()
    if winid then
      local cur_id = vim.w[winid].oil_entry_id
      if entry.id == cur_id then
        vim.api.nvim_win_close(winid, true)
        return
      end
    end
    oil.select({ preview = true })
  end,
}

M.preview_scroll_down = {
  desc = "Scroll down in the preview window",
  callback = function()
    local winid = util.get_preview_win()
    if winid then
      vim.api.nvim_win_call(winid, function()
        vim.cmd.normal({
          args = { vim.api.nvim_replace_termcodes("<C-d>", true, true, true) },
          bang = true,
        })
      end)
    end
  end,
}

M.preview_scroll_up = {
  desc = "Scroll up in the preview window",
  callback = function()
    local winid = util.get_preview_win()
    if winid then
      vim.api.nvim_win_call(winid, function()
        vim.cmd.normal({
          args = { vim.api.nvim_replace_termcodes("<C-u>", true, true, true) },
          bang = true,
        })
      end)
    end
  end,
}

M.parent = {
  desc = "Navigate to the parent path",
  callback = oil.open,
}

M.close = {
  desc = "Close oil and restore original buffer",
  callback = oil.close,
}

---@param cmd string
local function cd(cmd)
  local dir = oil.get_current_dir()
  if dir then
    vim.cmd({ cmd = cmd, args = { dir } })
  else
    vim.notify("Cannot :cd; not in a directory", vim.log.levels.WARN)
  end
end

M.cd = {
  desc = ":cd to the current oil directory",
  callback = function()
    cd("cd")
  end,
}

M.tcd = {
  desc = ":tcd to the current oil directory",
  callback = function()
    cd("tcd")
  end,
}

M.open_cwd = {
  desc = "Open oil in Neovim's current working directory",
  callback = function()
    oil.open(vim.fn.getcwd())
  end,
}

M.toggle_hidden = {
  desc = "Toggle hidden files and directories",
  callback = function()
    require("oil.view").toggle_hidden()
  end,
}

M.open_terminal = {
  desc = "Open a terminal in the current directory",
  callback = function()
    local dir = oil.get_current_dir()
    if dir then
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
      vim.fn.termopen(vim.o.shell, { cwd = dir })
    end
  end,
}

M.refresh = {
  desc = "Refresh current directory list",
  callback = function()
    if vim.bo.modified then
      local ok, choice = pcall(vim.fn.confirm, "Discard changes?", "No\nYes")
      if not ok or choice ~= 2 then
        return
      end
    end
    vim.cmd.edit({ bang = true })
  end,
}

local function open_cmdline_with_args(args)
  local escaped = vim.api.nvim_replace_termcodes(
    ": " .. args .. string.rep("<Left>", args:len() + 1),
    true,
    false,
    true
  )
  vim.api.nvim_feedkeys(escaped, "n", true)
end

M.open_cmdline = {
  desc = "Open vim cmdline with current entry as an argument",
  callback = function()
    local config = require("oil.config")
    local fs = require("oil.fs")
    local entry = oil.get_cursor_entry()
    if not entry then
      return
    end
    local bufname = vim.api.nvim_buf_get_name(0)
    local scheme, path = util.parse_url(bufname)
    if not scheme then
      return
    end
    local adapter = config.get_adapter_by_scheme(scheme)
    if not adapter or not path or adapter.name ~= "files" then
      return
    end
    local fullpath = fs.shorten_path(fs.posix_to_os_path(path) .. entry.name)
    open_cmdline_with_args(fullpath)
  end,
}

M.copy_entry_path = {
  desc = "Copy the filepath of the entry under the cursor to the + register",
  callback = function()
    local entry = oil.get_cursor_entry()
    local dir = oil.get_current_dir()
    if not entry or not dir then
      return
    end
    vim.fn.setreg(vim.v.register, dir .. entry.name)
  end,
}

M.open_cmdline_dir = {
  desc = "Open vim cmdline with current directory as an argument",
  callback = function()
    local fs = require("oil.fs")
    local dir = oil.get_current_dir()
    if dir then
      open_cmdline_with_args(fs.shorten_path(dir))
    end
  end,
}

---List actions for documentation generation
---@private
M._get_actions = function()
  local ret = {}
  for name, action in pairs(M) do
    if type(action) == "table" and action.desc then
      table.insert(ret, {
        name = name,
        desc = action.desc,
      })
    end
  end
  return ret
end

return M
