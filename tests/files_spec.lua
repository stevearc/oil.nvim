require("plenary.async").tests.add_to_env()
local fs = require("oil.fs")
local files = require("oil.adapters.files")
local cache = require("oil.cache")
local test_util = require("tests.test_util")

local function throwiferr(err, ...)
  if err then
    error(err)
  else
    return ...
  end
end

local function await(fn, nargs, ...)
  return throwiferr(a.wrap(fn, nargs)(...))
end

---@param path string
---@param cb fun(err: nil|string)
local function touch(path, cb)
  vim.loop.fs_open(path, "w", 420, function(err, fd) -- 0644
    if err then
      cb(err)
    else
      local shortpath = path:gsub("^[^" .. fs.sep .. "]*" .. fs.sep, "")
      vim.loop.fs_write(fd, shortpath, nil, function(err2)
        if err2 then
          cb(err2)
        else
          vim.loop.fs_close(fd, cb)
        end
      end)
    end
  end)
end

---@param filepath string
---@return boolean
local function exists(filepath)
  local stat = vim.loop.fs_stat(filepath)
  return stat ~= nil and stat.type ~= nil
end

local TmpDir = {}

TmpDir.new = function()
  local path = await(vim.loop.fs_mkdtemp, 2, "oil_test_XXXXXXXXX")
  return setmetatable({ path = path }, {
    __index = TmpDir,
  })
end

---@param paths string[]
function TmpDir:create(paths)
  for _, path in ipairs(paths) do
    local pieces = vim.split(path, fs.sep)
    local partial_path = self.path
    for i, piece in ipairs(pieces) do
      partial_path = fs.join(partial_path, piece)
      if i == #pieces and not vim.endswith(partial_path, fs.sep) then
        await(touch, 2, partial_path)
      elseif not exists(partial_path) then
        vim.loop.fs_mkdir(partial_path, 493)
      end
    end
  end
end

---@param filepath string
---@return string?
local read_file = function(filepath)
  local fd = vim.loop.fs_open(filepath, "r", 420)
  if not fd then
    return nil
  end
  local stat = vim.loop.fs_fstat(fd)
  local content = vim.loop.fs_read(fd, stat.size)
  vim.loop.fs_close(fd)
  return content
end

