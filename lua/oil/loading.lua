local util = require("oil.util")
local M = {}

local timers = {}

local FPS = 20

---@param bufnr integer
---@return boolean
M.is_loading = function(bufnr)
  return timers[bufnr] ~= nil
end

local spinners = {
  dots = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
}

---@param name_or_frames string|string[]
---@return fun(): string
M.get_iter = function(name_or_frames)
  local frames
  if type(name_or_frames) == "string" then
    frames = spinners[name_or_frames]
    if not frames then
      error(string.format("Unrecognized spinner: '%s'", name_or_frames))
    end
  else
    frames = name_or_frames
  end
  local i = 0
  return function()
    i = (i % #frames) + 1
    return frames[i]
  end
end

M.get_bar_iter = function(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    bar_size = 3,
    width = 20,
  })
  local i = 0
  return function()
    local chars = { "[" }
    for _ = 1, opts.width - 2 do
      table.insert(chars, " ")
    end
    table.insert(chars, "]")

    for j = i - opts.bar_size, i do
      if j > 1 and j < opts.width then
        chars[j] = "="
      end
    end

    i = (i + 1) % (opts.width + opts.bar_size)
    return table.concat(chars, "")
  end
end

---@param bufnr integer
---@param is_loading boolean
M.set_loading = function(bufnr, is_loading)
  if is_loading then
    if timers[bufnr] == nil then
      local width = 20
      timers[bufnr] = vim.loop.new_timer()
      local bar_iter = M.get_bar_iter({ width = width })
      timers[bufnr]:start(
        200, -- Delay the loading screen just a bit to avoid flicker
        math.floor(1000 / FPS),
        vim.schedule_wrap(function()
          if not vim.api.nvim_buf_is_valid(bufnr) or not timers[bufnr] then
            M.set_loading(bufnr, false)
            return
          end
          local lines = { util.lpad("Loading", math.floor(width / 2) - 3), bar_iter() }
          util.render_text(bufnr, lines)
        end)
      )
    end
  elseif timers[bufnr] then
    timers[bufnr]:close()
    timers[bufnr] = nil
  end
end

return M
