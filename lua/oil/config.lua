local default_config = {
  -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
  -- Set to false if you want some other plugin (e.g. netrw) to open when you edit directories.
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
    concealcursor = "nvic",
  },
  -- Send deleted files to the trash instead of permanently deleting them (:help oil-trash)
  delete_to_trash = false,
  -- Skip the confirmation popup for simple operations (:help oil.skip_confirm_for_simple_edits)
  skip_confirm_for_simple_edits = false,
  -- Selecting a new/moved/renamed file or directory will prompt you to save changes first
  -- (:help prompt_save_on_select_new_entry)
  prompt_save_on_select_new_entry = true,
  -- Oil will automatically delete hidden buffers after this delay
  -- You can set the delay to false to disable cleanup entirely
  -- Note that the cleanup process only starts when none of the oil buffers are currently displayed
  cleanup_delay_ms = 2000,
  lsp_file_methods = {
    -- Enable or disable LSP file operations
    enabled = true,
    -- Time to wait for LSP file operations to complete before skipping
    timeout_ms = 1000,
    -- Set to true to autosave buffers that are updated with LSP willRenameFiles
    -- Set to "unmodified" to only save unmodified buffers
    autosave_changes = false,
  },
  -- Constrain the cursor to the editable parts of the oil buffer
  -- Set to `false` to disable, or "name" to keep it on the file names
  constrain_cursor = "editable",
  -- Set to true to watch the filesystem for changes and reload oil
  watch_for_changes = false,
  -- Keymaps in oil buffer. Can be any value that `vim.keymap.set` accepts OR a table of keymap
  -- options with a `callback` (e.g. { callback = function() ... end, desc = "", mode = "n" })
  -- Additionally, if it is a string that matches "actions.<name>",
  -- it will use the mapping at require("oil.actions").<name>
  -- Set to `false` to remove a keymap
  -- See :help oil-actions for a list of all available actions
  keymaps = {
    ["g?"] = { "actions.show_help", mode = "n" },
    ["<CR>"] = "actions.select",
    ["<C-s>"] = { "actions.select", opts = { vertical = true } },
    ["<C-h>"] = { "actions.select", opts = { horizontal = true } },
    ["<C-t>"] = { "actions.select", opts = { tab = true } },
    ["<C-p>"] = "actions.preview",
    ["<C-c>"] = { "actions.close", mode = "n" },
    ["<C-l>"] = "actions.refresh",
    ["-"] = { "actions.parent", mode = "n" },
    ["_"] = { "actions.open_cwd", mode = "n" },
    ["`"] = { "actions.cd", mode = "n" },
    ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
    ["gs"] = { "actions.change_sort", mode = "n" },
    ["gx"] = "actions.open_external",
    ["g."] = { "actions.toggle_hidden", mode = "n" },
    ["g\\"] = { "actions.toggle_trash", mode = "n" },
  },
  -- Set to false to disable all of the above keymaps
  use_default_keymaps = true,
  view_options = {
    -- Show files and directories that start with "."
    show_hidden = false,
    -- This function defines what is considered a "hidden" file
    is_hidden_file = function(name, bufnr)
      local m = name:match("^%.")
      return m ~= nil
    end,
    -- This function defines what will never be shown, even when `show_hidden` is set
    is_always_hidden = function(name, bufnr)
      return false
    end,
    -- Sort file names with numbers in a more intuitive order for humans.
    -- Can be "fast", true, or false. "fast" will turn it off for large directories.
    natural_order = "fast",
    -- Sort file and directory names case insensitive
    case_insensitive = false,
    sort = {
      -- sort order can be "asc" or "desc"
      -- see :help oil-columns to see which columns are sortable
      { "type", "asc" },
      { "name", "asc" },
    },
    -- Customize the highlight group for the file name
    highlight_filename = function(entry, is_hidden, is_link_target, is_link_orphan)
      return nil
    end,
  },
  -- Extra arguments to pass to SCP when moving/copying files over SSH
  extra_scp_args = {},
  -- EXPERIMENTAL support for performing file operations with git
  git = {
    -- Return true to automatically git add/mv/rm files
    add = function(path)
      return false
    end,
    mv = function(src_path, dest_path)
      return false
    end,
    rm = function(path)
      return false
    end,
  },
  -- Configuration for the floating window in oil.open_float
  float = {
    -- Padding around the floating window
    padding = 2,
    -- max_width and max_height can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    max_width = 0,
    max_height = 0,
    border = "rounded",
    win_options = {
      winblend = 0,
    },
    -- optionally override the oil buffers window title with custom function: fun(winid: integer): string
    get_win_title = nil,
    -- preview_split: Split direction: "auto", "left", "right", "above", "below".
    preview_split = "auto",
    -- This is the config that will be passed to nvim_open_win.
    -- Change values here to customize the layout
    override = function(conf)
      return conf
    end,
  },
  -- Configuration for the file preview window
  preview_win = {
    -- Whether the preview window is automatically updated when the cursor is moved
    update_on_cursor_moved = true,
    -- How to open the preview window "load"|"scratch"|"fast_scratch"
    preview_method = "fast_scratch",
    -- A function that returns true to disable preview on a file e.g. to avoid lag
    disable_preview = function(filename)
      return false
    end,
    -- Window-local options to use for preview window buffers
    win_options = {},
  },
  -- Configuration for the floating action confirmation window
  confirmation = {
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
  -- Configuration for the floating SSH window
  ssh = {
    border = "rounded",
  },
  -- Configuration for the floating keymaps help window
  keymaps_help = {
    border = "rounded",
  },
}

