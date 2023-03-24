local fs = require("oil.fs")

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

return TmpDir
