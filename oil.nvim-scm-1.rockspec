rockspec_format = '3.0'
package = 'oil.nvim'
version = 'scm-1'

source = {
  url = 'git+https://github.com/barrettruth/oil.nvim.git',
}

description = {
  summary = 'Neovim file explorer: edit your filesystem like a buffer',
  homepage = 'https://github.com/barrettruth/oil.nvim',
  license = 'MIT',
}

dependencies = {
  'lua >= 5.1',
}

test_dependencies = {
  'nlua',
  'busted >= 2.1.1',
}

test = {
  type = 'busted',
}

build = {
  type = 'builtin',
}
