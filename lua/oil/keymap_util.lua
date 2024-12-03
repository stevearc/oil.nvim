local actions = require("oil.actions")
local config = require("oil.config")
local layout = require("oil.layout")
local util = require("oil.util")
local M = {}

---@param rhs string|table|fun()
---@return string|fun() rhs
---@return table opts
---@return string|nil mode
local function resolve(rhs)
  if type(rhs) == "string" and vim.startswith(rhs, "actions.") then
    local action_name = vim.split(rhs, ".", { plain = true })[2]
    local action = actions[action_name]
    if not action then
      vim.notify("[oil.nvim] Unknown action name: " .. action_name, vim.log.levels.ERROR)
    end
    return resolve(action)
  elseif type(rhs) == "table" then
    local opts = vim.deepcopy(rhs)
    -- We support passing in a `callback` key, or using the 1 index as the rhs of the keymap
    local callback, parent_opts = resolve(opts.callback or opts[1])

    -- Fall back to the parent desc, adding the opts as a string if it exists
    if parent_opts.desc and not opts.desc then
      if opts.opts then
        opts.desc =
          string.format("%s %s", parent_opts.desc, vim.inspect(opts.opts):gsub("%s+", " "))
      else
        opts.desc = parent_opts.desc
      end
    end

    local mode = opts.mode
    if type(rhs.callback) == "string" then
      local action_opts, action_mode
      callback, action_opts, action_mode = resolve(rhs.callback)
      opts = vim.tbl_extend("keep", opts, action_opts)
      mode = mode or action_mode
    end

    -- remove all the keys that we can't pass as options to `vim.keymap.set`
    opts.callback = nil
    opts.mode = nil
    opts[1] = nil
    opts.deprecated = nil
    opts.parameters = nil

    if opts.opts and type(callback) == "function" then
      local callback_args = opts.opts
      opts.opts = nil
      local orig_callback = callback
      callback = function()
        ---@diagnostic disable-next-line: redundant-parameter
        orig_callback(callback_args)
      end
    end

    return callback, opts, mode
  else
    return rhs, {}
  end
end

---@param keymaps table<string, string|table|fun()>
---@param bufnr integer
M.set_keymaps = function(keymaps, bufnr)
  for k, v in pairs(keymaps) do
    local rhs, opts, mode = resolve(v)
    if rhs then
      vim.keymap.set(mode or "", k, rhs, vim.tbl_extend("keep", { buffer = bufnr }, opts))
    end
  end
end

---@param keymaps table<string, string|table|fun()>
M.show_help = function(keymaps)
  local rhs_to_lhs = {}
  local lhs_to_all_lhs = {}
  for k, rhs in pairs(keymaps) do
    if rhs then
      if rhs_to_lhs[rhs] then
        local first_lhs = rhs_to_lhs[rhs]
        table.insert(lhs_to_all_lhs[first_lhs], k)
      else
        rhs_to_lhs[rhs] = k
        lhs_to_all_lhs[k] = { k }
      end
    end
  end

  local max_lhs = 1
  local keymap_entries = {}
  for k, rhs in pairs(keymaps) do
    local all_lhs = lhs_to_all_lhs[k]
    if all_lhs then
      local _, opts = resolve(rhs)
      local keystr = table.concat(all_lhs, "/")
      max_lhs = math.max(max_lhs, vim.api.nvim_strwidth(keystr))
      table.insert(keymap_entries, { str = keystr, all_lhs = all_lhs, desc = opts.desc or "" })
    end
  end
  table.sort(keymap_entries, function(a, b)
    return a.desc < b.desc
  end)

  local lines = {}
  local highlights = {}
  local max_line = 1
  for _, entry in ipairs(keymap_entries) do
    local line = string.format(" %s   %s", util.rpad(entry.str, max_lhs), entry.desc)
    max_line = math.max(max_line, vim.api.nvim_strwidth(line))
    table.insert(lines, line)
    local start = 1
    for _, key in ipairs(entry.all_lhs) do
      local keywidth = vim.api.nvim_strwidth(key)
      table.insert(highlights, { "Special", #lines, start, start + keywidth })
      start = start + keywidth + 1
    end
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local ns = vim.api.nvim_create_namespace("Oil")
  for _, hl in ipairs(highlights) do
    local hl_group, lnum, start_col, end_col = unpack(hl)
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, start_col, {
      end_col = end_col,
      hl_group = hl_group,
    })
  end
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = bufnr })
  vim.keymap.set("n", "<c-c>", "<cmd>close<CR>", { buffer = bufnr })
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].bufhidden = "wipe"

  local editor_width = vim.o.columns
  local editor_height = layout.get_editor_height()
  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = math.max(0, (editor_height - #lines) / 2),
    col = math.max(0, (editor_width - max_line - 1) / 2),
    width = math.min(editor_width, max_line + 1),
    height = math.min(editor_height, #lines),
    zindex = 150,
    style = "minimal",
    border = config.keymaps_help.border,
  })
  local function close()
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, true)
    end
  end
  vim.api.nvim_create_autocmd("BufLeave", {
    callback = close,
    once = true,
    nested = true,
    buffer = bufnr,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    callback = close,
    once = true,
    nested = true,
  })
end

return M
