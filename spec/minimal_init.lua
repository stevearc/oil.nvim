vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.opt.runtimepath:append('.')
vim.opt.packpath = {}
vim.o.swapfile = false
vim.cmd('filetype on')
vim.fn.mkdir(vim.fn.stdpath('cache'), 'p')
vim.fn.mkdir(vim.fn.stdpath('data'), 'p')
vim.fn.mkdir(vim.fn.stdpath('state'), 'p')
require('spec.test_util').reset_editor()
