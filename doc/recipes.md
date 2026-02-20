# Recipes

Have a cool recipe to share? Open a pull request and add it to this doc!

<!-- TOC -->

- [Toggle file detail view](#toggle-file-detail-view)
- [Show CWD in the winbar](#show-cwd-in-the-winbar)
- [Hide gitignored files and show git tracked hidden files](#hide-gitignored-files-and-show-git-tracked-hidden-files)
- [Open Telescope file finder in the current oil directory](#open-telescope-file-finder-in-the-current-oil-directory)
- [Add custom column for file extension](#add-custom-column-for-file-extension)

<!-- /TOC -->

## Toggle file detail view

```lua
local detail = false
require("oil").setup({
  keymaps = {
    ["gd"] = {
      desc = "Toggle file detail view",
      callback = function()
        detail = not detail
        if detail then
          require("oil").set_columns({ "icon", "permissions", "size", "mtime" })
        else
          require("oil").set_columns({ "icon" })
        end
      end,
    },
  },
})
```

## Show CWD in the winbar

```lua
-- Declare a global function to retrieve the current directory
function _G.get_oil_winbar()
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid)
  local dir = require("oil").get_current_dir(bufnr)
  if dir then
    return vim.fn.fnamemodify(dir, ":~")
  else
    -- If there is no current directory (e.g. over ssh), just show the buffer name
    return vim.api.nvim_buf_get_name(0)
  end
end

require("oil").setup({
  win_options = {
    winbar = "%!v:lua.get_oil_winbar()",
  },
})
```

## Hide gitignored files and show git tracked hidden files

```lua
-- helper function to parse output
local function parse_output(proc)
  local result = proc:wait()
  local ret = {}
  if result.code == 0 then
    for line in vim.gsplit(result.stdout, "\n", { plain = true, trimempty = true }) do
      -- Remove trailing slash
      line = line:gsub("/$", "")
      ret[line] = true
    end
  end
  return ret
end

-- build git status cache
local function new_git_status()
  return setmetatable({}, {
    __index = function(self, key)
      local ignore_proc = vim.system(
        { "git", "ls-files", "--ignored", "--exclude-standard", "--others", "--directory" },
        {
          cwd = key,
          text = true,
        }
      )
      local tracked_proc = vim.system({ "git", "ls-tree", "HEAD", "--name-only" }, {
        cwd = key,
        text = true,
      })
      local ret = {
        ignored = parse_output(ignore_proc),
        tracked = parse_output(tracked_proc),
      }

      rawset(self, key, ret)
      return ret
    end,
  })
end
local git_status = new_git_status()

-- Clear git status cache on refresh
local refresh = require("oil.actions").refresh
local orig_refresh = refresh.callback
refresh.callback = function(...)
  git_status = new_git_status()
  orig_refresh(...)
end

require("oil").setup({
  view_options = {
    is_hidden_file = function(name, bufnr)
      local dir = require("oil").get_current_dir(bufnr)
      local is_dotfile = vim.startswith(name, ".") and name ~= ".."
      -- if no local directory (e.g. for ssh connections), just hide dotfiles
      if not dir then
        return is_dotfile
      end
      -- dotfiles are considered hidden unless tracked
      if is_dotfile then
        return not git_status[dir].tracked[name]
      else
        -- Check if file is gitignored
        return git_status[dir].ignored[name]
      end
    end,
  },
})
```

## Open Telescope file finder in the current oil directory

When using `get_current_dir()` in a keymap that also opens another plugin's UI (like Telescope), always capture the directory in a local variable **before** the call that changes the buffer context. Passing `get_current_dir()` directly as an argument works because Lua evaluates arguments before calling the function, but any subsequent calls will see the new buffer.

```lua
require("oil").setup({
  keymaps = {
    ["<leader>ff"] = {
      desc = "Find files in the current directory",
      callback = function()
        local dir = require("oil").get_current_dir()
        if not dir then
          vim.notify("Could not get oil directory", vim.log.levels.WARN)
          return
        end
        require("telescope.builtin").find_files({ cwd = dir })
      end,
    },
    ["<leader>fg"] = {
      desc = "Live grep in the current directory",
      callback = function()
        local dir = require("oil").get_current_dir()
        if not dir then
          vim.notify("Could not get oil directory", vim.log.levels.WARN)
          return
        end
        require("telescope.builtin").live_grep({ cwd = dir })
      end,
    },
  },
})
```

If you need the directory after an operation that might change the current buffer, pass the buffer number explicitly:

```lua
local bufnr = vim.api.nvim_get_current_buf()
-- ... some operation that changes the current buffer ...
local dir = require("oil").get_current_dir(bufnr)
```

## Add custom column for file extension

```lua
local oil_cfg = require "oil.config"
local oil_constant = require "oil.constants"
local oil_column = require "oil.columns"

local FIELD_TYPE = oil_constant.FIELD_TYPE
local FIELD_NAME = oil_constant.FIELD_NAME

local function adjust_number(int)
  return string.format("%03d%s", #int, int)
end

local function format(output)
  return vim.fn.fnamemodify(output, ":e")
end

oil_column.register("extension", {
  render = function(entry, _)
    local field_type = entry[FIELD_TYPE]
    local name = entry[FIELD_NAME]

    if field_type == "file" then
      if name then
        local extension = format(name)

        if not extension:match "%s" then
          return extension
        end
      end
    end
  end,
  parse = function(line, _)
    return line:match "^(%S+)%s+(.*)$"
  end,
  create_sort_value_factory = function(num_entries)
    if
      oil_cfg.view_options.natural_order == false
      or (oil_cfg.view_options.natural_order == "fast" and num_entries > 5000)
    then
      return function(entry)
        return format(entry[FIELD_NAME]:lower())
      end
    else
      local memo = {}

      return function(entry)
        if memo[entry] == nil and entry[FIELD_TYPE] == "file" then
          local name = entry[FIELD_NAME]:gsub("0*(%d+)", adjust_number)

          memo[entry] = format(name:lower())
        end

        return memo[entry]
      end
    end
  end,
})

require("oil").setup({
  columns = {
    "size",
    "extension",
    "icon",
  },
  view_options = {
    sort = {
      { "type", "asc" },
      { "extension", "asc" },
      { "name", "asc" },
    },
  },
})
```
