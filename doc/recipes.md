# Recipes

Have a cool recipe to share? Open a pull request and add it to this doc!

<!-- TOC -->

- [Toggle file detail view](#toggle-file-detail-view)
- [Show CWD in the winbar](#show-cwd-in-the-winbar)
- [Hide gitignored files and show git tracked hidden files](#hide-gitignored-files-and-show-git-tracked-hidden-files)
- [Use oil as a persistent file explorer](#use-oil-as-a-persistent-file-explorer)

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

## Use oil as a persistent file explorer
Two separate windows: one for oil and another for editing. Once toggled, new buffers loading into the editing window cause the cwd shown by oil to be refreshed. Any new files opened via the oil window/buffer are opened in the editing window.

```lua
---@class OilFileEx
local OilFileEx = {}

---@return string
local function get_current_parent_dir()
  return vim.fn.expand('%:p:h')
end

local function is_oil_buffer(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    return string.find(bufname, "^oil")
  end
end

local function open_oil_parent_dir()
  local dir = get_current_parent_dir()
  require "oil".open(dir)
end

-- Opens the filetree to the left of the current window
-- and sets up an autocmd for reloading filetree on the buffer
-- in the code window changing
function OilFileEx:up()
  self.code_winnr = vim.api.nvim_get_current_win()
  self.code_bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("OilFileTreeCodeWindow", { clear = true }),
    callback = function(_)
      if not vim.api.nvim_win_is_valid(self.code_winnr) or self.killed then
        return
      end

      local bufnr = vim.api.nvim_win_get_buf(self.code_winnr)
      if bufnr ~= self.code_bufnr and not is_oil_buffer(bufnr) then
        self.code_bufnr = bufnr
        self:reload()
      end
    end
  })
  self:load()
end

function OilFileEx:load()
  vim.cmd("40vs") -- specify width of vertically split window that contains oil
  open_oil_parent_dir()
  self.oil_bufnr = vim.api.nvim_get_current_buf()
  self.oil_winnr = vim.api.nvim_get_current_win()

  -- Divert buffers that are opened from the oil window via oil to the main code
  -- window.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("OilFileTreeOilWindow", { clear = true }),
    callback = function(_)
      if not vim.api.nvim_win_is_valid(self.oil_winnr) then
        return
      end

      local bufnr = vim.api.nvim_win_get_buf(self.oil_winnr)
      if bufnr ~= self.oil_bufnr then
        -- reload oil if anything but an oil buffer is
        -- loaded in the designated oil window
        if not is_oil_buffer(bufnr) then
          self:reload()
          -- put whatever was loaded into the code window
          vim.api.nvim_win_set_buf(self.code_winnr, bufnr)
        end
      end
    end
  })

  vim.api.nvim_set_current_win(self.code_winnr)
end

function OilFileEx:reload()
  vim.schedule(function()
    self:down()
    self:load()
  end)
end

function OilFileEx:new() self.__index = self
  return setmetatable({}, self)
end

function OilFileEx:down()
  if self.oil_bufnr and vim.api.nvim_buf_is_valid(self.oil_bufnr) then
    vim.api.nvim_buf_delete(self.oil_bufnr, { force = true })
  end

  if self.oil_winnr and vim.api.nvim_win_is_valid(self.oil_winnr) then
    vim.api.nvim_win_close(self.oil_winnr, true)
  end
end

function OilFileEx:kill()
  self:down()
  self.killed = true
end

-- Practical example:

-- local oil_file_ex = OilFileEx:new()
-- oil_file_ex:up()   -- opens the oil file explorer
-- oil_file_ex:down() -- closes the file explorer, but the autocommands will remain intact meaning that if you navigate to other files from your coding buffer then oil will be reopened to the left.
-- oil_file_ex:kill() -- closes the file explorer and stops the autocommands from being triggered, you are truly free of the file explorer at this point... unless you make a new one and call up.

return OilFileEx
```
