local oil = require("oil")
local util = require("oil.util")

local M = {}

M.show_help = {
  callback = function()
    local config = require("oil.config")
    require("oil.keymap_util").show_help(config.keymaps)
  end,
  desc = "Show default keymaps",
}

M.select = {
  desc = "Open the entry under the cursor",
  callback = function(opts)
    opts = opts or {}
    local callback = opts.callback
    opts.callback = nil
    oil.select(opts, callback)
  end,
  parameters = {
    vertical = {
      type = "boolean",
      desc = "Open the buffer in a vertical split",
    },
    horizontal = {
      type = "boolean",
      desc = "Open the buffer in a horizontal split",
    },
    split = {
      type = '"aboveleft"|"belowright"|"topleft"|"botright"',
      desc = "Split modifier",
    },
    tab = {
      type = "boolean",
      desc = "Open the buffer in a new tab",
    },
    close = {
      type = "boolean",
      desc = "Close the original oil buffer once selection is made",
    },
  },
}

M.select_vsplit = {
  desc = "Open the entry under the cursor in a vertical split",
  deprecated = true,
  callback = function()
    oil.select({ vertical = true })
  end,
}

M.select_split = {
  desc = "Open the entry under the cursor in a horizontal split",
  deprecated = true,
  callback = function()
    oil.select({ horizontal = true })
  end,
}

M.select_tab = {
  desc = "Open the entry under the cursor in a new tab",
  deprecated = true,
  callback = function()
    oil.select({ tab = true })
  end,
}

M.preview = {
  desc = "Open the entry under the cursor in a preview window, or close the preview window if already open",
  parameters = {
    vertical = {
      type = "boolean",
      desc = "Open the buffer in a vertical split",
    },
    horizontal = {
      type = "boolean",
      desc = "Open the buffer in a horizontal split",
    },
    split = {
      type = '"aboveleft"|"belowright"|"topleft"|"botright"',
      desc = "Split modifier",
    },
  },
  callback = function(opts)
    local entry = oil.get_cursor_entry()
    if not entry then
      vim.notify("Could not find entry under cursor", vim.log.levels.ERROR)
      return
    end
    local winid = util.get_preview_win()
    if winid then
      local cur_id = vim.w[winid].oil_entry_id
      if entry.id == cur_id then
        vim.api.nvim_win_close(winid, true)
        if util.is_floating_win() then
          local layout = require("oil.layout")
          local win_opts = layout.get_fullscreen_win_opts()
          vim.api.nvim_win_set_config(0, win_opts)
        end
        return
      end
    end
    oil.open_preview(opts)
  end,
}

M.preview_scroll_down = {
  desc = "Scroll down in the preview window",
  callback = function()
    local winid = util.get_preview_win()
    if winid then
      vim.api.nvim_win_call(winid, function()
        vim.cmd.normal({
          args = { vim.api.nvim_replace_termcodes("<C-d>", true, true, true) },
          bang = true,
        })
      end)
    end
  end,
}

M.preview_scroll_up = {
  desc = "Scroll up in the preview window",
  callback = function()
    local winid = util.get_preview_win()
    if winid then
      vim.api.nvim_win_call(winid, function()
        vim.cmd.normal({
          args = { vim.api.nvim_replace_termcodes("<C-u>", true, true, true) },
          bang = true,
        })
      end)
    end
  end,
}

M.parent = {
  desc = "Navigate to the parent path",
  callback = oil.open,
}

M.close = {
  desc = "Close oil and restore original buffer",
  callback = function(opts)
    opts = opts or {}
    oil.close(opts)
  end,
  parameters = {
    exit_if_last_buf = {
      type = "boolean",
      desc = "Exit vim if oil is closed as the last buffer",
    },
  },
}

---@param cmd string
---@param silent? boolean
local function cd(cmd, silent)
  local dir = oil.get_current_dir()
  if dir then
    vim.cmd({ cmd = cmd, args = { dir } })
    if not silent then
      vim.notify(string.format("CWD: %s", dir), vim.log.levels.INFO)
    end
  else
    vim.notify("Cannot :cd; not in a directory", vim.log.levels.WARN)
  end
end

M.cd = {
  desc = ":cd to the current oil directory",
  callback = function(opts)
    opts = opts or {}
    local cmd = "cd"
    if opts.scope == "tab" then
      cmd = "tcd"
    elseif opts.scope == "win" then
      cmd = "lcd"
    end
    cd(cmd, opts.silent)
  end,
  parameters = {
    scope = {
      type = 'nil|"tab"|"win"',
      desc = "Scope of the directory change (e.g. use |:tcd| or |:lcd|)",
    },
    silent = {
      type = "boolean",
      desc = "Do not show a message when changing directories",
    },
  },
}

M.tcd = {
  desc = ":tcd to the current oil directory",
  deprecated = true,
  callback = function()
    cd("tcd")
  end,
}

