local cache = require('oil.cache')
local test_adapter = require('oil.adapters.test')
local util = require('oil.util')
local M = {}

M.reset_editor = function()
  require('oil').setup({
    columms = {},
    adapters = {
      ['oil-test://'] = 'test',
    },
    prompt_save_on_select_new_entry = false,
  })
  vim.cmd.tabonly({ mods = { silent = true } })
  vim.cmd.new()
  vim.cmd.only()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  cache.clear_everything()
  test_adapter.test_clear()
end

local function throwiferr(err, ...)
  if err then
    error(err)
  else
    return ...
  end
end

M.await = function(fn, nargs, ...)
  local done = false
  local results
  local n_results = 0
  local args = { ... }
  args[nargs] = function(...)
    results = { ... }
    n_results = select('#', ...)
    done = true
  end
  fn(unpack(args, 1, nargs))
  vim.wait(10000, function()
    return done
  end, 10)
  if not done then
    error('M.await timed out')
  end
  return unpack(results, 1, n_results)
end

M.await_throwiferr = function(fn, nargs, ...)
  return throwiferr(M.await(fn, nargs, ...))
end

M.oil_open = function(...)
  M.await(require('oil').open, 3, ...)
end

M.wait_for_autocmd = function(autocmd)
  local triggered = false
  local opts = {
    pattern = '*',
    nested = true,
    once = true,
  }
  if type(autocmd) == 'table' then
    opts = vim.tbl_extend('force', opts, autocmd)
    autocmd = autocmd[1]
    opts[1] = nil
  end
  opts.callback = vim.schedule_wrap(function()
    triggered = true
  end)
  vim.api.nvim_create_autocmd(autocmd, opts)
  vim.wait(10000, function()
    return triggered
  end, 10)
  if not triggered then
    error('wait_for_autocmd timed out waiting for ' .. tostring(autocmd))
  end
end

M.wait_oil_ready = function()
  local ready = false
  util.run_after_load(
    0,
    vim.schedule_wrap(function()
      ready = true
    end)
  )
  vim.wait(10000, function()
    return ready
  end, 10)
  if not ready then
    error('wait_oil_ready timed out')
  end
end

---@param actions string[]
---@param timestep integer
M.feedkeys = function(actions, timestep)
  timestep = timestep or 10
  vim.wait(timestep)
  for _, action in ipairs(actions) do
    vim.wait(timestep)
    local escaped = vim.api.nvim_replace_termcodes(action, true, false, true)
    vim.api.nvim_feedkeys(escaped, 'm', true)
  end
  vim.wait(timestep)
  vim.api.nvim_feedkeys('', 'x', true)
  vim.wait(timestep)
end

M.actions = {
  ---Open oil and wait for it to finish rendering
  ---@param args string[]
  open = function(args)
    vim.schedule(function()
      vim.cmd.Oil({ args = args })
      if vim.b.oil_ready then
        vim.api.nvim_exec_autocmds('User', {
          pattern = 'OilEnter',
          modeline = false,
          data = { buf = vim.api.nvim_get_current_buf() },
        })
      end
    end)
    M.wait_for_autocmd({ 'User', pattern = 'OilEnter' })
  end,

  ---Save all changes and wait for operation to complete
  save = function()
    vim.schedule_wrap(require('oil').save)({ confirm = false })
    M.wait_for_autocmd({ 'User', pattern = 'OilMutationComplete' })
  end,

  ---@param bufnr? integer
  reload = function(bufnr)
    M.await(require('oil.view').render_buffer_async, 3, bufnr or 0)
  end,

  ---Move cursor to a file or directory in an oil buffer
  ---@param filename string
  focus = function(filename)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local search = ' ' .. filename .. '$'
    for i, line in ipairs(lines) do
      if line:match(search) then
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        return
      end
    end
    error('Could not find file ' .. filename)
  end,
}

---Get the raw list of filenames from an unmodified oil buffer
---@param bufnr? integer
---@return string[]
M.parse_entries = function(bufnr)
  bufnr = bufnr or 0
  if vim.bo[bufnr].modified then
    error("parse_entries doesn't work on a modified oil buffer")
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  return vim.tbl_map(function(line)
    return line:match('^/%d+ +(.+)$')
  end, lines)
end

return M
