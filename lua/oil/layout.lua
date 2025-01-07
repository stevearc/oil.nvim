local M = {}

---@param value number
---@return boolean
local function is_float(value)
  local _, p = math.modf(value)
  return p ~= 0
end

---@param value number
---@param max_value number
---@return number
local function calc_float(value, max_value)
  if value and is_float(value) then
    return math.min(max_value, value * max_value)
  else
    return value
  end
end

---@return integer
M.get_editor_width = function()
  return vim.o.columns
end

---@return integer
M.get_editor_height = function()
  local editor_height = vim.o.lines - vim.o.cmdheight
  -- Subtract 1 if tabline is visible
  if vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) then
    editor_height = editor_height - 1
  end
  -- Subtract 1 if statusline is visible
  if
    vim.o.laststatus >= 2 or (vim.o.laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1)
  then
    editor_height = editor_height - 1
  end
  return editor_height
end

local function calc_list(values, max_value, aggregator, limit)
  local ret = limit
  if not max_value or not values then
    return nil
  elseif type(values) == "table" then
    for _, v in ipairs(values) do
      ret = aggregator(ret, calc_float(v, max_value))
    end
    return ret
  else
    ret = aggregator(ret, calc_float(values, max_value))
  end
  return ret
end

local function calculate_dim(desired_size, exact_size, min_size, max_size, total_size)
  local ret = calc_float(exact_size, total_size)
  local min_val = calc_list(min_size, total_size, math.max, 1)
  local max_val = calc_list(max_size, total_size, math.min, total_size)
  if not ret then
    if not desired_size then
      if min_val and max_val then
        ret = (min_val + max_val) / 2
      else
        ret = 80
      end
    else
      ret = calc_float(desired_size, total_size)
    end
  end
  if max_val then
    ret = math.min(ret, max_val)
  end
  if min_val then
    ret = math.max(ret, min_val)
  end
  return math.floor(ret)
end

M.calculate_width = function(desired_width, opts)
  return calculate_dim(
    desired_width,
    opts.width,
    opts.min_width,
    opts.max_width,
    M.get_editor_width()
  )
end

M.calculate_height = function(desired_height, opts)
  return calculate_dim(
    desired_height,
    opts.height,
    opts.min_height,
    opts.max_height,
    M.get_editor_height()
  )
end

---@class (exact) oil.WinLayout
---@field width integer
---@field height integer
---@field row integer
---@field col integer

---@return vim.api.keyset.win_config
M.get_fullscreen_win_opts = function()
  local config = require("oil.config")

  local total_width = M.get_editor_width()
  local total_height = M.get_editor_height()
  local width = total_width - 2 * config.float.padding
  if config.float.border ~= "none" then
    width = width - 2 -- The border consumes 1 col on each side
  end
  if config.float.max_width > 0 then
    local max_width = math.floor(calc_float(config.float.max_width, total_width))
    width = math.min(width, max_width)
  end
  local height = total_height - 2 * config.float.padding
  if config.float.max_height > 0 then
    local max_height = math.floor(calc_float(config.float.max_height, total_height))
    height = math.min(height, max_height)
  end
  local row = math.floor((total_height - height) / 2)
  local col = math.floor((total_width - width) / 2) - 1 -- adjust for border width

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = config.float.border,
    zindex = 45,
  }
  return config.float.override(win_opts) or win_opts
end

---@param winid integer
---@param direction "above"|"below"|"left"|"right"|"auto"
---@param gap integer
---@return oil.WinLayout root_dim New dimensions of the original window
---@return oil.WinLayout new_dim New dimensions of the new window
M.split_window = function(winid, direction, gap)
  if direction == "auto" then
    direction = vim.o.splitright and "right" or "left"
  end

  local float_config = vim.api.nvim_win_get_config(winid)
  ---@type oil.WinLayout
  local dim_root = {
    width = float_config.width,
    height = float_config.height,
    col = float_config.col,
    row = float_config.row,
  }
  if vim.fn.has("nvim-0.10") == 0 then
    -- read https://github.com/neovim/neovim/issues/24430 for more infos.
    dim_root.col = float_config.col[vim.val_idx]
    dim_root.row = float_config.row[vim.val_idx]
  end
  local dim_new = vim.deepcopy(dim_root)

  if direction == "left" or direction == "right" then
    dim_new.width = math.floor(float_config.width / 2) - math.ceil(gap / 2)
    dim_root.width = dim_new.width
  else
    dim_new.height = math.floor(float_config.height / 2) - math.ceil(gap / 2)
    dim_root.height = dim_new.height
  end

  if direction == "left" then
    dim_root.col = dim_root.col + dim_root.width + gap
  elseif direction == "right" then
    dim_new.col = dim_new.col + dim_new.width + gap
  elseif direction == "above" then
    dim_root.row = dim_root.row + dim_root.height + gap
  elseif direction == "below" then
    dim_new.row = dim_new.row + dim_new.height + gap
  end

  return dim_root, dim_new
end

---@param desired_width integer
---@param desired_height integer
---@param opts table
---@return integer width
---@return integer height
M.calculate_dims = function(desired_width, desired_height, opts)
  local width = M.calculate_width(desired_width, opts)
  local height = M.calculate_height(desired_height, opts)
  return width, height
end

return M
