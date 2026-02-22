# oil.nvim

A [vim-vinegar](https://github.com/tpope/vim-vinegar) like file explorer that lets you edit your filesystem like a normal Neovim buffer.

https://user-images.githubusercontent.com/506791/209727111-6b4a11f4-634a-4efa-9461-80e9717cea94.mp4

This is a maintained fork of [stevearc/oil.nvim](https://github.com/stevearc/oil.nvim)
with cherry-picked upstream PRs and original bug fixes that haven't landed
upstream yet.

<details>
<summary>Changes from upstream</summary>

### Cherry-picked PRs

Upstream PRs cherry-picked or adapted into this fork.

| PR | Description | Commit |
|---|---|---|
| [#495](https://github.com/stevearc/oil.nvim/pull/495) | Cancel visual/operator-pending mode on close | [`16f3d7b`](https://github.com/barrettruth/oil.nvim/commit/16f3d7b) |
| [#537](https://github.com/stevearc/oil.nvim/pull/537) | Configurable file/directory creation permissions | [`c6b4a7a`](https://github.com/barrettruth/oil.nvim/commit/c6b4a7a) |
| [#618](https://github.com/stevearc/oil.nvim/pull/618) | Opt-in filetype detection for icons | [`ded1725`](https://github.com/barrettruth/oil.nvim/commit/ded1725) |
| [#644](https://github.com/stevearc/oil.nvim/pull/644) | Pass entry to `is_hidden_file`/`is_always_hidden` | [`4ab4765`](https://github.com/barrettruth/oil.nvim/commit/4ab4765) |
| [#697](https://github.com/stevearc/oil.nvim/pull/697) | Recipe for file extension column | [`dcb3a08`](https://github.com/barrettruth/oil.nvim/commit/dcb3a08) |
| [#698](https://github.com/stevearc/oil.nvim/pull/698) | Executable file highlighting | [`41556ec`](https://github.com/barrettruth/oil.nvim/commit/41556ec), [`85ed9b8`](https://github.com/barrettruth/oil.nvim/commit/85ed9b8) |
| [#717](https://github.com/stevearc/oil.nvim/pull/717) | Add oil-git.nvim to extensions | [`582d9fc`](https://github.com/barrettruth/oil.nvim/commit/582d9fc) |
| [#720](https://github.com/stevearc/oil.nvim/pull/720) | Gate `BufAdd` autocmd behind config check | [`2228f80`](https://github.com/barrettruth/oil.nvim/commit/2228f80) |
| [#722](https://github.com/stevearc/oil.nvim/pull/722) | Fix freedesktop trash URL | [`b92ecb0`](https://github.com/barrettruth/oil.nvim/commit/b92ecb0) |
| [#723](https://github.com/stevearc/oil.nvim/pull/723) | Emit `OilReadPost` event after render | [`29239d5`](https://github.com/barrettruth/oil.nvim/commit/29239d5) |
| [#725](https://github.com/stevearc/oil.nvim/pull/725) | Normalize keymap keys before config merge | [`723145c`](https://github.com/barrettruth/oil.nvim/commit/723145c) |
| [#727](https://github.com/stevearc/oil.nvim/pull/727) | Clarify `get_current_dir` nil + Telescope recipe | [`eed6697`](https://github.com/barrettruth/oil.nvim/commit/eed6697) |

### Open upstream PRs

Open PRs on upstream not yet incorporated into this fork.

| PR | Description | Status |
|---|---|---|
| [#488](https://github.com/stevearc/oil.nvim/pull/488) | Parent directory in a split | not actionable — empty PR, 0 changes |
| [#493](https://github.com/stevearc/oil.nvim/pull/493) | UNC paths on Windows | not actionable — superseded by [#686](https://github.com/stevearc/oil.nvim/pull/686) |
| [#591](https://github.com/stevearc/oil.nvim/pull/591) | release-please changelog | not applicable — fork uses different release process |
| [#667](https://github.com/stevearc/oil.nvim/pull/667) | Virtual text columns + headers | deferred — WIP, conflicting |
| [#686](https://github.com/stevearc/oil.nvim/pull/686) | Windows path conversion fix | not actionable — Windows-only |
| [#708](https://github.com/stevearc/oil.nvim/pull/708) | Move file into new dir by renaming | deferred — needs rewrite for multi-level dirs, tests |
| [#721](https://github.com/stevearc/oil.nvim/pull/721) | `create_hook` to populate file contents | open |
| [#728](https://github.com/stevearc/oil.nvim/pull/728) | `open_split` for opening oil in a split | tracked — [barrettruth/oil.nvim#2](https://github.com/barrettruth/oil.nvim/issues/2) |

### Issues

All open upstream issues, triaged against this fork.

**Status key:** `fixed` = original fix in fork, `resolved` = addressed by cherry-picked PR,
`not actionable` = can't/won't fix, `tracking` = known/not yet addressed, `open` = not yet triaged.

| Issue | Status | Notes |
|---|---|---|
| [#85](https://github.com/stevearc/oil.nvim/issues/85) | open | Git status column (P2) |
| [#95](https://github.com/stevearc/oil.nvim/issues/95) | open | Undo after renaming files (P1) |
| [#117](https://github.com/stevearc/oil.nvim/issues/117) | open | Move file into new dir via slash in name (P1, related to [#708](https://github.com/stevearc/oil.nvim/pull/708)) |
| [#156](https://github.com/stevearc/oil.nvim/issues/156) | open | Paste path of files into oil buffer (P2) |
| [#200](https://github.com/stevearc/oil.nvim/issues/200) | open | Highlights not working when opening a file (P2) |
| [#207](https://github.com/stevearc/oil.nvim/issues/207) | open | Suppress "no longer available" message (P1) |
| [#210](https://github.com/stevearc/oil.nvim/issues/210) | open | FTP support (P2) |
| [#213](https://github.com/stevearc/oil.nvim/issues/213) | open | Disable preview for large files (P1) |
| [#226](https://github.com/stevearc/oil.nvim/issues/226) | open | K8s/Docker adapter (P2) |
| [#232](https://github.com/stevearc/oil.nvim/issues/232) | open | Cannot close last window (P2) |
| [#254](https://github.com/stevearc/oil.nvim/issues/254) | open | Buffer modified highlight group (P2) |
| [#263](https://github.com/stevearc/oil.nvim/issues/263) | open | Diff mode (P2) |
| [#276](https://github.com/stevearc/oil.nvim/issues/276) | open | Archives manipulation (P2) |
| [#280](https://github.com/stevearc/oil.nvim/issues/280) | open | vim-projectionist support (P2) |
| [#288](https://github.com/stevearc/oil.nvim/issues/288) | open | Oil failing to load (P2) |
| [#289](https://github.com/stevearc/oil.nvim/issues/289) | open | Show absolute path toggle (P2) |
| [#294](https://github.com/stevearc/oil.nvim/issues/294) | open | Can't handle emojis in filenames (P2) |
| [#298](https://github.com/stevearc/oil.nvim/issues/298) | open | Open float on neovim directory startup (P2) |
| [#302](https://github.com/stevearc/oil.nvim/issues/302) | open | C-o parent nav makes buffer buflisted (P0) |
| [#303](https://github.com/stevearc/oil.nvim/issues/303) | open | Preview in float window mode (P2) |
| [#325](https://github.com/stevearc/oil.nvim/issues/325) | open | oil-ssh error from command line (P0) |
| [#330](https://github.com/stevearc/oil.nvim/issues/330) | open | File opens in floating modal |
| [#332](https://github.com/stevearc/oil.nvim/issues/332) | open | Buffer not fixed to floating window (P2) |
| [#335](https://github.com/stevearc/oil.nvim/issues/335) | open | Disable editing outside root dir |
| [#349](https://github.com/stevearc/oil.nvim/issues/349) | open | Parent directory as column/vsplit (P2) |
| [#351](https://github.com/stevearc/oil.nvim/issues/351) | open | Paste deleted file from register |
| [#359](https://github.com/stevearc/oil.nvim/issues/359) | open | Parse error on filenames differing by space (P1) |
| [#360](https://github.com/stevearc/oil.nvim/issues/360) | open | Pick window to open file into |
| [#362](https://github.com/stevearc/oil.nvim/issues/362) | open | "Could not find oil adapter for scheme" error |
| [#363](https://github.com/stevearc/oil.nvim/issues/363) | open | `prompt_save_on_select_new_entry` uses wrong prompt |
| [#371](https://github.com/stevearc/oil.nvim/issues/371) | open | Constrain cursor in insert mode |
| [#373](https://github.com/stevearc/oil.nvim/issues/373) | open | Dir from quickfix with bqf/trouble broken (P1) |
| [#375](https://github.com/stevearc/oil.nvim/issues/375) | open | Highlights for file types and permissions (P2) |
| [#380](https://github.com/stevearc/oil.nvim/issues/380) | open | Show file in oil when editing hidden file |
| [#382](https://github.com/stevearc/oil.nvim/issues/382) | open | Relative path in window title (P2) |
| [#392](https://github.com/stevearc/oil.nvim/issues/392) | open | Option to skip delete prompt |
| [#393](https://github.com/stevearc/oil.nvim/issues/393) | open | Auto-save new buffer on entry |
| [#396](https://github.com/stevearc/oil.nvim/issues/396) | open | Customize preview content (P2) |
| [#399](https://github.com/stevearc/oil.nvim/issues/399) | open | Open file without closing Oil (P1) |
| [#404](https://github.com/stevearc/oil.nvim/issues/404) | not actionable | Restricted UNC paths — Windows-only (P2) |
| [#416](https://github.com/stevearc/oil.nvim/issues/416) | open | Cannot remap key to open split |
| [#431](https://github.com/stevearc/oil.nvim/issues/431) | open | More SSH adapter documentation |
| [#435](https://github.com/stevearc/oil.nvim/issues/435) | open | Error previewing with semantic tokens LSP |
| [#436](https://github.com/stevearc/oil.nvim/issues/436) | open | Owner and group columns (P2) |
| [#444](https://github.com/stevearc/oil.nvim/issues/444) | open | Opening behaviour customization |
| [#446](https://github.com/stevearc/oil.nvim/issues/446) | resolved | Executable highlighting — PR [#698](https://github.com/stevearc/oil.nvim/pull/698) |
| [#449](https://github.com/stevearc/oil.nvim/issues/449) | open | Renaming TypeScript files stopped working |
| [#450](https://github.com/stevearc/oil.nvim/issues/450) | open | Highlight opened file in directory listing |
| [#457](https://github.com/stevearc/oil.nvim/issues/457) | open | Custom column API |
| [#466](https://github.com/stevearc/oil.nvim/issues/466) | open | Select into window on right |
| [#473](https://github.com/stevearc/oil.nvim/issues/473) | open | Show all hidden files if dir only has hidden |
| [#479](https://github.com/stevearc/oil.nvim/issues/479) | open | Harpoon integration recipe |
| [#483](https://github.com/stevearc/oil.nvim/issues/483) | not actionable | Spell downloads depend on netrw — fixed in [neovim#34940](https://github.com/neovim/neovim/pull/34940) |
| [#486](https://github.com/stevearc/oil.nvim/issues/486) | open | All directory sizes show 4.1k |
| [#492](https://github.com/stevearc/oil.nvim/issues/492) | not actionable | j/k remapping question — answered in comments |
| [#507](https://github.com/stevearc/oil.nvim/issues/507) | open | lacasitos.nvim conflict (P1) |
| [#521](https://github.com/stevearc/oil.nvim/issues/521) | open | oil-ssh connection issues |
| [#525](https://github.com/stevearc/oil.nvim/issues/525) | open | SSH adapter documentation (P2) |
| [#531](https://github.com/stevearc/oil.nvim/issues/531) | not actionable | Windows — incomplete drive letters (P1) |
| [#533](https://github.com/stevearc/oil.nvim/issues/533) | not actionable | `constrain_cursor` — needs repro |
| [#570](https://github.com/stevearc/oil.nvim/issues/570) | open | Improve c0/d0 for renaming |
| [#571](https://github.com/stevearc/oil.nvim/issues/571) | open | Callback before `highlight_filename` (P2) |
| [#578](https://github.com/stevearc/oil.nvim/issues/578) | resolved | Hidden file dimming recipe — [`38db6cf`](https://github.com/barrettruth/oil.nvim/commit/38db6cf) |
| [#587](https://github.com/stevearc/oil.nvim/issues/587) | not actionable | Alt+h keymap — user config issue |
| [#599](https://github.com/stevearc/oil.nvim/issues/599) | open | user:group display and manipulation (P2) |
| [#607](https://github.com/stevearc/oil.nvim/issues/607) | open | Per-host SCP args (P2) |
| [#609](https://github.com/stevearc/oil.nvim/issues/609) | open | Cursor placement via Snacks picker |
| [#612](https://github.com/stevearc/oil.nvim/issues/612) | open | Delete buffers on file delete (P2) |
| [#615](https://github.com/stevearc/oil.nvim/issues/615) | open | Cursor at name column on o/O (P2) |
| [#617](https://github.com/stevearc/oil.nvim/issues/617) | open | Filetype by actual filetype (P2) |
| [#621](https://github.com/stevearc/oil.nvim/issues/621) | open | Toggle function for regular windows (P2) |
| [#623](https://github.com/stevearc/oil.nvim/issues/623) | not actionable | bufferline.nvim interaction — cross-plugin |
| [#624](https://github.com/stevearc/oil.nvim/issues/624) | not actionable | Mutation race — no reliable repro |
| [#625](https://github.com/stevearc/oil.nvim/issues/625) | not actionable | E19 mark invalid line — intractable without neovim API changes |
| [#632](https://github.com/stevearc/oil.nvim/issues/632) | fixed | Preview + move = copy — [PR #12](https://github.com/barrettruth/oil.nvim/pull/12) ([`fe16993`](https://github.com/barrettruth/oil.nvim/commit/fe16993)) |
| [#636](https://github.com/stevearc/oil.nvim/issues/636) | open | Telescope picker opens in active buffer |
| [#637](https://github.com/stevearc/oil.nvim/issues/637) | open | Inconsistent symlink resolution |
| [#641](https://github.com/stevearc/oil.nvim/issues/641) | open | Flicker on `actions.parent` |
| [#642](https://github.com/stevearc/oil.nvim/issues/642) | fixed | W10 warning under `nvim -R` — [`ca834cf`](https://github.com/barrettruth/oil.nvim/commit/ca834cf) |
| [#645](https://github.com/stevearc/oil.nvim/issues/645) | resolved | `close_float` action — [`f6bcdda`](https://github.com/barrettruth/oil.nvim/commit/f6bcdda) |
| [#646](https://github.com/stevearc/oil.nvim/issues/646) | open | `get_current_dir` nil on SSH |
| [#650](https://github.com/stevearc/oil.nvim/issues/650) | open | Emit LSP `workspace.fileOperations` events |
| [#655](https://github.com/stevearc/oil.nvim/issues/655) | open | File statistics as virtual text |
| [#659](https://github.com/stevearc/oil.nvim/issues/659) | open | Mark and diff files in buffer |
| [#664](https://github.com/stevearc/oil.nvim/issues/664) | not actionable | Session reload extra buffer — no repro |
| [#665](https://github.com/stevearc/oil.nvim/issues/665) | open | Hot load preview fast-scratch buffers |
| [#668](https://github.com/stevearc/oil.nvim/issues/668) | open | Custom yes/no confirmation |
| [#670](https://github.com/stevearc/oil.nvim/issues/670) | fixed | Multi-directory cmdline — [PR #11](https://github.com/barrettruth/oil.nvim/pull/11) ([`70861e5`](https://github.com/barrettruth/oil.nvim/commit/70861e5)) |
| [#671](https://github.com/stevearc/oil.nvim/issues/671) | open | Yanking between nvim instances |
| [#673](https://github.com/stevearc/oil.nvim/issues/673) | fixed | Symlink newlines crash — [`9110a1a`](https://github.com/barrettruth/oil.nvim/commit/9110a1a) |
| [#675](https://github.com/stevearc/oil.nvim/issues/675) | open | Move file into folder by renaming (related to [#708](https://github.com/stevearc/oil.nvim/pull/708)) |
| [#676](https://github.com/stevearc/oil.nvim/issues/676) | not actionable | Windows — path conversion |
| [#678](https://github.com/stevearc/oil.nvim/issues/678) | tracking | `buftype='acwrite'` causes `mksession` to skip oil windows |
| [#679](https://github.com/stevearc/oil.nvim/issues/679) | resolved | Executable file sign — PR [#698](https://github.com/stevearc/oil.nvim/pull/698) |
| [#682](https://github.com/stevearc/oil.nvim/issues/682) | open | `get_current_dir()` nil in non-telescope context |
| [#683](https://github.com/stevearc/oil.nvim/issues/683) | open | Path not shown in floating mode |
| [#684](https://github.com/stevearc/oil.nvim/issues/684) | open | User and group columns |
| [#685](https://github.com/stevearc/oil.nvim/issues/685) | open | Plain directory paths in buffer names |
| [#690](https://github.com/stevearc/oil.nvim/issues/690) | resolved | `OilFileIcon` highlight group — [`ce64ae1`](https://github.com/barrettruth/oil.nvim/commit/ce64ae1) |
| [#692](https://github.com/stevearc/oil.nvim/issues/692) | resolved | Keymap normalization — PR [#725](https://github.com/stevearc/oil.nvim/pull/725) |
| [#699](https://github.com/stevearc/oil.nvim/issues/699) | open | `select` blocks UI with slow FileType autocmd |
| [#707](https://github.com/stevearc/oil.nvim/issues/707) | open | Move file/dir into new dir by renaming (related to [#708](https://github.com/stevearc/oil.nvim/pull/708)) |
| [#710](https://github.com/stevearc/oil.nvim/issues/710) | fixed | buftype empty on BufEnter — [PR #10](https://github.com/barrettruth/oil.nvim/pull/10) ([`01b860e`](https://github.com/barrettruth/oil.nvim/commit/01b860e)) |
| [#714](https://github.com/stevearc/oil.nvim/issues/714) | not actionable | Support question — answered |
| [#719](https://github.com/stevearc/oil.nvim/issues/719) | not actionable | Neovim crash on node_modules — libuv/neovim bug |
| [#726](https://github.com/stevearc/oil.nvim/issues/726) | not actionable | Meta discussion/roadmap |

</details>

## Requirements

Neovim 0.8+ and optionally [mini.icons](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-icons.md) or [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for file icons.

## Installation

Install with your favorite package manager or with luarocks:

```console
luarocks install oil.nvim
```

## Documentation

```vim
:help oil.nvim
```

## FAQ

**Q: How do I migrate from `stevearc/oil.nvim` to `barrettruth/oil.nvim`?**

Replace your `setup()` call with a `vim.g.oil` assignment. For example, with
[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- before
{
  'stevearc/oil.nvim',
  config = function(_, opts)
    require('oil').setup(opts)
  end,
  opts = {
    ...
  }
}

-- after
{
  'barrettruth/oil.nvim',
  init = function()
    vim.g.oil = {
      columns = { "icon", "size" },
      delete_to_trash = true,
    }
  end,
}
```

**Q: Why "oil"?**

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

**Q: Can oil display files as a tree view?**

**A:** No. A tree view would require a completely different methodology, necessitating a complete rewrite.

**Q: What are some alternatives?**

**A:**

- [the original](https://github.com/stevearc/oil.nvim): the lesser-maintained but
  official `oil.nvim`
- [mini.files](https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-files.md): Also supports cross-directory filesystem-as-buffer edits with a column view.
- [vim-vinegar](https://github.com/tpope/vim-vinegar): The granddaddy of single-directory file browsing.
- [dirbuf.nvim](https://github.com/elihunter173/dirbuf.nvim): Edit filesystem like a buffer, but no cross-directory edits.
- [lir.nvim](https://github.com/tamago324/lir.nvim): Similar to vim-vinegar with better Neovim integration.
- [vim-dirvish](https://github.com/justinmk/vim-dirvish): Stable, simple directory browser.