M.open_cwd = {
  desc = "Open oil in Neovim's current working directory",
  callback = function()
    oil.open(vim.fn.getcwd())
  end,
}

M.toggle_hidden = {
  desc = "Toggle hidden files and directories",
  callback = function()
    require("oil.view").toggle_hidden()
  end,
}

M.open_terminal = {
  desc = "Open a terminal in the current directory",
  callback = function()
    local config = require("oil.config")
    local bufname = vim.api.nvim_buf_get_name(0)
    local adapter = config.get_adapter_by_scheme(bufname)
    if not adapter then
      return
    end
    if adapter.name == "files" then
      local dir = oil.get_current_dir()
      assert(dir, "Oil buffer with files adapter must have current directory")
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
      vim.fn.termopen(vim.o.shell, { cwd = dir })
    elseif adapter.name == "ssh" then
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
      local url = require("oil.adapters.ssh").parse_url(bufname)
      local cmd = require("oil.adapters.ssh.connection").create_ssh_command(url)
      local term_id = vim.fn.termopen(cmd)
      if term_id then
        vim.api.nvim_chan_send(term_id, string.format("cd %s\n", url.path))
      end
    else
      vim.notify(
        string.format("Cannot open terminal for unsupported adapter: '%s'", adapter.name),
        vim.log.levels.WARN
      )
    end
  end,
}

---Copied from vim.ui.open in Neovim 0.10+
---@param path string
---@return nil|string[] cmd
---@return nil|string error
local function get_open_cmd(path)
  if vim.fn.has("mac") == 1 then
    return { "open", path }
  elseif vim.fn.has("win32") == 1 then
    if vim.fn.executable("rundll32") == 1 then
      return { "rundll32", "url.dll,FileProtocolHandler", path }
    else
      return nil, "rundll32 not found"
    end
  elseif vim.fn.executable("explorer.exe") == 1 then
    return { "explorer.exe", path }
  elseif vim.fn.executable("xdg-open") == 1 then
    return { "xdg-open", path }
  else
    return nil, "no handler found"
  end
end

M.open_external = {
  desc = "Open the entry under the cursor in an external program",
  callback = function()
    local entry = oil.get_cursor_entry()
    local dir = oil.get_current_dir()
    if not entry or not dir then
      return
    end
    local path = dir .. entry.name

    if vim.ui.open then
      vim.ui.open(path)
      return
    end

    local cmd, err = get_open_cmd(path)
    if not cmd then
      vim.notify(string.format("Could not open %s: %s", path, err), vim.log.levels.ERROR)
      return
    end
    local jid = vim.fn.jobstart(cmd, { detach = true })
    assert(jid > 0, "Failed to start job")
  end,
}

M.refresh = {
  desc = "Refresh current directory list",
  callback = function(opts)
    opts = opts or {}
    if vim.bo.modified and not opts.force then
      local ok, choice = pcall(vim.fn.confirm, "Discard changes?", "No\nYes")
      if not ok or choice ~= 2 then
        return
      end
    end
    vim.cmd.edit({ bang = true })

    -- :h CTRL-L-default
    vim.cmd.nohlsearch()
  end,
  parameters = {
    force = {
      desc = "When true, do not prompt user if they will be discarding changes",
      type = "boolean",
    },
  },
}

local function open_cmdline_with_path(path)
  local escaped =
    vim.api.nvim_replace_termcodes(": " .. vim.fn.fnameescape(path) .. "<Home>", true, false, true)
  vim.api.nvim_feedkeys(escaped, "n", false)
end

M.open_cmdline = {
  desc = "Open vim cmdline with current entry as an argument",
  callback = function(opts)
    opts = vim.tbl_deep_extend("keep", opts or {}, {
      shorten_path = true,
    })
    local config = require("oil.config")
    local fs = require("oil.fs")
    local entry = oil.get_cursor_entry()
    if not entry then
      return
    end
    local bufname = vim.api.nvim_buf_get_name(0)
    local scheme, path = util.parse_url(bufname)
    if not scheme then
      return
    end
    local adapter = config.get_adapter_by_scheme(scheme)
    if not adapter or not path or adapter.name ~= "files" then
      return
    end
    local fullpath = fs.posix_to_os_path(path) .. entry.name
    if opts.modify then
      fullpath = vim.fn.fnamemodify(fullpath, opts.modify)
    end
    if opts.shorten_path then
      fullpath = fs.shorten_path(fullpath)
    end
    open_cmdline_with_path(fullpath)
  end,
  parameters = {
    modify = {
      desc = "Modify the path with |fnamemodify()| using this as the mods argument",
      type = "string",
    },
    shorten_path = {
      desc = "Use relative paths when possible",
      type = "boolean",
    },
  },
}