---@param dir string
---@param cb fun(err: nil|string, entry: {type: oil.EntryType, name: string, root: string}
local function walk(dir)
  local ret = {}
  for name, type in vim.fs.dir(dir) do
    table.insert(ret, {
      name = name,
      type = type,
      root = dir,
    })
    if type == "directory" then
      vim.list_extend(ret, walk(fs.join(dir, name)))
    end
  end
  return ret
end

---@param paths table<string, string>
local assert_fs = function(root, paths)
  local unlisted_dirs = {}
  for k in pairs(paths) do
    local pieces = vim.split(k, "/")
    local partial_path = ""
    for i, piece in ipairs(pieces) do
      partial_path = fs.join(partial_path, piece) .. "/"
      if i ~= #pieces then
        unlisted_dirs[partial_path:sub(2)] = true
      end
    end
  end
  for k in pairs(unlisted_dirs) do
    paths[k] = true
  end

  local entries = walk(root)
  for _, entry in ipairs(entries) do
    local fullpath = fs.join(entry.root, entry.name)
    local shortpath = fullpath:sub(root:len() + 2)
    if entry.type == "directory" then
      shortpath = shortpath .. "/"
    end
    local expected_content = paths[shortpath]
    paths[shortpath] = nil
    assert.truthy(expected_content, string.format("Unexpected entry '%s'", shortpath))
    if entry.type == "file" then
      local data = read_file(fullpath)
      assert.equals(
        expected_content,
        data,
        string.format(
          "File '%s' expected content '%s' received '%s'",
          shortpath,
          expected_content,
          data
        )
      )
    end
  end

  for k, v in pairs(paths) do
    assert.falsy(
      k,
      string.format(
        "Expected %s '%s', but it was not found",
        v == true and "directory" or "file",
        k
      )
    )
  end
end

---@param paths table<string, string>
function TmpDir:assert_fs(paths)
  a.util.scheduler()
  assert_fs(self.path, paths)
end

function TmpDir:dispose()
  await(fs.recursive_delete, 3, "directory", self.path)
end

a.describe("files adapter", function()
  local tmpdir
  a.before_each(function()
    tmpdir = TmpDir.new()
  end)
  a.after_each(function()
    if tmpdir then
      tmpdir:dispose()
      a.util.scheduler()
      tmpdir = nil
    end
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    cache.clear_everything()
  end)

  a.it("tmpdir creates files and asserts they exist", function()
    tmpdir:create({ "a.txt", "foo/b.txt", "foo/c.txt", "bar/" })
    tmpdir:assert_fs({
      ["a.txt"] = "a.txt",
      ["foo/b.txt"] = "foo/b.txt",
      ["foo/c.txt"] = "foo/c.txt",
      ["bar/"] = true,
    })
  end)

  a.it("Creates files", function()
    local err = a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "a.txt",
      entry_type = "file",
      type = "create",
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ["a.txt"] = "",
    })
  end)

  a.it("Creates directories", function()
    local err = a.wrap(files.perform_action, 2)({
      url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "a",
      entry_type = "directory",
      type = "create",
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ["a/"] = true,
    })
  end)

  a.it("Deletes files", function()
    tmpdir:create({ "a.txt" })
    a.util.scheduler()
    local url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "a.txt"
    local err = a.wrap(files.perform_action, 2)({
      url = url,
      entry_type = "file",
      type = "delete",
    })
    assert.is_nil(err)
    tmpdir:assert_fs({})
  end)

  a.it("Deletes directories", function()
    tmpdir:create({ "a/" })
    local url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "a"
    local err = a.wrap(files.perform_action, 2)({
      url = url,
      entry_type = "directory",
      type = "delete",
    })
    assert.is_nil(err)
    tmpdir:assert_fs({})
  end)

  a.it("Moves files", function()
    tmpdir:create({ "a.txt" })
    a.util.scheduler()
    local src_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "a.txt"
    local dest_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "b.txt"
    local err = a.wrap(files.perform_action, 2)({
      src_url = src_url,
      dest_url = dest_url,
      entry_type = "file",
      type = "move",
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ["b.txt"] = "a.txt",
    })
  end)

  a.it("Moves directories", function()
    tmpdir:create({ "a/a.txt" })
    a.util.scheduler()
    local src_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "a"
    local dest_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "b"
    local err = a.wrap(files.perform_action, 2)({
      src_url = src_url,
      dest_url = dest_url,
      entry_type = "directory",
      type = "move",
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ["b/a.txt"] = "a/a.txt",
      ["b/"] = true,
    })
  end)

  a.it("Copies files", function()
    tmpdir:create({ "a.txt" })
    a.util.scheduler()
    local src_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "a.txt"
    local dest_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "b.txt"
    local err = a.wrap(files.perform_action, 2)({
      src_url = src_url,
      dest_url = dest_url,
      entry_type = "file",
      type = "copy",
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ["a.txt"] = "a.txt",
      ["b.txt"] = "a.txt",
    })
  end)

  a.it("Recursively copies directories", function()
    tmpdir:create({ "a/a.txt" })
    a.util.scheduler()
    local src_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "a"
    local dest_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "b"
    local err = a.wrap(files.perform_action, 2)({
      src_url = src_url,
      dest_url = dest_url,
      entry_type = "directory",
      type = "copy",
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ["b/a.txt"] = "a/a.txt",
      ["b/"] = true,
      ["a/a.txt"] = "a/a.txt",
      ["a/"] = true,
    })
  end)

  a.it("Editing a new oil://path/ creates an oil buffer", function()
    local tmpdir_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "/"
    vim.cmd.edit({ args = { tmpdir_url } })
    test_util.wait_for_autocmd("BufReadPost")
    local new_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "newdir"
    vim.cmd.edit({ args = { new_url } })
    test_util.wait_for_autocmd("BufReadPost")
    assert.equals("oil", vim.bo.filetype)
    -- The normalization will add a '/'
    assert.equals(new_url .. "/", vim.api.nvim_buf_get_name(0))
  end)

  a.it("Editing a new oil://file.rb creates a normal buffer", function()
    local tmpdir_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "/"
    vim.cmd.edit({ args = { tmpdir_url } })
    test_util.wait_for_autocmd("BufReadPost")
    local new_url = "oil://" .. vim.fn.fnamemodify(tmpdir.path, ":p") .. "file.rb"
    vim.cmd.edit({ args = { new_url } })
    test_util.wait_for_autocmd("BufReadPost")
    assert.equals("ruby", vim.bo.filetype)
    assert.equals(vim.fn.fnamemodify(tmpdir.path, ":p") .. "file.rb", vim.api.nvim_buf_get_name(0))
  end)
end)