-- The adapter API hasn't really stabilized yet. We're not ready to advertise or encourage people to
-- write their own adapters, and so there's no real reason to edit these config options. For that
-- reason, I'm taking them out of the section above so they won't show up in the autogen docs.
default_config.adapters = {
  ["oil://"] = "files",
  ["oil-ssh://"] = "ssh",
  ["oil-trash://"] = "trash",
}
default_config.adapter_aliases = {}
-- We want the function in the default config for documentation generation, but if we nil it out
-- here we can get some performance wins
default_config.view_options.highlight_filename = nil

---@class oil.Config
---@field adapters table<string, string> Hidden from SetupOpts
---@field adapter_aliases table<string, string> Hidden from SetupOpts
---@field trash_command? string Deprecated option that we should clean up soon
---@field silence_scp_warning? boolean Undocumented option
---@field default_file_explorer boolean
---@field columns oil.ColumnSpec[]
---@field buf_options table<string, any>
---@field win_options table<string, any>
---@field delete_to_trash boolean
---@field skip_confirm_for_simple_edits boolean
---@field prompt_save_on_select_new_entry boolean
---@field cleanup_delay_ms integer
---@field lsp_file_methods oil.LspFileMethods
---@field constrain_cursor false|"name"|"editable"
---@field watch_for_changes boolean
---@field keymaps table<string, any>
---@field use_default_keymaps boolean
---@field view_options oil.ViewOptions
---@field extra_scp_args string[]
---@field git oil.GitOptions
---@field float oil.FloatWindowConfig
---@field preview_win oil.PreviewWindowConfig
---@field confirmation oil.ConfirmationWindowConfig
---@field progress oil.ProgressWindowConfig
---@field ssh oil.SimpleWindowConfig
---@field keymaps_help oil.SimpleWindowConfig
local M = {}

-- For backwards compatibility
---@alias oil.setupOpts oil.SetupOpts

---@class (exact) oil.SetupOpts
---@field default_file_explorer? boolean Oil will take over directory buffers (e.g. `vim .` or `:e src/`). Set to false if you still want to use netrw.
---@field columns? oil.ColumnSpec[] The columns to display. See :help oil-columns.
---@field buf_options? table<string, any> Buffer-local options to use for oil buffers
---@field win_options? table<string, any> Window-local options to use for oil buffers
---@field delete_to_trash? boolean Send deleted files to the trash instead of permanently deleting them (:help oil-trash).
---@field skip_confirm_for_simple_edits? boolean Skip the confirmation popup for simple operations (:help oil.skip_confirm_for_simple_edits).
---@field prompt_save_on_select_new_entry? boolean Selecting a new/moved/renamed file or directory will prompt you to save changes first (:help prompt_save_on_select_new_entry).
---@field cleanup_delay_ms? integer Oil will automatically delete hidden buffers after this delay. You can set the delay to false to disable cleanup entirely. Note that the cleanup process only starts when none of the oil buffers are currently displayed.
---@field lsp_file_methods? oil.SetupLspFileMethods Configure LSP file operation integration.
---@field constrain_cursor? false|"name"|"editable" Constrain the cursor to the editable parts of the oil buffer. Set to `false` to disable, or "name" to keep it on the file names.
---@field watch_for_changes? boolean Set to true to watch the filesystem for changes and reload oil.
---@field keymaps? table<string, any>
---@field use_default_keymaps? boolean Set to false to disable all of the above keymaps
---@field view_options? oil.SetupViewOptions Configure which files are shown and how they are shown.
---@field extra_scp_args? string[] Extra arguments to pass to SCP when moving/copying files over SSH
---@field git? oil.SetupGitOptions EXPERIMENTAL support for performing file operations with git
---@field float? oil.SetupFloatWindowConfig Configuration for the floating window in oil.open_float
---@field preview_win? oil.SetupPreviewWindowConfig Configuration for the file preview window
---@field confirmation? oil.SetupConfirmationWindowConfig Configuration for the floating action confirmation window
---@field progress? oil.SetupProgressWindowConfig Configuration for the floating progress window
---@field ssh? oil.SetupSimpleWindowConfig Configuration for the floating SSH window
---@field keymaps_help? oil.SetupSimpleWindowConfig Configuration for the floating keymaps help window

