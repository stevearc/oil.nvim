local oil = require("oil")

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

M.preview = {
  desc = "Open the entry under the cursor in a preview window",
  callback = function()
    oil.select({ preview = true })
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
  desc = "Open oil in Neovim's cwd",
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
      vim.fn.termopen(vim.o.shell, { cwd = dir })
    end
  end,
}

M.refresh = {
  desc = "Refresh directory",
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

M.open_cmdline = {
  desc = "Open vim cmdline with current entry as an argument",
  callback = function()
    local config = require("oil.config")
    local fs = require("oil.fs")
    local util = require("oil.util")
    local entry = oil.get_cursor_entry()
    if not entry then
      return
    end
    local bufname = vim.api.nvim_buf_get_name(0)
    local scheme, path = util.parse_url(bufname)
    local adapter = config.get_adapter_by_scheme(scheme)
    if not adapter or not path or adapter.name ~= "files" then
      return
    end
    local fullpath = fs.shorten_path(fs.posix_to_os_path(path) .. entry.name)
    local escaped = vim.api.nvim_replace_termcodes(
      ": " .. fullpath .. string.rep("<Left>", fullpath:len() + 1),
      true,
      false,
      true
    )
    vim.api.nvim_feedkeys(escaped, "n", true)
  end,
}

return M
