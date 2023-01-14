local fs = require("oil.fs")
local test_util = require("tests.test_util")
local util = require("oil.util")

describe("update_moved_buffers", function()
  after_each(function()
    test_util.reset_editor()
  end)

  it("Renames moved buffers", function()
    vim.cmd.edit({ args = { "oil-test:///foo/bar.txt" } })
    util.update_moved_buffers("file", "oil-test:///foo/bar.txt", "oil-test:///foo/baz.txt")
    assert.equals("oil-test:///foo/baz.txt", vim.api.nvim_buf_get_name(0))
  end)

  it("Renames moved buffers when they are normal files", function()
    local tmpdir = fs.join(vim.loop.fs_realpath(vim.fn.stdpath("cache")), "oil", "test")
    local testfile = fs.join(tmpdir, "foo.txt")
    vim.cmd.edit({ args = { testfile } })
    util.update_moved_buffers(
      "file",
      "oil://" .. fs.os_to_posix_path(testfile),
      "oil://" .. fs.os_to_posix_path(fs.join(tmpdir, "bar.txt"))
    )
    assert.equals(fs.join(tmpdir, "bar.txt"), vim.api.nvim_buf_get_name(0))
  end)

  it("Renames directories", function()
    vim.cmd.edit({ args = { "oil-test:///foo/" } })
    util.update_moved_buffers("directory", "oil-test:///foo/", "oil-test:///bar/")
    assert.equals("oil-test:///bar/", vim.api.nvim_buf_get_name(0))
  end)

  it("Renames subdirectories", function()
    vim.cmd.edit({ args = { "oil-test:///foo/bar/" } })
    util.update_moved_buffers("directory", "oil-test:///foo/", "oil-test:///baz/")
    assert.equals("oil-test:///baz/bar/", vim.api.nvim_buf_get_name(0))
  end)

  it("Renames subfiles", function()
    vim.cmd.edit({ args = { "oil-test:///foo/bar.txt" } })
    util.update_moved_buffers("directory", "oil-test:///foo/", "oil-test:///baz/")
    assert.equals("oil-test:///baz/bar.txt", vim.api.nvim_buf_get_name(0))
  end)

  it("Renames subfiles when they are normal files", function()
    local tmpdir = fs.join(vim.loop.fs_realpath(vim.fn.stdpath("cache")), "oil", "test")
    local foo = fs.join(tmpdir, "foo")
    local bar = fs.join(tmpdir, "bar")
    local testfile = fs.join(foo, "foo.txt")
    vim.cmd.edit({ args = { testfile } })
    util.update_moved_buffers(
      "directory",
      "oil://" .. fs.os_to_posix_path(foo),
      "oil://" .. fs.os_to_posix_path(bar)
    )
    assert.equals(fs.join(bar, "foo.txt"), vim.api.nvim_buf_get_name(0))
  end)
end)
