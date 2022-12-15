local columns = require("oil.columns")
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
  local width = 120
  local height = 10
  self.winid = vim.api.nvim_open_win(self.bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - vim.o.cmdheight - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })
end

function Progress:_render()
  util.render_centered_text(self.bufnr, self.lines)
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
  self:_render()
end

function Progress:close()
  if self.timer then
    self.timer:close()
    self.timer = nil
  end
  if self.winid then
    vim.api.nvim_win_close(self.winid, true)
    self.winid = nil
  end
end

return Progress
