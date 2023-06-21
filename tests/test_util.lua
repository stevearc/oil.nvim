require("plenary.async").tests.add_to_env()
local cache = require("oil.cache")
local M = {}

M.reset_editor = function()
  require("oil").setup({
    columms = {},
    adapters = {
      ["oil-test://"] = "test",
    },
    prompt_save_on_select_new_entry = false,
  })
  vim.cmd.tabonly({ mods = { silent = true } })
  for i, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if i > 1 then
      vim.api.nvim_win_close(winid, true)
    end
  end
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  cache.clear_everything()
end

M.wait_for_autocmd = a.wrap(function(autocmd, cb)
  local opts = {
    pattern = "*",
    nested = true,
    once = true,
  }
  if type(autocmd) == "table" then
    opts = vim.tbl_extend("force", opts, autocmd)
    autocmd = autocmd[1]
    opts[1] = nil
  end
  opts.callback = vim.schedule_wrap(cb)

  vim.api.nvim_create_autocmd(autocmd, opts)
end, 2)

---@param actions string[]
---@param timestep integer
M.feedkeys = function(actions, timestep)
  timestep = timestep or 10
  a.util.sleep(timestep)
  for _, action in ipairs(actions) do
    a.util.sleep(timestep)
    local escaped = vim.api.nvim_replace_termcodes(action, true, false, true)
    vim.api.nvim_feedkeys(escaped, "m", true)
  end
  a.util.sleep(timestep)
  -- process pending keys until the queue is empty.
  -- Note that this will exit insert mode.
  vim.api.nvim_feedkeys("", "x", true)
  a.util.sleep(timestep)
end

return M
