local layout = require("oil.layout")
local ReplLayout = {}

---@param opts table
---    min_height integer
---    min_width integer
---    lines string[]
---    on_submit fun(text: string): boolean
---    on_cancel nil|fun()
ReplLayout.new = function(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    min_height = 10,
    min_width = 120,
  })
  vim.validate({
    lines = { opts.lines, "t" },
    min_height = { opts.min_height, "n" },
    min_width = { opts.min_width, "n" },
    on_submit = { opts.on_submit, "f" },
    on_cancel = { opts.on_cancel, "f", true },
  })
  local total_height = layout.get_editor_height()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  local width = math.min(opts.min_width, vim.o.columns - 2)
  local height = math.min(opts.min_height, total_height - 3)
  local row = math.floor((total_height - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local view_winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = false,
  })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, opts.lines)
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].modifiable = false
  vim.api.nvim_win_set_cursor(view_winid, { #opts.lines, 0 })

  local input_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[input_bufnr].bufhidden = "wipe"
  local input_winid = vim.api.nvim_open_win(input_bufnr, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row + height + 2,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    desc = "Close oil repl window when text input closes",
    pattern = tostring(input_winid),
    callback = function()
      if view_winid and vim.api.nvim_win_is_valid(view_winid) then
        vim.api.nvim_win_close(view_winid, true)
      end
    end,
    once = true,
    nested = true,
  })

  local self = setmetatable({
    input_bufnr = input_bufnr,
    view_bufnr = bufnr,
    input_winid = input_winid,
    view_winid = view_winid,
    _cancel = nil,
    _submit = nil,
  }, {
    __index = ReplLayout,
  })
  self._cancel = function()
    self:close()
    if opts.on_cancel then
      opts.on_cancel()
    end
  end
  self._submit = function()
    local line = vim.trim(vim.api.nvim_buf_get_lines(input_bufnr, 0, 1, true)[1])
    if line == "" then
      return
    end
    if not opts.on_submit(line) then
      vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, true, {})
      vim.bo[input_bufnr].modified = false
    end
  end
  local cancel = function()
    self._cancel()
  end
  vim.api.nvim_create_autocmd("BufLeave", {
    callback = cancel,
    once = true,
    nested = true,
    buffer = input_bufnr,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    callback = cancel,
    once = true,
    nested = true,
  })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = input_bufnr })
  vim.keymap.set({ "n", "i" }, "<C-c>", cancel, { buffer = input_bufnr })
  vim.keymap.set({ "n", "i" }, "<CR>", function()
    self._submit()
  end, { buffer = input_bufnr })
  vim.cmd.startinsert()
  return self
end

function ReplLayout:append_view_lines(lines)
  local bufnr = self.view_bufnr
  local num_lines = vim.api.nvim_buf_line_count(bufnr)
  local last_line = vim.api.nvim_buf_get_lines(bufnr, num_lines - 1, num_lines, true)[1]
  lines[1] = last_line .. lines[1]
  for i, v in ipairs(lines) do
    lines[i] = v:gsub("\r$", "")
  end
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, num_lines - 1, -1, true, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  vim.api.nvim_win_set_cursor(self.view_winid, { num_lines + #lines - 1, 0 })
end

function ReplLayout:close()
  self._submit = function() end
  self._cancel = function() end
  vim.cmd.stopinsert()
  vim.api.nvim_win_close(self.input_winid, true)
end

return ReplLayout