---@class (exact) oil.LspFileMethods
---@field enabled boolean
---@field timeout_ms integer
---@field autosave_changes boolean|"unmodified" Set to true to autosave buffers that are updated with LSP willRenameFiles. Set to "unmodified" to only save unmodified buffers.

---@class (exact) oil.SetupLspFileMethods
---@field enabled? boolean Enable or disable LSP file operations
---@field timeout_ms? integer Time to wait for LSP file operations to complete before skipping.
---@field autosave_changes? boolean|"unmodified" Set to true to autosave buffers that are updated with LSP willRenameFiles. Set to "unmodified" to only save unmodified buffers.

---@class (exact) oil.ViewOptions
---@field show_hidden boolean
---@field is_hidden_file fun(name: string, bufnr: integer): boolean
---@field is_always_hidden fun(name: string, bufnr: integer): boolean
---@field natural_order boolean|"fast"
---@field case_insensitive boolean
---@field sort oil.SortSpec[]
---@field highlight_filename? fun(entry: oil.Entry, is_hidden: boolean, is_link_target: boolean, is_link_orphan: boolean, bufnr: integer): string|nil

---@class (exact) oil.SetupViewOptions
---@field show_hidden? boolean Show files and directories that start with "."
---@field is_hidden_file? fun(name: string, bufnr: integer): boolean This function defines what is considered a "hidden" file
---@field is_always_hidden? fun(name: string, bufnr: integer): boolean This function defines what will never be shown, even when `show_hidden` is set
---@field natural_order? boolean|"fast" Sort file names with numbers in a more intuitive order for humans. Can be slow for large directories.
---@field case_insensitive? boolean Sort file and directory names case insensitive
---@field sort? oil.SortSpec[] Sort order for the file list
---@field highlight_filename? fun(entry: oil.Entry, is_hidden: boolean, is_link_target: boolean, is_link_orphan: boolean): string|nil Customize the highlight group for the file name

---@class (exact) oil.SortSpec
---@field [1] string
---@field [2] "asc"|"desc"

---@class (exact) oil.GitOptions
---@field add fun(path: string): boolean
---@field mv fun(src_path: string, dest_path: string): boolean
---@field rm fun(path: string): boolean

---@class (exact) oil.SetupGitOptions
---@field add? fun(path: string): boolean Return true to automatically git add a new file
---@field mv? fun(src_path: string, dest_path: string): boolean Return true to automatically git mv a moved file
---@field rm? fun(path: string): boolean Return true to automatically git rm a deleted file

---@class (exact) oil.WindowDimensionDualConstraint
---@field [1] number
---@field [2] number

---@alias oil.WindowDimension number|oil.WindowDimensionDualConstraint

---@class (exact) oil.WindowConfig
---@field max_width oil.WindowDimension
---@field min_width oil.WindowDimension
---@field width? number
---@field max_height oil.WindowDimension
---@field min_height oil.WindowDimension
---@field height? number
---@field border string|string[]
---@field win_options table<string, any>

---@class (exact) oil.SetupWindowConfig
---@field max_width? oil.WindowDimension Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%). Can be a single value or a list of mixed integer/float types. max_width = {100, 0.8} means "the lesser of 100 columns or 80% of total"
---@field min_width? oil.WindowDimension Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%). Can be a single value or a list of mixed integer/float types. min_width = {40, 0.4} means "the greater of 40 columns or 40% of total"
---@field width? number Define an integer/float for the exact width of the preview window
---@field max_height? oil.WindowDimension Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%). Can be a single value or a list of mixed integer/float types. max_height = {80, 0.9} means "the lesser of 80 columns or 90% of total"
---@field min_height? oil.WindowDimension Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%). Can be a single value or a list of mixed integer/float types. min_height = {5, 0.1} means "the greater of 5 columns or 10% of total"
---@field height? number Define an integer/float for the exact height of the preview window
---@field border? string|string[] Window border
---@field win_options? table<string, any>

