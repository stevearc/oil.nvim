local columns = require("oil.columns")
local config = require("oil.config")
local layout = require("oil.layout")
local util = require("oil.util")
local M = {}

---@param actions oil.Action[]
---@return boolean
local function is_simple_edit(actions)
  local num_create = 0
  local num_copy = 0
  local num_move = 0
  for _, action in ipairs(actions) do
    -- If there are any deletes, it is not a simple edit
    if action.type == "delete" then
      return false
    elseif action.type == "create" then
      num_create = num_create + 1
    elseif action.type == "copy" then
      num_copy = num_copy + 1
      -- Cross-adapter copies are not simple
      if util.parse_url(action.src_url) ~= util.parse_url(action.dest_url) then
        return false
      end
    elseif action.type == "move" then
      num_move = num_move + 1
      -- Cross-adapter moves are not simple
      if util.parse_url(action.src_url) ~= util.parse_url(action.dest_url) then
        return false
      end
    end
  end
  -- More than one move/copy is complex
  if num_move > 1 or num_copy > 1 then
    return false
  end
  -- More than 5 creates is complex
  if num_create > 5 then
    return false
  end
  return true
end

---@param actions oil.Action[]
---@param should_confirm nil|boolean
---@param cb fun(proceed: boolean)
M.show = vim.schedule_wrap(function(actions, should_confirm, cb)
  -- The schedule wrap ensures that we actually enter the floating window.
  -- Not sure why it doesn't work without that
  if should_confirm == false or #actions == 0 then
    cb(true)
    return
  end
  if should_confirm == nil and config.skip_confirm_for_simple_edits and is_simple_edit(actions) then
    cb(true)
    return
  end

  -- Create the buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  local lines = {}
  local max_line_width = 0
  for _, action in ipairs(actions) do
    local adapter = util.get_adapter_for_action(action)
    local line
    if action.type == "change" then
      line = columns.render_change_action(adapter, action)
    else
      line = adapter.render_action(action)
    end
    table.insert(lines, line)
    local line_width = vim.api.nvim_strwidth(line)
    if line_width > max_line_width then
      max_line_width = line_width
    end
  end
  table.insert(lines, "")

  -- Create the floating window
  local width, height = layout.calculate_dims(max_line_width, #lines + 1, config.preview)
  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((layout.get_editor_height() - height) / 2),
    col = math.floor((layout.get_editor_width() - width) / 2),
    zindex = 152, -- render on top of the floating window title
    style = "minimal",
    border = config.preview.border,
  })
  vim.bo[bufnr].filetype = "oil_preview"
  vim.bo[bufnr].syntax = "oil_preview"
  for k, v in pairs(config.preview.win_options) do
    vim.api.nvim_win_set_option(winid, k, v)
  end

  -- Finish setting the last line and highlights on the buffer
  width = vim.api.nvim_win_get_width(0)
  height = vim.api.nvim_win_get_height(0)
  while #lines < height - 1 do
    table.insert(lines, "")
  end
  local last_line = "[O]k    [C]ancel"
  local highlights = {}
  local padding = string.rep(" ", math.floor((width - last_line:len()) / 2))
  last_line = padding .. last_line
  table.insert(highlights, { "Special", #lines, padding:len(), padding:len() + 3 })
  table.insert(highlights, { "Special", #lines, padding:len() + 8, padding:len() + 11 })
  table.insert(lines, last_line)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.bo[bufnr].modified = false
  vim.bo[bufnr].modifiable = false
  local ns = vim.api.nvim_create_namespace("Oil")
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns, unpack(hl))
  end

  -- Attach autocmds and keymaps
  local cancel
  local confirm
  local function make_callback(value)
    return function()
      confirm = function() end
      cancel = function() end
      vim.api.nvim_win_close(winid, true)
      cb(value)
    end
  end
  cancel = make_callback(false)
  confirm = make_callback(true)
  vim.api.nvim_create_autocmd("BufLeave", {
    callback = cancel,
    once = true,
    nested = true,
    buffer = bufnr,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    callback = cancel,
    once = true,
    nested = true,
  })
  vim.keymap.set("n", "q", cancel, { buffer = bufnr })
  vim.keymap.set("n", "C", cancel, { buffer = bufnr })
  vim.keymap.set("n", "c", cancel, { buffer = bufnr })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = bufnr })
  vim.keymap.set("n", "<C-c>", cancel, { buffer = bufnr })
  vim.keymap.set("n", "O", confirm, { buffer = bufnr })
  vim.keymap.set("n", "o", confirm, { buffer = bufnr })
end)

return M
