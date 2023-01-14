require("plenary.async").tests.add_to_env()
local M = {}

M.reset_editor = function()
  require("oil").setup({})
  vim.cmd.tabonly({ mods = { silent = true } })
  for i, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if i > 1 then
      vim.api.nvim_win_close(winid, true)
    end
  end
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(false, true))
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_option(bufnr, "buflisted") then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

M.wait_for_autocmd = a.wrap(function(autocmd, cb)
  vim.api.nvim_create_autocmd(autocmd, {
    pattern = "*",
    nested = true,
    once = true,
    callback = vim.schedule_wrap(cb),
  })
end, 2)

return M