M.yank_entry = {
  desc = "Yank the filepath of the entry under the cursor to a register",
  callback = function(opts)
    opts = opts or {}
    local entry = oil.get_cursor_entry()
    local dir = oil.get_current_dir()
    if not entry or not dir then
      return
    end
    local name = entry.name
    if entry.type == "directory" then
      name = name .. "/"
    end
    local path = dir .. name
    if opts.modify then
      path = vim.fn.fnamemodify(path, opts.modify)
    end
    vim.fn.setreg(vim.v.register, path)
  end,
  parameters = {
    modify = {
      desc = "Modify the path with |fnamemodify()| using this as the mods argument",
      type = "string",
    },
  },
}

M.copy_entry_path = {
  desc = "Yank the filepath of the entry under the cursor to a register",
  deprecated = true,
  callback = function()
    local entry = oil.get_cursor_entry()
    local dir = oil.get_current_dir()
    if not entry or not dir then
      return
    end
    vim.fn.setreg(vim.v.register, dir .. entry.name)
  end,
}

M.copy_entry_filename = {
  desc = "Yank the filename of the entry under the cursor to a register",
  deprecated = true,
  callback = function()
    local entry = oil.get_cursor_entry()
    if not entry then
      return
    end
    vim.fn.setreg(vim.v.register, entry.name)
  end,
}

M.copy_to_system_clipboard = {
  desc = "Copy the entry under the cursor to the system clipboard",
  callback = function()
    local fs = require("oil.fs")
    local dir = oil.get_current_dir()
    local entry = oil.get_cursor_entry()
    if not dir or not entry then
      return
    end
    local path = dir .. entry.name
    local cmd
    if fs.is_mac then
      cmd =
        "osascript -e 'on run args' -e 'set the clipboard to POSIX file (first item of args)' -e end '%s'"
    elseif fs.is_linux then
      cmd = "echo -en '%s\\n' | xclip -i -selection clipboard -t text/uri-list"
    else
      cmd = "exit 1"
    end

    local jid = vim.fn.jobstart(string.format(cmd, path), {
      on_exit = function(j, exit_code)
        if exit_code ~= 0 then
          vim.schedule(function()
            if fs.is_windows then
              vim.notify("System clipboard not supported on this platform", vim.log.levels.WARN)
            else
              vim.notify(
                string.format("Error copying '%s' to system clipboard", path),
                vim.log.levels.ERROR
              )
            end
          end)
        end
      end,
    })
    assert(jid > 0, "Failed to start job")
  end,
}

M.paste_from_system_clipboard = {
  desc = "Paste the system clipboard into the current oil directory",
  callback = function()
    local fs = require("oil.fs")
    local view = require("oil.view")
    local cache = require("oil.cache")
    local config = require("oil.config")
    local columns = require("oil.columns")
    local constants = require("oil.constants")
    local dir = oil.get_current_dir()
    if not dir then
      return
    end
    local cmd, path
    if fs.is_mac then
      cmd = "osascript -e 'on run' -e 'POSIX path of (the clipboard as «class furl»)' -e end"
    elseif fs.is_linux then
      cmd = "xclip -o -selection clipboard -t text/uri-list"
    else
      cmd = "exit 1"
    end
    local write_pasted = function(entry, column_defs, adapter, bufnr)
      local col_width = {}
      for i in ipairs(column_defs) do
        col_width[i + 1] = 1
      end
      local line_table =
        { view.format_entry_cols(entry, column_defs, col_width, adapter, false, bufnr) }
      local lines, _ = util.render_table(line_table, col_width)
      local pos = vim.api.nvim_win_get_cursor(0)
      vim.api.nvim_buf_set_lines(0, pos[1], pos[1], true, lines)
    end

    local jid = vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(j, output)
        if #output > 1 then
          path = vim.uv.fs_realpath(output[1]:gsub("^files?://", ""))
        end
      end,
      on_exit = function(j, exit_code)
        if exit_code ~= 0 or path == nil then
          vim.schedule(function()
            if fs.is_windows then
              vim.notify("System clipboard not supported on this platform", vim.log.levels.WARN)
            else
              vim.notify(
                string.format("Error pasting '%s' from system clipboard", path),
                vim.log.levels.ERROR
              )
            end
          end)
          return
        end

        local bufnr = 0
        local scheme = "oil://"
        local parent_url = scheme .. vim.fs.dirname(path)
        local adapter = assert(config.get_adapter_by_scheme(parent_url))
        local column_defs = columns.get_supported_columns(scheme)

        local ori_entry = cache.get_entry_by_url(scheme .. path)
        if ori_entry then
          write_pasted(ori_entry, column_defs, adapter, bufnr)
          return
        end

        cache.begin_update_url(parent_url)
        adapter.list(
          parent_url,
          column_defs,
          vim.schedule_wrap(function(err, entries, fetch_more)
            if err then
              cache.end_update_url(parent_url)
              util.render_text(bufnr, { "Error: " .. err })
              return
            end
            if entries then
              for _, entry in ipairs(entries) do
                cache.store_entry(parent_url, entry)
                if entry[constants.FIELD_NAME] == vim.fs.basename(path) then
                  cache.end_update_url(parent_url)
                  write_pasted(entry, column_defs, adapter, bufnr)
                  return
                end
              end
            end
            if fetch_more then
              vim.defer_fn(fetch_more, 4)
            else
              cache.end_update_url(parent_url)
              vim.notify(
                string.format("The requested file is not found under '%s'", parent_url),
                vim.log.levels.ERROR
              )
            end
          end)
        )
      end,
    })
    assert(jid > 0, "Failed to start job")
  end,
}

