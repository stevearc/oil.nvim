local uv = vim.uv or vim.loop
require("plenary.async").tests.add_to_env()
local TmpDir = require("tests.tmpdir")
local fs = require("oil.fs")
local test_util = require("tests.test_util")

---Get the raw list of filenames from an unmodified oil buffer
---@param bufnr? integer
---@return string[]
local function parse_entries(bufnr)
  bufnr = bufnr or 0
  if vim.bo[bufnr].modified then
    error("parse_entries doesn't work on a modified oil buffer")
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  return vim.tbl_map(function(line)
    return line:match("^/%d+ +(.+)$")
  end, lines)
end

a.describe("freedesktop", function()
  local tmpdir
  a.before_each(function()
    tmpdir = TmpDir.new()
    package.loaded["oil.adapters.trash"] = require("oil.adapters.trash.freedesktop")
    local trash_dir = string.format(".Trash-%d", uv.getuid())
    tmpdir:create({ fs.join(trash_dir, "__dummy__") })
  end)
  a.after_each(function()
    if tmpdir then
      tmpdir:dispose()
    end
    test_util.reset_editor()
    package.loaded["oil.adapters.trash"] = nil
  end)

  a.it("files can be moved to the trash", function()
    tmpdir:create({ "a.txt", "foo/b.txt" })
    test_util.actions.open({ tmpdir.path })
    test_util.actions.focus("a.txt")
    vim.api.nvim_feedkeys("dd", "x", true)
    test_util.actions.open({ "--trash", tmpdir.path })
    vim.api.nvim_feedkeys("p", "x", true)
    test_util.actions.save()
    tmpdir:assert_not_exists("a.txt")
    tmpdir:assert_exists("foo/b.txt")
    test_util.actions.reload()
    assert.are.same({ "a.txt" }, parse_entries(0))
  end)

  -- TODO
  -- deleting a file moves it to the trash
  -- can't create files in trash
  -- can't rename files in trash
  -- can't copy files in trash
  -- pasting a file multiple times into the trash only deletes to trash once
  -- restore from trash
  -- restore from trash to multiple locations
  -- can have multiple files with the same name in trash
  -- can delete directories to trash
end)
