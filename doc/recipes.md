# Recipes

Have a cool recipe to share? Open a pull request and add it to this doc!

<!-- TOC -->

- [Toggle file detail view](#toggle-file-detail-view)
- [Hide gitignored files](#hide-gitignored-files)
- [Enable compact directories](#enable-compact-directories)

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

## Hide gitignored files

```lua
local git_ignored = setmetatable({}, {
  __index = function(self, key)
    local proc = vim.system(
      { "git", "ls-files", "--ignored", "--exclude-standard", "--others", "--directory" },
      {
        cwd = key,
        text = true,
      }
    )
    local result = proc:wait()
    local ret = {}
    if result.code == 0 then
      for line in vim.gsplit(result.stdout, "\n", { plain = true, trimempty = true }) do
        -- Remove trailing slash
        line = line:gsub("/$", "")
        table.insert(ret, line)
      end
    end

    rawset(self, key, ret)
    return ret
  end,
})

require("oil").setup({
  view_options = {
    is_hidden_file = function(name, _)
      -- dotfiles are always considered hidden
      if vim.startswith(name, ".") then
        return true
      end
      local dir = require("oil").get_current_dir()
      -- if no local directory (e.g. for ssh connections), always show
      if not dir then
        return false
      end
      -- Check if file is gitignored
      return vim.list_contains(git_ignored[dir], name)
    end,
  },
})
```

## Enable compact directories

```lua
require("oil").setup({
    keymaps = {
        ["oo"] = {
            desc = "Recursively Open directores",
            callback = function()

                local oil = require("oil")
                local dir = oil.get_current_dir()
                local cursor = oil.get_cursor_entry()

                local function o()
                    oil.open(dir .. cursor.name)
                    vim.wait(50)

                    dir = oil.get_current_dir()
                    cursor = oil.get_cursor_entry()

                    local bn = vim.fn.bufnr()
                    local lines = vim.api.nvim_buf_line_count(bn)

                    if lines == 1 and cursor ~= nil and cursor.type == "directory" then
                        o()
                    end
                end

                o()
            end,
        },
    },
})
```
