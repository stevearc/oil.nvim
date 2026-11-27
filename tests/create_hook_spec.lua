require("plenary.async").tests.add_to_env()
local TmpDir = require("tests.tmpdir")
local files = require("oil.adapters.files")
local test_util = require("tests.test_util")
local config = require("oil.config")

a.describe("create_hook", function()
  local tmpdir
  local original_hook

  a.before_each(function()
    tmpdir = TmpDir.new()
    original_hook = config.create_hook
    config.create_hook = nil
  end)

  a.after_each(function()
    config.create_hook = original_hook
    if tmpdir then
      tmpdir:dispose()
    end
    test_util.reset_editor()
  end)

  a.it("creates empty file when hook returns nil", function()
    config.create_hook = function(action)
      return nil
    end

    local err = a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "test.txt",
      entry_type = "file",
      type = "create",
    })

    assert.is_nil(err)
    tmpdir:assert_fs({
      ["test.txt"] = "",
    })
  end)

  a.it("creates file with hook content", function()
    config.create_hook = function(action)
      return "hello world"
    end

    local err = a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "test.txt",
      entry_type = "file",
      type = "create",
    })

    assert.is_nil(err)
    tmpdir:assert_fs({
      ["test.txt"] = "hello world",
    })
  end)

  a.it("handles hook errors gracefully", function()
    config.create_hook = function(action)
      error("hook error")
    end

    local err = a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "test.txt",
      entry_type = "file",
      type = "create",
    })

    -- Should fall back to empty file creation
    assert.is_nil(err)
    tmpdir:assert_fs({
      ["test.txt"] = "",
    })
  end)

  a.it("passes action to hook", function()
    local received_action
    config.create_hook = function(action)
      received_action = action
      return nil
    end

    a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "foo.go",
      entry_type = "file",
      type = "create",
    })

    assert.is_not_nil(received_action)
    assert.equals("create", received_action.type)
    assert.equals("file", received_action.entry_type)
    assert.is_truthy(received_action.url:match("foo.go$"))
  end)

  a.it("creates file with custom content based on extension", function()
    config.create_hook = function(action)
      if action.url:match("%.sh$") then
        return "#!/bin/bash\n"
      elseif action.url:match("%.go$") then
        return "package main\n"
      end
      return nil
    end

    -- Create shell script
    local err1 = a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "script.sh",
      entry_type = "file",
      type = "create",
    })
    assert.is_nil(err1)

    -- Create go file
    local err2 = a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "main.go",
      entry_type = "file",
      type = "create",
    })
    assert.is_nil(err2)

    -- Create other file (should be empty)
    local err3 = a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "readme.txt",
      entry_type = "file",
      type = "create",
    })
    assert.is_nil(err3)

    tmpdir:assert_fs({
      ["script.sh"] = "#!/bin/bash\n",
      ["main.go"] = "package main\n",
      ["readme.txt"] = "",
    })
  end)
end)
