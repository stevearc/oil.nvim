vim.cmd([[set runtimepath+=.]])

vim.o.swapfile = false
vim.bo.swapfile = false
require("oil").setup({
  columms = {},
  adapters = {
    ["oil-test://"] = "test",
  },
  trash = false,
})
