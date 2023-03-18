require("plenary.async").tests.add_to_env()
local oil = require("oil")
local test_util = require("tests.test_util")

a.describe("regression tests", function()
  after_each(function()
    test_util.reset_editor()
  end)
  -- see https://github.com/stevearc/oil.nvim/issues/25
  a.it("can edit dirs that will be renamed to an existing buffer", function()
    vim.cmd.edit({ args = { "README.md" } })
    vim.cmd.vsplit()
    vim.cmd.edit({ args = { "%:p:h" } })
    assert.equals("oil", vim.bo.filetype)
    vim.cmd.wincmd({ args = { "p" } })
    assert.equals("markdown", vim.bo.filetype)
    vim.cmd.edit({ args = { "%:p:h" } })
    test_util.wait_for_autocmd("BufReadPost")
    assert.equals("oil", vim.bo.filetype)
  end)

  -- https://github.com/stevearc/oil.nvim/issues/37
  a.it("places the cursor on correct entry when opening on file", function()
    vim.cmd.edit({ args = { "." } })
    test_util.wait_for_autocmd("BufReadPost")
    local entry = oil.get_cursor_entry()
    assert.not_equals("README.md", entry and entry.name)
    vim.cmd.edit({ args = { "README.md" } })
    oil.open()
    a.util.sleep(10)
    entry = oil.get_cursor_entry()
    assert.equals("README.md", entry and entry.name)
  end)

  -- https://github.com/stevearc/oil.nvim/issues/64
  a.it("doesn't close floating windows oil didn't open itself", function()
    local winid = vim.api.nvim_open_win(vim.fn.bufadd("README.md"), true, {
      relative = "editor",
      row = 1,
      col = 1,
      width = 100,
      height = 100,
    })
    oil.open()
    a.util.sleep(10)
    oil.close()
    a.util.sleep(10)
    assert.equals(winid, vim.api.nvim_get_current_win())
  end)

  -- https://github.com/stevearc/oil.nvim/issues/64
  a.it("doesn't close splits on oil.close", function()
    vim.cmd.edit({ args = { "README.md" } })
    vim.cmd.vsplit()
    local winid = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()
    oil.open()
    a.util.sleep(10)
    oil.close()
    a.util.sleep(10)
    assert.equals(2, #vim.api.nvim_tabpage_list_wins(0))
    assert.equals(winid, vim.api.nvim_get_current_win())
    assert.equals(bufnr, vim.api.nvim_get_current_buf())
  end)
end)
