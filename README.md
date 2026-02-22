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

**Q: How do I set up oil.nvim with lazy.nvim?**

```lua
{
  'barrettruth/oil.nvim',
  init = function()
    vim.g.oil = {
      columns = { 'icon', 'size' },
      delete_to_trash = true,
    }
  end,
}
```

Do not use `config`, `opts`, or `lazy` — oil.nvim loads itself when you open a
directory.

**Q: How do I migrate from stevearc/oil.nvim?**

Replace `stevearc/oil.nvim` with `barrettruth/oil.nvim` in your plugin manager
and switch your `setup()` call to a `vim.g.oil` assignment in `init`. The
configuration table is the same.

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