M.open_cmdline_dir = {
  desc = "Open vim cmdline with current directory as an argument",
  deprecated = true,
  callback = function()
    local fs = require("oil.fs")
    local dir = oil.get_current_dir()
    if dir then
      open_cmdline_with_path(fs.shorten_path(dir))
    end
  end,
}

M.change_sort = {
  desc = "Change the sort order",
  callback = function(opts)
    opts = opts or {}

    if opts.sort then
      oil.set_sort(opts.sort)
      return
    end

    local sort_cols = { "name", "size", "atime", "mtime", "ctime", "birthtime" }
    vim.ui.select(sort_cols, { prompt = "Sort by", kind = "oil_sort_col" }, function(col)
      if not col then
        return
      end
      vim.ui.select(
        { "ascending", "descending" },
        { prompt = "Sort order", kind = "oil_sort_order" },
        function(order)
          if not order then
            return
          end
          order = order == "ascending" and "asc" or "desc"
          oil.set_sort({
            { "type", "asc" },
            { col, order },
          })
        end
      )
    end)
  end,
  parameters = {
    sort = {
      type = "oil.SortSpec[]",
      desc = "List of columns plus direction (see |oil.set_sort|) instead of interactive selection",
    },
  },
}

M.toggle_trash = {
  desc = "Jump to and from the trash for the current directory",
  callback = function()
    local fs = require("oil.fs")
    local bufname = vim.api.nvim_buf_get_name(0)
    local scheme, path = util.parse_url(bufname)
    local bufnr = vim.api.nvim_get_current_buf()
    local url
    if scheme == "oil://" then
      url = "oil-trash://" .. path
    elseif scheme == "oil-trash://" then
      url = "oil://" .. path
      -- The non-linux trash implementations don't support per-directory trash,
      -- so jump back to the stored source buffer.
      if not fs.is_linux then
        local src_bufnr = vim.b.oil_trash_toggle_src
        if src_bufnr and vim.api.nvim_buf_is_valid(src_bufnr) then
          url = vim.api.nvim_buf_get_name(src_bufnr)
        end
      end
    else
      vim.notify("No trash found for buffer", vim.log.levels.WARN)
      return
    end
    vim.cmd.edit({ args = { url } })
    vim.b.oil_trash_toggle_src = bufnr
  end,
}

M.send_to_qflist = {
  desc = "Sends files in the current oil directory to the quickfix list, replacing the previous entries.",
  callback = function(opts)
    opts = vim.tbl_deep_extend("keep", opts or {}, {
      target = "qflist",
      action = "r",
    })
    util.send_to_quickfix({
      target = opts.target,
      action = opts.action,
    })
  end,
  parameters = {
    target = {
      type = '"qflist"|"loclist"',
      desc = "The target list to send files to",
    },
    action = {
      type = '"r"|"a"',
      desc = "Replace or add to current quickfix list (see |setqflist-action|)",
    },
  },
}

M.add_to_qflist = {
  desc = "Adds files in the current oil directory to the quickfix list, keeping the previous entries.",
  deprecated = true,
  callback = function()
    util.send_to_quickfix({
      target = "qflist",
      mode = "a",
    })
  end,
}

M.send_to_loclist = {
  desc = "Sends files in the current oil directory to the location list, replacing the previous entries.",
  deprecated = true,
  callback = function()
    util.send_to_quickfix({
      target = "loclist",
      mode = "r",
    })
  end,
}

M.add_to_loclist = {
  desc = "Adds files in the current oil directory to the location list, keeping the previous entries.",
  deprecated = true,
  callback = function()
    util.send_to_quickfix({
      target = "loclist",
      mode = "a",
    })
  end,
}

---List actions for documentation generation
---@private
M._get_actions = function()
  local ret = {}
  for name, action in pairs(M) do
    if type(action) == "table" and action.desc then
      table.insert(ret, {
        name = name,
        desc = action.desc,
        deprecated = action.deprecated,
        parameters = action.parameters,
      })
    end
  end
  return ret
end

return M
