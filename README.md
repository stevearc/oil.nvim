# oil.nvim

**A file explorer that lets you edit your filesystem like a buffer**

Browse directories as normal Neovim buffers, then create, rename, move, copy,
and delete files by editing the listing and saving. Cross-directory operations
work seamlessly across local, SSH, S3, and trash adapters.

https://user-images.githubusercontent.com/506791/209727111-6b4a11f4-634a-4efa-9461-80e9717cea94.mp4

## Features

- Edit directory listings as normal buffers — mutations are derived by diffing
- Cross-directory move, copy, and rename across any adapter
- Adapters for local filesystem, SSH, S3, and OS trash
- File preview in split or floating window
- Configurable columns (icon, size, permissions, timestamps)
- Executable file highlighting and filetype-aware icons
- Floating window and split layouts

## Requirements

- Neovim 0.10+
- Optional:
  [mini.icons](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-icons.md)
  or [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for
  file icons

## Installation

Install with your package manager of choice or via
[luarocks](https://luarocks.org/modules/barrettruth/oil.nvim):

```
luarocks install oil.nvim
```

## Documentation

```vim
:help oil.nvim
```

## FAQ

**Q: How do I set up oil.nvim (or migrate from stevearc/oil.nvim)?**

Change the plugin source and replace `setup()` with `vim.g.oil` in `init`. The
configuration table is identical — only the entry point changes.

Before (stevearc/oil.nvim):

```lua
{
  'stevearc/oil.nvim',
  opts = { ... },
  config = function(_, opts)
    require('oil').setup(opts)
  end,
}
```

After (barrettruth/oil.nvim):

```lua
{
  'barrettruth/oil.nvim',
  init = function()
    vim.g.oil = { ... }
  end,
}
```

`init` runs before the plugin loads; `config` runs after. oil.nvim reads
`vim.g.oil` at load time, so `init` is the correct hook. Do not use `config`,
`opts`, or `lazy` — oil.nvim loads itself when you open a directory.

**Q: Why "oil"?**

From the [vim-vinegar](https://github.com/tpope/vim-vinegar) README, a quote by
Drew Neil:

> Split windows and the project drawer go together like oil and vinegar

**Q: What are some alternatives?**

- [stevearc/oil.nvim](https://github.com/stevearc/oil.nvim): the original
  oil.nvim
- [mini.files](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-files.md):
  cross-directory filesystem-as-buffer with a column view
- [vim-vinegar](https://github.com/tpope/vim-vinegar): the granddaddy of
  single-directory file browsing
- [dirbuf.nvim](https://github.com/elihunter173/dirbuf.nvim): filesystem as
  buffer without cross-directory edits
- [lir.nvim](https://github.com/tamago324/lir.nvim): vim-vinegar style with
  Neovim integration
- [vim-dirvish](https://github.com/justinmk/vim-dirvish): stable, simple
  directory browser

## Acknowledgements

oil.nvim was created by
[Steven Arcangeli](https://github.com/stevearc/oil.nvim). This fork is
maintained by [Barrett Ruth](https://github.com/barrettruth).