---@alias oil.PreviewMethod
---| '"load"' # Load the previewed file into a buffer
---| '"scratch"' # Put the text into a scratch buffer to avoid LSP attaching
---| '"fast_scratch"' # Put only the visible text into a scratch buffer

---@class (exact) oil.PreviewWindowConfig
---@field update_on_cursor_moved boolean
---@field preview_method oil.PreviewMethod
---@field disable_preview fun(filename: string): boolean
---@field win_options table<string, any>

---@class (exact) oil.ConfirmationWindowConfig : oil.WindowConfig

---@class (exact) oil.SetupPreviewWindowConfig
---@field update_on_cursor_moved? boolean Whether the preview window is automatically updated when the cursor is moved
---@field disable_preview? fun(filename: string): boolean A function that returns true to disable preview on a file e.g. to avoid lag
---@field preview_method? oil.PreviewMethod How to open the preview window
---@field win_options? table<string, any> Window-local options to use for preview window buffers

---@class (exact) oil.SetupConfirmationWindowConfig : oil.SetupWindowConfig

---@class (exact) oil.ProgressWindowConfig : oil.WindowConfig
---@field minimized_border string|string[]

---@class (exact) oil.SetupProgressWindowConfig : oil.SetupWindowConfig
---@field minimized_border? string|string[] The border for the minimized progress window

---@class (exact) oil.FloatWindowConfig
---@field padding integer
---@field max_width integer
---@field max_height integer
---@field border string|string[]
---@field win_options table<string, any>
---@field get_win_title fun(winid: integer): string
---@field preview_split "auto"|"left"|"right"|"above"|"below"
---@field override fun(conf: table): table

---@class (exact) oil.SetupFloatWindowConfig
---@field padding? integer
---@field max_width? integer
---@field max_height? integer
---@field border? string|string[] Window border
---@field win_options? table<string, any>
---@field get_win_title? fun(winid: integer): string
---@field preview_split? "auto"|"left"|"right"|"above"|"below" Direction that the preview command will split the window
---@field override? fun(conf: table): table

---@class (exact) oil.SimpleWindowConfig
---@field border string|string[]

---@class (exact) oil.SetupSimpleWindowConfig
---@field border? string|string[] Window border

M.setup = function(opts)
  opts = opts or {}

  if opts.trash_command then
    vim.notify(
      "[oil.nvim] trash_command is deprecated. Use built-in trash functionality instead (:help oil-trash).\nCompatibility will be removed on 2025-06-01.",
      vim.log.levels.WARN
    )
  end

  local new_conf = vim.tbl_deep_extend("keep", opts, default_config)
  if not new_conf.use_default_keymaps then
    new_conf.keymaps = opts.keymaps or {}
  elseif opts.keymaps then
    -- We don't want to deep merge the keymaps, we want any keymap defined by the user to override
    -- everything about the default.
    for k, v in pairs(opts.keymaps) do
      new_conf.keymaps[k] = v
    end
  end

  -- Backwards compatibility. We renamed the 'preview' window config to be called 'confirmation'.
  if opts.preview and not opts.confirmation then
    new_conf.confirmation = vim.tbl_deep_extend("keep", opts.preview, default_config.confirmation)
  end
  -- Backwards compatibility. We renamed the 'preview' config to 'preview_win'
  if opts.preview and opts.preview.update_on_cursor_moved ~= nil then
    new_conf.preview_win.update_on_cursor_moved = opts.preview.update_on_cursor_moved
  end

  if new_conf.lsp_rename_autosave ~= nil then
    new_conf.lsp_file_methods.autosave_changes = new_conf.lsp_rename_autosave
    new_conf.lsp_rename_autosave = nil
    vim.notify_once(
      "oil config value lsp_rename_autosave has moved to lsp_file_methods.autosave_changes.\nCompatibility will be removed on 2024-09-01.",
      vim.log.levels.WARN
    )
  end

  -- This option was renamed because it is no longer experimental
  if new_conf.experimental_watch_for_changes then
    new_conf.watch_for_changes = true
  end

  for k, v in pairs(new_conf) do
    M[k] = v
  end

  M.adapter_to_scheme = {}
  for k, v in pairs(M.adapters) do
    M.adapter_to_scheme[v] = k
  end
  M._adapter_by_scheme = {}
end

---@param scheme nil|string
---@return nil|oil.Adapter
M.get_adapter_by_scheme = function(scheme)
  if not scheme then
    return nil
  end
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
    end
  end
  if adapter then
    return adapter
  else
    return nil
  end
end

return M
