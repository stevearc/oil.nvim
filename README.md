# oil.nvim

A [vim-vinegar](https://github.com/tpope/vim-vinegar) like file explorer that lets you edit your filesystem like a normal Neovim buffer.

https://user-images.githubusercontent.com/506791/209727111-6b4a11f4-634a-4efa-9461-80e9717cea94.mp4

This is a maintained fork of [stevearc/oil.nvim](https://github.com/stevearc/oil.nvim)
with cherry-picked upstream PRs and original bug fixes that haven't landed
upstream yet.

<details>
<summary>Changes from upstream</summary>

### PRs

Upstream PRs cherry-picked or adapted into this fork.

| PR | Description | Commit |
|---|---|---|
| [#495](https://github.com/stevearc/oil.nvim/pull/495) | Cancel visual/operator-pending mode on close instead of closing buffer | [`16f3d7b`](https://github.com/barrettruth/oil.nvim/commit/16f3d7b) |
| [#537](https://github.com/stevearc/oil.nvim/pull/537) | Configurable file and directory creation permissions (`new_file_mode`, `new_dir_mode`) | [`c6b4a7a`](https://github.com/barrettruth/oil.nvim/commit/c6b4a7a) |
| [#578](https://github.com/stevearc/oil.nvim/issues/578) | Recipe to disable hidden file dimming by relinking `Oil*Hidden` groups | [`38db6cf`](https://github.com/barrettruth/oil.nvim/commit/38db6cf) |
| [#618](https://github.com/stevearc/oil.nvim/pull/618) | Opt-in filetype detection for icons via `use_slow_filetype_detection` | [`ded1725`](https://github.com/barrettruth/oil.nvim/commit/ded1725) |
| [#644](https://github.com/stevearc/oil.nvim/pull/644) | Pass full entry to `is_hidden_file` and `is_always_hidden` callbacks | [`4ab4765`](https://github.com/barrettruth/oil.nvim/commit/4ab4765) |
| [#645](https://github.com/stevearc/oil.nvim/pull/645) | Add `close_float` action (close only floating oil windows) | [`f6bcdda`](https://github.com/barrettruth/oil.nvim/commit/f6bcdda) |
| [#690](https://github.com/stevearc/oil.nvim/pull/690) | Add `OilFileIcon` highlight group as fallback for unrecognized icons | [`ce64ae1`](https://github.com/barrettruth/oil.nvim/commit/ce64ae1) |
| [#697](https://github.com/stevearc/oil.nvim/pull/697) | Recipe for custom file extension column with sorting | [`dcb3a08`](https://github.com/barrettruth/oil.nvim/commit/dcb3a08) |
| [#698](https://github.com/stevearc/oil.nvim/pull/698) | Executable file highlighting (`OilExecutable`, `OilExecutableHidden`) | [`41556ec`](https://github.com/barrettruth/oil.nvim/commit/41556ec), [`85ed9b8`](https://github.com/barrettruth/oil.nvim/commit/85ed9b8) |
| [#717](https://github.com/stevearc/oil.nvim/pull/717) | Add malewicz1337/oil-git.nvim to third-party extensions | [`582d9fc`](https://github.com/barrettruth/oil.nvim/commit/582d9fc) |
| [#720](https://github.com/stevearc/oil.nvim/pull/720) | Gate `BufAdd` autocmd behind `default_file_explorer` check | [`2228f80`](https://github.com/barrettruth/oil.nvim/commit/2228f80) |
| [#722](https://github.com/stevearc/oil.nvim/pull/722) | Fix dead freedesktop trash specification URL | [`b92ecb0`](https://github.com/barrettruth/oil.nvim/commit/b92ecb0) |
| [#723](https://github.com/stevearc/oil.nvim/pull/723) | Emit `OilReadPost` user event after every buffer render | [`29239d5`](https://github.com/barrettruth/oil.nvim/commit/29239d5) |
| [#725](https://github.com/stevearc/oil.nvim/pull/725) | Normalize keymap keys before config merge (`<c-t>` = `<C-t>`) | [`723145c`](https://github.com/barrettruth/oil.nvim/commit/723145c) |
| [#727](https://github.com/stevearc/oil.nvim/pull/727) | Clarify `get_current_dir` nil return and add Telescope recipe | [`eed6697`](https://github.com/barrettruth/oil.nvim/commit/eed6697) |

### Issues

Upstream issues triaged against this fork.

| Issue | Status | Resolution |
|---|---|---|
| [#446](https://github.com/stevearc/oil.nvim/issues/446) | resolved | Executable highlighting — implemented by PR [#698](https://github.com/stevearc/oil.nvim/pull/698) |
| [#483](https://github.com/stevearc/oil.nvim/issues/483) | not actionable | Spell downloads depend on netrw — fixed in neovim ([neovim#34940](https://github.com/neovim/neovim/pull/34940)) |
| [#492](https://github.com/stevearc/oil.nvim/issues/492) | not actionable | Question — j/k remapping, answered in comments |
| [#533](https://github.com/stevearc/oil.nvim/issues/533) | not actionable | `constrain_cursor` — needs repro from reporter |
| [#587](https://github.com/stevearc/oil.nvim/issues/587) | not actionable | Alt+h keymap — user config issue |
| [#623](https://github.com/stevearc/oil.nvim/issues/623) | not actionable | bufferline.nvim interaction — cross-plugin issue |
| [#624](https://github.com/stevearc/oil.nvim/issues/624) | not actionable | Mutation-in-progress race — no reliable repro |
| [#632](https://github.com/stevearc/oil.nvim/issues/632) | fixed | Preview + move = copy — [`fe16993`](https://github.com/barrettruth/oil.nvim/commit/fe16993) |
| [#642](https://github.com/stevearc/oil.nvim/issues/642) | fixed | W10 warning under `nvim -R` — [`ca834cf`](https://github.com/barrettruth/oil.nvim/commit/ca834cf) |
| [#664](https://github.com/stevearc/oil.nvim/issues/664) | not actionable | Extra buffer on session reload — no repro |
| [#670](https://github.com/stevearc/oil.nvim/issues/670) | fixed | Multi-directory cmdline — [`70861e5`](https://github.com/barrettruth/oil.nvim/commit/70861e5) |
| [#673](https://github.com/stevearc/oil.nvim/issues/673) | fixed | Symlink newlines crash — [`9110a1a`](https://github.com/barrettruth/oil.nvim/commit/9110a1a) |
| [#679](https://github.com/stevearc/oil.nvim/issues/679) | resolved | Executable file sign — implemented by PR [#698](https://github.com/stevearc/oil.nvim/pull/698) |
| [#692](https://github.com/stevearc/oil.nvim/issues/692) | resolved | Keymap normalization — fixed by PR [#725](https://github.com/stevearc/oil.nvim/pull/725) |
| [#710](https://github.com/stevearc/oil.nvim/issues/710) | fixed | buftype empty on BufEnter — [`01b860e`](https://github.com/barrettruth/oil.nvim/commit/01b860e) |
| [#714](https://github.com/stevearc/oil.nvim/issues/714) | not actionable | Support question — already answered |
| [#719](https://github.com/stevearc/oil.nvim/issues/719) | not actionable | Neovim crash on node_modules delete — libuv/neovim bug |
| [#726](https://github.com/stevearc/oil.nvim/issues/726) | not actionable | Meta discussion/roadmap |

</details>

## Requirements

Neovim 0.8+ and optionally [mini.icons](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-icons.md) or [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for file icons.

## Installation

Install with your favorite package manager or with luarocks.

## Quick start

```lua
vim.g.oil = {}
```

Open a directory with `nvim .`. Use `<CR>` to open a file/directory, and `-` to go up a directory. Edit the listing like a normal buffer, then `:w` to apply changes.

## Documentation

```vim
:help oil
```

## FAQ

**Q: How do I migrate from `require("oil").setup()` to `vim.g.oil`?**

**A:** Replace your `setup()` call with a `vim.g.oil` assignment. The option
tables are identical:

```lua
-- before
require("oil").setup({
  columns = { "icon", "size" },
  delete_to_trash = true,
})

-- after
vim.g.oil = {
  columns = { "icon", "size" },
  delete_to_trash = true,
}
```

`vim.g.oil` must be set before the plugin loads (e.g. in lazy.nvim's `init`
function). `require("oil").setup(opts)` still works and takes precedence if
both are present.

**Q: Why "oil"**?

**A:** From the [vim-vinegar](https://github.com/tpope/vim-vinegar) README, a quote by Drew Neil:

> Split windows and the project drawer go together like oil and vinegar

Vinegar was taken. Let's be oil.
Plus, I think it's pretty slick ;)

**Q: Why would I want to use oil vs any other plugin?**

**A:**

- You like to use a netrw-like view to browse directories (as opposed to a file tree)
- AND you want to be able to edit your filesystem like a buffer
- AND you want to perform cross-directory actions. AFAIK there is no other plugin that does this. (update: [mini.files](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-files.md) also offers this functionality)

If you don't need those features specifically, check out the alternatives listed below

**Q: Can oil display files as a tree view**?

**A:** No. A tree view would require a completely different methodology, necessitating a complete rewrite.

**Q: What are some alternatives?**

**A:**

- [mini.files](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-files.md): Also supports cross-directory filesystem-as-buffer edits with a column view.
- [vim-vinegar](https://github.com/tpope/vim-vinegar): The granddaddy of single-directory file browsing.
- [dirbuf.nvim](https://github.com/elihunter173/dirbuf.nvim): Edit filesystem like a buffer, but no cross-directory edits.
- [lir.nvim](https://github.com/tamago324/lir.nvim): Similar to vim-vinegar with better Neovim integration.
- [vim-dirvish](https://github.com/justinmk/vim-dirvish): Stable, simple directory browser.
