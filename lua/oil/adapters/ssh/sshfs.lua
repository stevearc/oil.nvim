local SSHConnection = require("oil.adapters.ssh.connection")
local cache = require("oil.cache")
local constants = require("oil.constants")
local permissions = require("oil.adapters.files.permissions")
local util = require("oil.util")

---@class (exact) oil.sshFs
---@field new fun(url: oil.sshUrl): oil.sshFs
---@field conn oil.sshConnection
local SSHFS = {}

local FIELD_TYPE = constants.FIELD_TYPE
local FIELD_META = constants.FIELD_META

local typechar_map = {
  l = "link",
  d = "directory",
  p = "fifo",
  s = "socket",
  ["-"] = "file",
  c = "file", -- character special file
  b = "file", -- block special file
}
---@param line string
---@return string Name of entry
---@return oil.EntryType
---@return table Metadata for entry
local function parse_ls_line(line)
  local typechar, perms, refcount, user, group, rem =
    line:match("^(.)(%S+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(.*)$")
  if not typechar then
    error(string.format("Could not parse '%s'", line))
  end
  local type = typechar_map[typechar] or "file"

  local meta = {
    user = user,
    group = group,
    mode = permissions.parse(perms),
    refcount = tonumber(refcount),
  }
  local name, size, date, major, minor
  if typechar == "c" or typechar == "b" then
    major, minor, date, name = rem:match("^(%d+)%s*,%s*(%d+)%s+(%S+%s+%d+%s+%d%d:?%d%d)%s+(.*)")
    if name == nil then
      major, minor, date, name =
        rem:match("^(%d+)%s*,%s*(%d+)%s+(%d+%-%d+%-%d+%s+%d%d:?%d%d)%s+(.*)")
    end
    meta.major = tonumber(major)
    meta.minor = tonumber(minor)
  else
    size, date, name = rem:match("^(%d+)%s+(%S+%s+%d+%s+%d%d:?%d%d)%s+(.*)")
    if name == nil then
      size, date, name = rem:match("^(%d+)%s+(%d+%-%d+%-%d+%s+%d%d:?%d%d)%s+(.*)")
    end
    meta.size = tonumber(size)
  end
  meta.iso_modified_date = date
  if type == "link" then
    local link
    name, link = unpack(vim.split(name, " -> ", { plain = true }))
    if vim.endswith(link, "/") then
      link = link:sub(1, #link - 1)
    end
    meta.link = link
  end

  return name, type, meta
end

---@param str string String to escape
---@return string Escaped string
local function shellescape(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

---@param url oil.sshUrl
---@return oil.sshFs
function SSHFS.new(url)
  ---@type oil.sshFs
  return setmetatable({
    conn = SSHConnection.new(url),
  }, {
    __index = SSHFS,
  })
end

function SSHFS:get_connection_error()
  return self.conn.connection_error
end

---@param value integer
---@param path string
---@param callback fun(err: nil|string)
function SSHFS:chmod(value, path, callback)
  local octal = permissions.mode_to_octal_str(value)
  self.conn:run(string.format("chmod %s %s", octal, shellescape(path)), callback)
end

function SSHFS:open_terminal()
  self.conn:open_terminal()
end

function SSHFS:realpath(path, callback)
  local cmd = string.format(
    'if ! readlink -f "%s" 2>/dev/null; then [[ "%s" == /* ]] && echo "%s" || echo "$PWD/%s"; fi',
    path,
    path,
    path,
    path
  )
  self.conn:run(cmd, function(err, lines)
    if err then
      return callback(err)
    end
    assert(lines)
    local abspath = table.concat(lines, "")
    -- If the path was "." then the abspath might be /path/to/., so we need to trim that final '.'
    if vim.endswith(abspath, ".") then
      abspath = abspath:sub(1, #abspath - 1)
    end
    self.conn:run(
      string.format("LC_ALL=C ls -land --color=never %s", shellescape(abspath)),
      function(ls_err, ls_lines)
        local type
        if ls_err then
          -- If the file doesn't exist, treat it like a not-yet-existing directory
          type = "directory"
        else
          assert(ls_lines)
          local _
          _, type = parse_ls_line(ls_lines[1])
        end
        if type == "directory" then
          abspath = util.addslash(abspath)
        end
        callback(nil, abspath)
      end
    )
  end)
end

local dir_meta = {}

---@param url string
---@param path string
---@param callback fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
function SSHFS:list_dir(url, path, callback)
  local path_postfix = ""
  if path ~= "" then
    path_postfix = string.format(" %s", shellescape(path))
  end
  self.conn:run("LC_ALL=C ls -lan --color=never" .. path_postfix, function(err, lines)
    if err then
      if err:match("No such file or directory%s*$") then
        -- If the directory doesn't exist, treat the list as a success. We will be able to traverse
        -- and edit a not-yet-existing directory.
        return callback()
      else
        return callback(err)
      end
    end
    assert(lines)
    local any_links = false
    local entries = {}
    local cache_entries = {}
    for _, line in ipairs(lines) do
      if line ~= "" and not line:match("^total") then
        local name, type, meta = parse_ls_line(line)
        if name == "." then
          dir_meta[url] = meta
        elseif name ~= ".." then
          if type == "link" then
            any_links = true
          end
          local cache_entry = cache.create_entry(url, name, type)
          table.insert(cache_entries, cache_entry)
          entries[name] = cache_entry
          cache_entry[FIELD_META] = meta
        end
      end
    end
    if any_links then
      -- If there were any soft links, then we need to run another ls command with -L so that we can
      -- resolve the type of the link target
      self.conn:run(
        "LC_ALL=C ls -naLl --color=never" .. path_postfix .. " 2> /dev/null",
        function(link_err, link_lines)
          -- Ignore exit code 1. That just means one of the links could not be resolved.
          if link_err and not link_err:match("^1:") then
            return callback(link_err)
          end
          assert(link_lines)
          for _, line in ipairs(link_lines) do
            if line ~= "" and not line:match("^total") then
              local ok, name, type, meta = pcall(parse_ls_line, line)
              if ok and name ~= "." and name ~= ".." then
                local cache_entry = entries[name]
                if cache_entry[FIELD_TYPE] == "link" then
                  cache_entry[FIELD_META].link_stat = {
                    type = type,
                    size = meta.size,
                  }
                end
              end
            end
          end
          callback(nil, cache_entries)
        end
      )
    else
      callback(nil, cache_entries)
    end
  end)
end

---@param path string
---@param callback fun(err: nil|string)
function SSHFS:mkdir(path, callback)
  self.conn:run(string.format("mkdir -p %s", shellescape(path)), callback)
end

---@param path string
---@param callback fun(err: nil|string)
function SSHFS:touch(path, callback)
  self.conn:run(string.format("touch %s", shellescape(path)), callback)
end

---@param path string
---@param link string
---@param callback fun(err: nil|string)
function SSHFS:mklink(path, link, callback)
  self.conn:run(string.format("ln -s %s %s", shellescape(link), shellescape(path)), callback)
end

---@param path string
---@param callback fun(err: nil|string)
function SSHFS:rm(path, callback)
  self.conn:run(string.format("rm -rf %s", shellescape(path)), callback)
end

---@param src string
---@param dest string
---@param callback fun(err: nil|string)
function SSHFS:mv(src, dest, callback)
  self.conn:run(string.format("mv %s %s", shellescape(src), shellescape(dest)), callback)
end

---@param src string
---@param dest string
---@param callback fun(err: nil|string)
function SSHFS:cp(src, dest, callback)
  self.conn:run(string.format("cp -r %s %s", shellescape(src), shellescape(dest)), callback)
end

function SSHFS:get_dir_meta(url)
  return dir_meta[url]
end

function SSHFS:get_meta()
  return self.conn.meta
end

return SSHFS
