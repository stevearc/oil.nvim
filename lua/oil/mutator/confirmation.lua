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

---@param winid integer
---@param bufnr integer
---@param lines string[]
local function render_lines(winid, bufnr, lines)
  util.render_text(bufnr, lines, {
    v_align = "top",
    h_align = "left",
    winid = winid,
    actions = { "[Y]es", "[N]o" },
  })
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
      ---@cast action oil.ChangeAction
      line = columns.render_change_action(adapter, action)
    else
      line = adapter.render_action(action)
    end
    -- We can't handle lines with newlines in them
    line = line:gsub("\n", "")
    table.insert(lines, line)
    local line_width = vim.api.nvim_strwidth(line)
    if line_width > max_line_width then
      max_line_width = line_width
    end
  end
  table.insert(lines, "")

  -- Create the floating window
  local width, height = layout.calculate_dims(max_line_width, #lines + 1, config.confirmation)
  local ok, winid = pcall(vim.api.nvim_open_win, bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((layout.get_editor_height() - height) / 2),
    col = math.floor((layout.get_editor_width() - width) / 2),
    zindex = 152, -- render on top of the floating window title
    style = "minimal",
    border = config.confirmation.border,
  })
  if not ok then
    vim.notify(string.format("Error showing oil preview window: %s", winid), vim.log.levels.ERROR)
    cb(false)
  end
  vim.bo[bufnr].filetype = "oil_preview"
  vim.bo[bufnr].syntax = "oil_preview"
  for k, v in pairs(config.confirmation.win_options) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
  end

  render_lines(winid, bufnr, lines)

  local restore_cursor = util.hide_cursor()

  -- Attach autocmds and keymaps
  local cancel
  local confirm
  local autocmds = {}
  local function make_callback(value)
    return function()
      confirm = function() end
      cancel = function() end
      for _, id in ipairs(autocmds) do
        vim.api.nvim_del_autocmd(id)
      end
      autocmds = {}
      vim.api.nvim_win_close(winid, true)
      restore_cursor()
      cb(value)
    end
  end
  cancel = make_callback(false)
  confirm = make_callback(true)
  vim.api.nvim_create_autocmd("BufLeave", {
    callback = function()
      cancel()
    end,
    once = true,
    nested = true,
    buffer = bufnr,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    callback = function()
      cancel()
    end,
    once = true,
    nested = true,
  })
  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("VimResized", {
      callback = function()
        if vim.api.nvim_win_is_valid(winid) then
          width, height = layout.calculate_dims(max_line_width, #lines, config.confirmation)
          vim.api.nvim_win_set_config(winid, {
            relative = "editor",
            width = width,
            height = height,
            row = math.floor((layout.get_editor_height() - height) / 2),
            col = math.floor((layout.get_editor_width() - width) / 2),
            zindex = 152, -- render on top of the floating window title
          })
          render_lines(winid, bufnr, lines)
        end
      end,
    })
  )

  local function setup_keymaps(bufnr, confirm, cancel)
    -- Define default keymaps
    -- We used to use [O]k to confirm, so preserve the old keymap
    local default_confirm_keys = { "y", "Y", "o", "O" }
    -- We used to use [C]ancel to cancel, so preserve the old keymap
    local default_cancel_keys = { "n", "N", "c", "C", "q", "<C-c>", "<Esc>" }

    -- Get custom keymaps from config
    local custom_keymaps = config.confirmation.keymaps or {}

    -- Apply custom keymaps
    for key, action in pairs(custom_keymaps) do
      if action == "confirm" then
        vim.keymap.set("n", key, confirm, { buffer = bufnr, nowait = true })
      elseif action == "cancel" then
        vim.keymap.set("n", key, cancel, { buffer = bufnr, nowait = true })
      else
        -- Log warning for invalid mapping values
        vim.notify(
          string.format(
            "[oil.nvim] Invalid confirmation keymap action for key '%s': '%s'. " ..
            "Valid values are 'confirm' or 'cancel'." ..
            "Any other value will be ignored.", key, tostring(action)
          ),
          vim.log.levels.WARN
        )
        custom_keymaps[key] = nil
      end
    end

    -- Apply default keymaps (only if not overridden by custom keymaps)
    for _, cancel_key in ipairs(default_cancel_keys) do
      if not custom_keymaps[cancel_key] then
        vim.keymap.set("n", cancel_key, function()
          cancel()
        end, { buffer = bufnr, nowait = true })
      end
    end

    for _, confirm_key in ipairs(default_confirm_keys) do
      if not custom_keymaps[confirm_key] then
        vim.keymap.set("n", confirm_key, function()
          confirm()
        end, { buffer = bufnr, nowait = true })
      end
    end
  end

  setup_keymaps(bufnr, confirm, cancel)

end)

return M
