local config = require("oil.config")
local columns = require("oil.columns")
local layout = require("oil.layout")
local loading = require("oil.loading")
local util = require("oil.util")
local Progress = {}

local FPS = 20

function Progress.new()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  return setmetatable({
    lines = { "", "", "" },
    bufnr = bufnr,
    autocmds = {},
  }, {
    __index = Progress,
  })
end

function Progress:show()
  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    return
  end
  local loading_iter = loading.get_bar_iter()
  self.timer = vim.loop.new_timer()
  self.timer:start(
    0,
    math.floor(1000 / FPS),
    vim.schedule_wrap(function()
      self.lines[2] = loading_iter()
      self:_render()
    end)
  )
  local width, height = layout.calculate_dims(120, 10, config.progress)
  self.winid = vim.api.nvim_open_win(self.bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((layout.get_editor_height() - height) / 2),
    col = math.floor((layout.get_editor_width() - width) / 2),
    zindex = 152, -- render on top of the floating window title
    style = "minimal",
    border = config.progress.border,
  })
  vim.bo[self.bufnr].filetype = "oil_progress"
  for k, v in pairs(config.preview.win_options) do
    vim.api.nvim_win_set_option(self.winid, k, v)
  end
  table.insert(
    self.autocmds,
    vim.api.nvim_create_autocmd("VimResized", {
      callback = function()
        self:_reposition()
      end,
    })
  )
end

function Progress:_render()
  util.render_centered_text(self.bufnr, self.lines)
end

function Progress:_reposition()
  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    local min_width = 120
    local line_width = vim.api.nvim_strwidth(self.lines[1])
    if line_width > min_width then
      min_width = line_width
    end
    local width, height = layout.calculate_dims(min_width, 10, config.progress)
    vim.api.nvim_win_set_config(self.winid, {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((layout.get_editor_height() - height) / 2),
      col = math.floor((layout.get_editor_width() - width) / 2),
      zindex = 152, -- render on top of the floating window title
    })
  end
end

---@param action oil.Action
---@param idx integer
---@param total integer
function Progress:set_action(action, idx, total)
  local adapter = util.get_adapter_for_action(action)
  local change_line
  if action.type == "change" then
    change_line = columns.render_change_action(adapter, action)
  else
    change_line = adapter.render_action(action)
  end
  self.lines[1] = change_line
  self.lines[3] = string.format("[%d/%d]", idx, total)
  self:_reposition()
  self:_render()
end

function Progress:close()
  if self.timer then
    self.timer:close()
    self.timer = nil
  end
  if self.winid then
    if vim.api.nvim_win_is_valid(self.winid) then
      vim.api.nvim_win_close(self.winid, true)
    end
    self.winid = nil
  end
  for _, id in ipairs(self.autocmds) do
    vim.api.nvim_del_autocmd(id)
  end
  self.autocmds = {}
end

return Progress
