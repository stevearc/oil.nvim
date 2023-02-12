local default_config = {
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
  },
}

-- The adapter API hasn't really stabilized yet. We're not ready to advertise or encourage people to
-- write their own adapters, and so there's no real reason to edit these config options. For that
-- reason, I'm taking them out of the section above so they won't show up in the autogen docs.
default_config.adapters = {
  ["oil://"] = "files",
  ["oil-ssh://"] = "ssh",
}
default_config.adapter_aliases = {}

local M = {}

M.setup = function(opts)
  local new_conf = vim.tbl_deep_extend("keep", opts or {}, default_config)
  if not new_conf.use_default_keymaps then
    new_conf.keymaps = opts.keymaps or {}
  end

  for k, v in pairs(new_conf) do
    M[k] = v
  end

  M.adapter_to_scheme = {}
  for k, v in pairs(M.adapters) do
    M.adapter_to_scheme[v] = k
  end
  M._adapter_by_scheme = {}
  if type(M.trash) == "string" then
    M.trash = vim.fn.fnamemodify(vim.fn.expand(M.trash), ":p")
  end
end

---@return nil|string
M.get_trash_url = function()
  if not M.trash then
    return nil
  end
  local fs = require("oil.fs")
  if M.trash == true then
    local data_home = os.getenv("XDG_DATA_HOME") or vim.fn.expand("~/.local/share")
    local preferred = fs.join(data_home, "trash")
    local candidates = {
      preferred,
    }
    if fs.is_windows then
      -- TODO permission issues when using the recycle bin. The folder gets created without
      -- read/write perms, so all operations fail
      -- local cwd = vim.fn.getcwd()
      -- table.insert(candidates, 1, cwd:sub(1, 3) .. "$Recycle.Bin")
      -- table.insert(candidates, 1, "C:\\$Recycle.Bin")
    else
      table.insert(candidates, fs.join(data_home, "Trash", "files"))
      table.insert(candidates, fs.join(os.getenv("HOME"), ".Trash"))
    end
    local trash_dir = preferred
    for _, candidate in ipairs(candidates) do
      if vim.fn.isdirectory(candidate) == 1 then
        trash_dir = candidate
        break
      end
    end

    local oil_trash_dir = vim.fn.fnamemodify(fs.join(trash_dir, "nvim", "oil"), ":p")
    fs.mkdirp(oil_trash_dir)
    M.trash = oil_trash_dir
  end
  return M.adapter_to_scheme.files .. fs.os_to_posix_path(M.trash)
end

---@param scheme string
---@return nil|oil.Adapter
M.get_adapter_by_scheme = function(scheme)
  if not vim.endswith(scheme, "://") then
    local pieces = vim.split(scheme, "://", { plain = true })
    if #pieces <= 2 then
      scheme = pieces[1] .. "://"
    else
      error(string.format("Malformed url: '%s'", scheme))
    end
  end
  local adapter = M._adapter_by_scheme[scheme]
  if adapter == nil then
    local name = M.adapters[scheme]
    if not name then
      vim.notify(
        string.format("Could not find oil adapter for scheme '%s'", scheme),
        vim.log.levels.ERROR
      )
      return nil
    end
    local ok
    ok, adapter = pcall(require, string.format("oil.adapters.%s", name))
    if ok then
      adapter.name = name
      M._adapter_by_scheme[scheme] = adapter
    else
      M._adapter_by_scheme[scheme] = false
      adapter = false
      vim.notify(string.format("Could not find oil adapter '%s'", name), vim.log.levels.ERROR)
    end
  end
  if adapter then
    return adapter
  else
    return nil
  end
end

return M
