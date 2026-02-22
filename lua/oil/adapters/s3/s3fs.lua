local cache = require('oil.cache')
local config = require('oil.config')
local constants = require('oil.constants')
local shell = require('oil.shell')
local util = require('oil.util')

local M = {}

local FIELD_META = constants.FIELD_META

---@param line string
---@return string Name of entry
---@return oil.EntryType
---@return table Metadata for entry
local function parse_ls_line_bucket(line)
  local date, name = line:match('^(%d+%-%d+%-%d+%s%d+:%d+:%d+)%s+(.*)$')
  if not date or not name then
    error(string.format("Could not parse '%s'", line))
  end
  local type = 'directory'
  local meta = { date = date }
  return name, type, meta
end

---@param line string
---@return string Name of entry
---@return oil.EntryType
---@return table Metadata for entry
local function parse_ls_line_file(line)
  local name = line:match('^%s+PRE%s+(.*)/$')
  local type = 'directory'
  local meta = {}
  if name then
    return name, type, meta
  end
  local date, size
  date, size, name = line:match('^(%d+%-%d+%-%d+%s%d+:%d+:%d+)%s+(%d+)%s+(.*)$')
  if not name then
    error(string.format("Could not parse '%s'", line))
  end
  type = 'file'
  meta = { date = date, size = tonumber(size) }
  return name, type, meta
end

---@param cmd string[] cmd and flags
---@return string[] Shell command to run
local function create_s3_command(cmd)
  local full_cmd = vim.list_extend({ 'aws', 's3' }, cmd)
  return vim.list_extend(full_cmd, config.extra_s3_args)
end

---@param url string
---@param path string
---@param callback fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
function M.list_dir(url, path, callback)
  local cmd = create_s3_command({ 'ls', path, '--color=off', '--no-cli-pager' })
  shell.run(cmd, function(err, lines)
    if err then
      return callback(err)
    end
    assert(lines)
    local cache_entries = {}
    local url_path, _
    _, url_path = util.parse_url(url)
    local is_top_level = url_path == nil or url_path:match('/') == nil
    local parse_ls_line = is_top_level and parse_ls_line_bucket or parse_ls_line_file
    for _, line in ipairs(lines) do
      if line ~= '' then
        local name, type, meta = parse_ls_line(line)
        -- in s3 '-' can be used to create an "empty folder"
        if name ~= '-' then
          local cache_entry = cache.create_entry(url, name, type)
          table.insert(cache_entries, cache_entry)
          cache_entry[FIELD_META] = meta
        end
      end
    end
    callback(nil, cache_entries)
  end)
end

--- Create files
---@param path string
---@param callback fun(err: nil|string)
function M.touch(path, callback)
  -- here "-" means that we copy from stdin
  local cmd = create_s3_command({ 'cp', '-', path })
  shell.run(cmd, { stdin = 'null' }, callback)
end

--- Remove files
---@param path string
---@param is_folder boolean
---@param callback fun(err: nil|string)
function M.rm(path, is_folder, callback)
  local main_cmd = { 'rm', path }
  if is_folder then
    table.insert(main_cmd, '--recursive')
  end
  local cmd = create_s3_command(main_cmd)
  shell.run(cmd, callback)
end

--- Remove bucket
---@param bucket string
---@param callback fun(err: nil|string)
function M.rb(bucket, callback)
  local cmd = create_s3_command({ 'rb', bucket })
  shell.run(cmd, callback)
end

--- Make bucket
---@param bucket string
---@param callback fun(err: nil|string)
function M.mb(bucket, callback)
  local cmd = create_s3_command({ 'mb', bucket })
  shell.run(cmd, callback)
end

--- Move files
---@param src string
---@param dest string
---@param is_folder boolean
---@param callback fun(err: nil|string)
function M.mv(src, dest, is_folder, callback)
  local main_cmd = { 'mv', src, dest }
  if is_folder then
    table.insert(main_cmd, '--recursive')
  end
  local cmd = create_s3_command(main_cmd)
  shell.run(cmd, callback)
end

--- Copy files
---@param src string
---@param dest string
---@param is_folder boolean
---@param callback fun(err: nil|string)
function M.cp(src, dest, is_folder, callback)
  local main_cmd = { 'cp', src, dest }
  if is_folder then
    table.insert(main_cmd, '--recursive')
  end
  local cmd = create_s3_command(main_cmd)
  shell.run(cmd, callback)
end

return M
