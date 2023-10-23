vim.opt.runtimepath:append(".")

vim.o.swapfile = false
vim.bo.swapfile = false
require("tests.test_util").reset_editor()
