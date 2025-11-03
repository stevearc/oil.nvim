require("plenary.async").tests.add_to_env()

local fs = require("oil.fs")
local buffer_cleanup = require("oil.buffer_cleanup")
local util = require("oil.util")
local TmpDir = require("tests.tmpdir")
local test_util = require("tests.test_util")

a.describe("buffer cleanup", function()
  local original_cwd

  a.before_each(function()
    original_cwd = vim.loop.cwd()
    test_util.reset_editor()
  end)

  a.after_each(function()
    if original_cwd then
      vim.loop.chdir(original_cwd)
    end
    test_util.reset_editor()
  end)

  local function setup_oil(opts)
    opts = opts or {}
    opts.adapters = vim.tbl_extend("force", {
      ["oil://"] = "files",
      ["oil-test://"] = "test",
    }, opts.adapters or {})
    opts.prompt_save_on_select_new_entry = false
    require("oil").setup(opts)
  end

  a.it("closes unmodified buffers for deleted files", function()
    local tmp = TmpDir.new()
    tmp:create({ "foo.txt" })
    local abs_path = fs.abspath(tmp.path)
    local file = fs.join(abs_path, "foo.txt")
    setup_oil({ buffer_cleanup = { delete = true } })
    assert.is_true(require("oil.config").buffer_cleanup.delete)
    vim.loop.chdir(abs_path)
    vim.cmd.edit({ args = { "foo.txt" } })
    local bufnr = vim.api.nvim_get_current_buf()
    buffer_cleanup.handle_action({
      type = "delete",
      entry_type = "file",
      url = "oil://" .. fs.os_to_posix_path(file),
    })
    a.util.scheduler()
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
  end)

  a.it("skips modified buffers by default", function()
    local tmp = TmpDir.new()
    tmp:create({ "foo.txt" })
    local abs_path = fs.abspath(tmp.path)
    local file = fs.join(abs_path, "foo.txt")
    setup_oil({ buffer_cleanup = { delete = true } })
    vim.loop.chdir(abs_path)
    vim.cmd.edit({ args = { "foo.txt" } })
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { "changed" })
    buffer_cleanup.handle_action({
      type = "delete",
      entry_type = "file",
      url = "oil://" .. fs.os_to_posix_path(file),
    })
    a.util.scheduler()
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
  end)

  a.it("forces closing modified buffers when configured", function()
    local tmp = TmpDir.new()
    tmp:create({ "foo.txt" })
    local abs_path = fs.abspath(tmp.path)
    local file = fs.join(abs_path, "foo.txt")
    setup_oil({ buffer_cleanup = { delete = true, force = true } })
    local conf = require("oil.config").buffer_cleanup
    assert.is_true(conf.delete)
    assert.is_true(conf.force)
    vim.loop.chdir(abs_path)
    vim.cmd.edit({ args = { "foo.txt" } })
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { "changed" })
    buffer_cleanup.handle_action({
      type = "delete",
      entry_type = "file",
      url = "oil://" .. fs.os_to_posix_path(file),
    })
    a.util.scheduler()
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
  end)

  a.it("reloads moved file buffers", function()
    local tmp = TmpDir.new()
    tmp:create({ "foo.txt" })
    local abs_path = fs.abspath(tmp.path)
    local src = fs.join(abs_path, "foo.txt")
    local dest = fs.join(abs_path, "bar.txt")
    setup_oil({ buffer_cleanup = { delete = true, move = true } })
    vim.loop.chdir(abs_path)
    vim.cmd.edit({ args = { "foo.txt" } })
    local bufnr = vim.api.nvim_get_current_buf()

    local ok, err = vim.loop.fs_rename(src, dest)
    assert(ok, err)
    util.update_moved_buffers("file", "oil://" .. fs.os_to_posix_path(src), "oil://" .. fs.os_to_posix_path(dest))
    a.util.scheduler()

    local fd = assert(vim.loop.fs_open(dest, "w", 420))
    assert(vim.loop.fs_write(fd, "updated"))
    vim.loop.fs_close(fd)

    buffer_cleanup.handle_action({
      type = "move",
      entry_type = "file",
      src_url = "oil://" .. fs.os_to_posix_path(src),
      dest_url = "oil://" .. fs.os_to_posix_path(dest),
    })
    a.util.scheduler()
    local dest_bufnr = vim.fn.bufnr(dest)
    assert.is_true(dest_bufnr > 0, "destination buffer not found")
    local lines = vim.api.nvim_buf_get_lines(dest_bufnr, 0, -1, true)
    assert.are.same({ "updated" }, lines)
  end)
end)

