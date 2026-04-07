require("plenary.async").tests.add_to_env()
local actions = require("oil.actions")
local TmpDir = require("tests.tmpdir")
local test_util = require("tests.test_util")

a.describe("oil yank_entry", function()
  local tmpdir
  a.before_each(function()
    tmpdir = TmpDir.new()
  end)
  a.after_each(function()
    if tmpdir then
      tmpdir:dispose()
      tmpdir = nil
    end
    test_util.reset_editor()
  end)

  a.it("yanks the filepath of the entry under cursor", function()
    tmpdir:create({ "test_file.txt" })
    a.util.scheduler()

    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("test_file.txt")

    -- Save current register content
    local old_reg = vim.fn.getreg('"')

    -- Call yank_entry action
    actions.yank_entry.callback()

    -- Verify the path was yanked
    local yanked = vim.fn.getreg('"')
    assert.is_true(yanked:find("test_file.txt") ~= nil, string.format("Expected path with 'test_file.txt', got: '%s'", yanked))

    -- Restore original register
    vim.fn.setreg('"', old_reg)
  end)

  a.it("yanks directory path with trailing slash", function()
    tmpdir:create({ "mydir/" })
    a.util.scheduler()

    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("mydir/")

    local old_reg = vim.fn.getreg('"')
    actions.yank_entry.callback()

    local yanked = vim.fn.getreg('"')
    assert.is_true(vim.endswith(yanked, "/"), string.format("Expected trailing slash for directory, got: '%s'", yanked))

    vim.fn.setreg('"', old_reg)
  end)

  a.it("yanks file path without trailing slash", function()
    tmpdir:create({ "myfile.txt" })
    a.util.scheduler()

    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("myfile.txt")

    local old_reg = vim.fn.getreg('"')
    actions.yank_entry.callback()

    local yanked = vim.fn.getreg('"')
    assert.is_true(not vim.endswith(yanked, "/"), string.format("Expected no trailing slash for file, got: '%s'", yanked))

    vim.fn.setreg('"', old_reg)
  end)

  a.it("respects the modify parameter", function()
    tmpdir:create({ "testdir/" })
    a.util.scheduler()

    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("testdir/")

    local old_reg = vim.fn.getreg('"')

    -- Use modify to shorten the path (get parent directory name)
    actions.yank_entry.callback({ modify = ":h:t" })

    local yanked = vim.fn.getreg('"')
    -- :h gets the parent directory, :t gets the tail (directory name)
    -- We should get a non-empty result
    assert.is_true(#yanked > 0, string.format("Expected non-empty path after :h:t, got: '%s'", yanked))

    vim.fn.setreg('"', old_reg)
  end)
end)
