# oil.nvim

A [vim-vinegar](https://github.com/tpope/vim-vinegar) like file explorer that lets you edit your filesystem like a normal Neovim buffer.

https://user-images.githubusercontent.com/506791/209727111-6b4a11f4-634a-4efa-9461-80e9717cea94.mp4

<!-- TOC -->

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Options](#options)
- [Adapters](#adapters)
- [API](#api)
- [FAQ](#faq)

<!-- /TOC -->

## Requirements

- Neovim 0.8+
- (optional) [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for file icons

## Installation

oil.nvim supports all the usual plugin managers

<details>
  <summary>lazy.nvim</summary>

```lua
{
  'stevearc/oil.nvim',
  opts = {},
  -- Optional dependencies
  dependencies = { "nvim-tree/nvim-web-devicons" },
}
```

</details>

<details>
  <summary>Packer</summary>

```lua
require('packer').startup(function()
    use {
      'stevearc/oil.nvim',
      config = function() require('oil').setup() end
    }
end)
```

</details>

<details>
  <summary>Paq</summary>

```lua
require "paq" {
    {'stevearc/oil.nvim'};
}
```

</details>

<details>
  <summary>vim-plug</summary>

```vim
Plug 'stevearc/oil.nvim'
```

</details>

<details>
  <summary>dein</summary>

```vim
call dein#add('stevearc/oil.nvim')
```

</details>

<details>
  <summary>Pathogen</summary>

```sh
git clone --depth=1 https://github.com/stevearc/oil.nvim.git ~/.vim/bundle/
```

</details>

<details>
  <summary>Neovim native package</summary>

```sh
git clone --depth=1 https://github.com/stevearc/oil.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/oil/start/oil.nvim
```

</details>

## Quick start

Add the following to your init.lua

```lua
require("oil").setup()
```

Then open a directory with `nvim .`. Use `<CR>` to open a file/directory, and `-` to go up a directory. Otherwise, just treat it like a normal buffer and make changes as you like. Remember to `:w` when you're done to actually perform the actions.

If you want to mimic the `vim-vinegar` method of navigating to the parent directory of a file, add this keymap:

```lua
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
```

You can open a directory with `:edit <path>` or `:Oil <path>`. To open oil in a floating window, do `:Oil --float <path>`.

## Options

```lua
require("oil").setup({
  -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
  -- Set to false if you still want to use netrw.
  default_file_explorer = true,
  -- Id is automatically added at the beginning, and name at the end
  -- See :help oil-columns
  columns = {
    "icon",
    -- "permissions",
    -- "size",
    -- "mtime",
  },
  -- Buffer-local options to use for oil buffers
  buf_options = {
    buflisted = false,
    bufhidden = "hide",
  },
  -- Window-local options to use for oil buffers
  win_options = {
    wrap = false,
    signcolumn = "no",
    cursorcolumn = false,
    foldcolumn = "0",
    spell = false,
    list = false,
    conceallevel = 3,
    concealcursor = "n",
  },
  -- Restore window options to previous values when leaving an oil buffer
  restore_win_options = true,
  -- Skip the confirmation popup for simple operations
  skip_confirm_for_simple_edits = false,
  -- Deleted files will be removed with the trash_command (below).
  delete_to_trash = false,
  -- Change this to customize the command used when deleting to trash
  trash_command = "trash-put",
  -- Selecting a new/moved/renamed file or directory will prompt you to save changes first
  prompt_save_on_select_new_entry = true,
  -- Keymaps in oil buffer. Can be any value that `vim.keymap.set` accepts OR a table of keymap
  -- options with a `callback` (e.g. { callback = function() ... end, desc = "", nowait = true })
  -- Additionally, if it is a string that matches "actions.<name>",
  -- it will use the mapping at require("oil.actions").<name>
  -- Set to `false` to remove a keymap
  -- See :help oil-actions for a list of all available actions
  keymaps = {
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.select",
    ["<C-s>"] = "actions.select_vsplit",
    ["<C-h>"] = "actions.select_split",
    ["<C-t>"] = "actions.select_tab",
    ["<C-p>"] = "actions.preview",
    ["<C-c>"] = "actions.close",
    ["<C-l>"] = "actions.refresh",
    ["-"] = "actions.parent",
    ["_"] = "actions.open_cwd",
    ["`"] = "actions.cd",
    ["~"] = "actions.tcd",
    ["g."] = "actions.toggle_hidden",
  },
  -- Set to false to disable all of the above keymaps
  use_default_keymaps = true,
  view_options = {
    -- Show files and directories that start with "."
    show_hidden = false,
    -- This function defines what is considered a "hidden" file
    is_hidden_file = function(name, bufnr)
      return vim.startswith(name, ".")
    end,
    -- This function defines what will never be shown, even when `show_hidden` is set
    is_always_hidden = function(name, bufnr)
      return false
    end,
  },
  -- Configuration for the floating window in oil.open_float
  float = {
    -- Padding around the floating window
    padding = 2,
    max_width = 0,
    max_height = 0,
    border = "rounded",
    win_options = {
      winblend = 10,
    },
    -- This is the config that will be passed to nvim_open_win.
    -- Change values here to customize the layout
    override = function(conf)
      return conf
    end,
  },
  -- Configuration for the actions floating preview window
  preview = {
    -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_width and max_width can be a single value or a list of mixed integer/float types.
    -- max_width = {100, 0.8} means "the lesser of 100 columns or 80% of total"
    max_width = 0.9,
    -- min_width = {40, 0.4} means "the greater of 40 columns or 40% of total"
    min_width = { 40, 0.4 },
    -- optionally define an integer/float for the exact width of the preview window
    width = nil,
    -- Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_height and max_height can be a single value or a list of mixed integer/float types.
    -- max_height = {80, 0.9} means "the lesser of 80 columns or 90% of total"
    max_height = 0.9,
    -- min_height = {5, 0.1} means "the greater of 5 columns or 10% of total"
    min_height = { 5, 0.1 },
    -- optionally define an integer/float for the exact height of the preview window
    height = nil,
    border = "rounded",
    win_options = {
      winblend = 0,
    },
  },
  -- Configuration for the floating progress window
  progress = {
    max_width = 0.9,
    min_width = { 40, 0.4 },
    width = nil,
    max_height = { 10, 0.9 },
    min_height = { 5, 0.1 },
    height = nil,
    border = "rounded",
    minimized_border = "none",
    win_options = {
      winblend = 0,
    },
  },
})
```

## Adapters

Oil does all of its filesystem interaction through an _adapter_ abstraction. In practice, this means that oil can be used to view and modify files in more places than just the local filesystem, so long as the destination has an adapter implementation.

Note that file operations work _across adapters_. This means that you can use oil to copy files to/from a remote server using the ssh adapter just as easily as you can copy files from one directory to another on your local machine.

### SSH

This adapter allows you to browse files over ssh, much like netrw. To use it, simply open a buffer using the following name template:

```
nvim oil-ssh://[username@]hostname[:port]/[path]
```

This may look familiar. In fact, this is the same url format that netrw uses.

Note that at the moment the ssh adapter does not support Windows machines, and it requires the server to have a `/bin/sh` binary as well as standard unix commands (`rm`, `mv`, `mkdir`, `chmod`, `cp`, `touch`, `ln`, `echo`).

## API

<!-- API -->

- [get_entry_on_line(bufnr, lnum)](doc/api.md#get_entry_on_linebufnr-lnum)
- [get_cursor_entry()](doc/api.md#get_cursor_entry)
- [discard_all_changes()](doc/api.md#discard_all_changes)
- [set_columns(cols)](doc/api.md#set_columnscols)
- [set_is_hidden_file(is_hidden_file)](doc/api.md#set_is_hidden_fileis_hidden_file)
- [toggle_hidden()](doc/api.md#toggle_hidden)
- [get_current_dir()](doc/api.md#get_current_dir)
- [open_float(dir)](doc/api.md#open_floatdir)
- [toggle_float(dir)](doc/api.md#toggle_floatdir)
- [open(dir)](doc/api.md#opendir)
- [close()](doc/api.md#close)
- [select(opts, callback)](doc/api.md#selectopts-callback)
- [save(opts)](doc/api.md#saveopts)
- [setup(opts)](doc/api.md#setupopts)

<!-- /API -->

## FAQ

**Q: Why "oil"**?

**A:** From the [vim-vinegar](https://github.com/tpope/vim-vinegar) README, a quote by Drew Neil:

> Split windows and the project drawer go together like oil and vinegar

Vinegar was taken. Let's be oil.
Plus, I think it's pretty slick ;)

**Q: Why would I want to use oil vs any other plugin?**

**A:**

- You like to use a netrw-like view to browse directories (as opposed to a file tree)
- AND you want to be able to edit your filesystem like a buffer
- AND you want to perform cross-directory actions. AFAIK there is no other plugin that does this. (update: [mini.files](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-files.md) also offers this functionality)

If you don't need those features specifically, check out the alternatives listed below

**Q: Why write another plugin yourself instead of adding functionality to one that already exists**?

**A:** Because I am a _maniac control freak_.

**Q: Can oil display files as a tree view**?

**A:** No. A tree view would require a completely different methodology, necessitating a complete rewrite. I don't use tree views, so I will leave this as a plugin for someone else to write.

**Q: What are some alternatives?**

**A:**

- [mini.files](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-files.md): A newer plugin that also supports cross-directory filesystem-as-buffer edits. It utilizes a unique column view.
- [vim-vinegar](https://github.com/tpope/vim-vinegar): The granddaddy. This made me fall in love with single-directory file browsing. I stopped using it when I encountered netrw bugs and performance issues.
- [defx.nvim](https://github.com/Shougo/defx.nvim): What I switched to after vim-vinegar. Much more flexible and performant, but requires python and the API is a little hard to work with.
- [dirbuf.nvim](https://github.com/elihunter173/dirbuf.nvim): The first plugin I encountered that let you edit the filesystem like a buffer. Never used it because it [can't do cross-directory edits](https://github.com/elihunter173/dirbuf.nvim/issues/7).
- [lir.nvim](https://github.com/tamago324/lir.nvim): What I used prior to writing this plugin. Similar to vim-vinegar, but with better Neovim integration (floating windows, lua API).
- [vim-dirvish](https://github.com/justinmk/vim-dirvish): Never personally used, but well-established, stable, simple directory browser.
- [vidir](https://github.com/trapd00r/vidir): Never personally used, but might be the first plugin to come up with the idea of editing a directory like a buffer.

There's also file trees like [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) and [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua), but they're really a different category entirely.
