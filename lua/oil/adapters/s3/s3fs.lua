local config = require("oil.config")
local cache = require("oil.cache")
local constants = require("oil.constants")
local shell = require("oil.shell")

---@class (exact) oil.s3Fs
---@field new fun(): oil.s3Fs
local S3FS = {}

local FIELD_META = constants.FIELD_META

---@param line string
---@return string Name of entry
---@return oil.EntryType
---@return table Metadata for entry
local function parse_ls_line_bucket(line)
  local date, name = line:match("^(%d+%-%d+-%d+%s%d+:%d+:%d+)%s+(.*)$")
  if not date or not name then
    error(string.format("Could not parse '%s'", line))
  end
  name = "s3://" .. name .. "/"
  local type = "directory"
  local meta = { date = date }
  return name, type, meta
end

---@param line string
---@return string Name of entry
---@return oil.EntryType
---@return table Metadata for entry
local function parse_ls_line_file(line)
  local name = line:match("^%s+PRE%s+(.*/)$")
  local type = "directory"
  local meta = {}
  if name then
    return name, type, meta
  end
  local date, size
  date, size, name = line:match("^(%d+%-%d+-%d+%s%d+:%d+:%d+)%s+(%d+)%s+(.*)$")
  if not name then
    error(string.format("Could not parse '%s'", line))
  end
  type = "file"
  meta = { date = date, size = size }
  return name, type, meta
end

---@param str string String to escape
---@return string Escaped string
local function shellescape(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

---@param cmd string[] cmd and flags
---@return string[] Shell command to run
local function create_s3_command(cmd)
  local full_cmd = vim.list_extend({ "aws", "s3" }, cmd)
  return vim.list_extend(full_cmd, config.extra_s3_args)
end

---@return oil.s3Fs
function S3FS.new()
  ---@type oil.s3Fs
  return setmetatable({}, {
    __index = S3FS,
  })
end

---@param url string
---@param path string
---@param callback fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
function S3FS:list_dir(url, path, callback)
  local cmd = create_s3_command({ "ls", shellescape(path), "--color=off", "--no-cli-pager" })
  shell.run(cmd, function(err, lines)
    if err then
      return callback(err)
    end
    assert(lines)
    local cache_entries = {}
    local is_top_level = url:match("^s3://(.*)$") == ""
    local parse_ls_line = is_top_level and parse_ls_line_bucket or parse_ls_line_file
    for _, line in ipairs(lines) do
      local name, type, meta = parse_ls_line(line)
      -- in s3 '-' can be used to create an "empty folder"
      if name ~= "-" then
        local cache_entry = cache.create_entry(url, name, type)
        table.insert(cache_entries, cache_entry)
        cache_entry[FIELD_META] = meta
      end
    end
    callback(nil, cache_entries)
  end)
end

--- Create files
---@param path string
---@param callback fun(err: nil|string)
function S3FS:touch(path, callback)
  -- here "-" means that we copy from stdin
  local cmd = create_s3_command({ "cp", "-", shellescape(path) })
  shell.run(cmd, { stdin = "" }, callback)
end

--- Remove files
---@param path string
---@param callback fun(err: nil|string)
function S3FS:rm(path, callback)
  local cmd = create_s3_command({ "rm", shellescape(path), "--recursive" })
  shell.run(cmd, callback)
end

--- Remove bucket
---@param bucket string
---@param callback fun(err: nil|string)
function S3FS:rb(bucket, callback)
  local cmd = create_s3_command({ "rb", shellescape(bucket) })
  shell.run(cmd, callback)
end

--- Make bucket
---@param bucket string
---@param callback fun(err: nil|string)
function S3FS:mb(bucket, callback)
  local cmd = create_s3_command({ "mb", shellescape(bucket) })
  shell.run(cmd, callback)
end

--- Move files
---@param src string
---@param dest string
---@param callback fun(err: nil|string)
function S3FS:mv(src, dest, callback)
  local cmd = create_s3_command({ "mv", shellescape(src), shellescape(dest), "--recursive" })
  shell.run(cmd, callback)
end

--- Copy files
---@param src string
---@param dest string
---@param callback fun(err: nil|string)
function S3FS:cp(src, dest, callback)
  local cmd = create_s3_command({ "cp", shellescape(src), shellescape(dest), "--recursive" })
  shell.run(cmd, callback)
end

return S3FS
