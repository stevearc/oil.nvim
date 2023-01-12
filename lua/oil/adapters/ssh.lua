local cache = require("oil.cache")
local config = require("oil.config")
local fs = require("oil.fs")
local files = require("oil.adapters.files")
local permissions = require("oil.adapters.files.permissions")
local ssh_connection = require("oil.adapters.ssh.connection")
local pathutil = require("oil.pathutil")
local shell = require("oil.shell")
local util = require("oil.util")
local FIELD = require("oil.constants").FIELD
local M = {}

---@class oil.sshUrl
---@field scheme string
---@field host string
---@field user nil|string
---@field port nil|integer
---@field path string

---@param oil_url string
---@return oil.sshUrl
local function parse_url(oil_url)
  local scheme, url = util.parse_url(oil_url)
  local ret = { scheme = scheme }
  local username, rem = url:match("^([^@%s]+)@(.*)$")
  ret.user = username
  url = rem or url
  local host, port, path = url:match("^([^:]+):(%d+)/(.*)$")
  if host then
    ret.host = host
    ret.port = tonumber(port)
    ret.path = path
  else
    host, path = url:match("^([^/]+)/(.*)$")
    ret.host = host
    ret.path = path
  end
  if not ret.host or not ret.path then
    error(string.format("Malformed SSH url: %s", oil_url))
  end

  return ret
end

---@param url oil.sshUrl
---@return string
local function url_to_str(url)
  local pieces = { url.scheme }
  if url.user then
    table.insert(pieces, url.user)
    table.insert(pieces, "@")
  end
  table.insert(pieces, url.host)
  if url.port then
    table.insert(pieces, string.format(":%d", url.port))
  end
  table.insert(pieces, "/")
  table.insert(pieces, url.path)
  return table.concat(pieces, "")
end

---@param url oil.sshUrl
---@return string
local function url_to_scp(url)
  local pieces = { "scp://" }
  if url.user then
    table.insert(pieces, url.user)
    table.insert(pieces, "@")
  end
  table.insert(pieces, url.host)
  if url.port then
    table.insert(pieces, string.format(":%d", url.port))
  end
  table.insert(pieces, "/")
  table.insert(pieces, url.path)
  return table.concat(pieces, "")
end

local _connections = {}
---@param url string
---@param allow_retry nil|boolean
local function get_connection(url, allow_retry)
  local res = parse_url(url)
  res.scheme = config.adapter_to_scheme.ssh
  res.path = ""
  local key = url_to_str(res)
  local conn = _connections[key]
  if not conn or (allow_retry and conn.connection_error) then
    conn = ssh_connection.new(res)
    _connections[key] = conn
  end
  return conn
end

local typechar_map = {
  l = "link",
  d = "directory",
  p = "fifo",
  s = "socket",
  ["-"] = "file",
}
---@param line string
---@return string Name of entry
---@return oil.EntryType
---@return nil|table Metadata for entry
local function parse_ls_line(line)
  local typechar, perms, refcount, user, group, size, date, name =
    line:match("^(.)(%S+)%s+(%d+)%s+(%S+)%s+(%S+)%s+(%d+)%s+(%S+%s+%d+%s+%d%d:?%d%d)%s+(.*)$")
  if not typechar then
    error(string.format("Could not parse '%s'", line))
  end
  local type = typechar_map[typechar] or "file"

  local meta = {
    user = user,
    group = group,
    mode = permissions.parse(perms),
    refcount = tonumber(refcount),
    size = tonumber(size),
    iso_modified_date = date,
  }
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

local ssh_columns = {}
ssh_columns.permissions = {
  render = function(entry, conf)
    local meta = entry[FIELD.meta]
    return permissions.mode_to_str(meta.mode)
  end,

  parse = function(line, conf)
    return permissions.parse(line)
  end,

  compare = function(entry, parsed_value)
    local meta = entry[FIELD.meta]
    if parsed_value and meta.mode then
      local mask = bit.lshift(1, 12) - 1
      local old_mode = bit.band(meta.mode, mask)
      if parsed_value ~= old_mode then
        return true
      end
    end
    return false
  end,

  render_action = function(action)
    return string.format("CHMOD %s %s", permissions.mode_to_octal_str(action.value), action.url)
  end,

  perform_action = function(action, callback)
    local res = parse_url(action.url)
    local conn = get_connection(action.url)
    local octal = permissions.mode_to_octal_str(action.value)
    conn:run(string.format("chmod %s '%s'", octal, res.path), callback)
  end,
}

ssh_columns.size = {
  render = function(entry, conf)
    local meta = entry[FIELD.meta]
    if meta.size >= 1e9 then
      return string.format("%.1fG", meta.size / 1e9)
    elseif meta.size >= 1e6 then
      return string.format("%.1fM", meta.size / 1e6)
    elseif meta.size >= 1e3 then
      return string.format("%.1fk", meta.size / 1e3)
    else
      return string.format("%d", meta.size)
    end
  end,

  parse = function(line, conf)
    return line:match("^(%d+%S*)%s+(.*)$")
  end,
}

---@param name string
---@return nil|oil.ColumnDefinition
M.get_column = function(name)
  return ssh_columns[name]
end

---For debugging
M.open_terminal = function()
  local conn = get_connection(vim.api.nvim_buf_get_name(0))
  if conn then
    conn:open_terminal()
  end
end

---@param bufname string
---@return string
M.get_parent = function(bufname)
  local res = parse_url(bufname)
  res.path = pathutil.parent(res.path)
  return url_to_str(res)
end

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  local res = parse_url(url)
  local conn = get_connection(url, true)

  local path = res.path
  if path == "" then
    path = "."
  end

  local cmd = string.format(
    'if ! readlink -f "%s" 2>/dev/null; then [[ "%s" == /* ]] && echo "%s" || echo "$PWD/%s"; fi',
    path,
    path,
    path,
    path
  )
  conn:run(cmd, function(err, lines)
    if err then
      vim.notify(string.format("Error normalizing url %s: %s", url, err), vim.log.levels.WARN)
      return callback(url)
    end
    local abspath = table.concat(lines, "")
    if vim.endswith(abspath, ".") then
      abspath = abspath:sub(1, #abspath - 1)
    end
    abspath = util.addslash(abspath)
    if abspath == res.path then
      callback(url)
    else
      res.path = abspath
      callback(url_to_str(res))
    end
  end)
end

local dir_meta = {}

---@param url string
---@param column_defs string[]
---@param callback fun(err: nil|string, entries: nil|oil.InternalEntry[])
M.list = function(url, column_defs, callback)
  local res = parse_url(url)

  local path_postfix = ""
  if res.path ~= "" then
    path_postfix = string.format(" '%s'", res.path)
  end
  local conn = get_connection(url)
  cache.begin_update_url(url)
  local function cb(err, data)
    if err or not data then
      cache.end_update_url(url)
    end
    callback(err, data)
  end
  conn:run("ls -fl" .. path_postfix, function(err, lines)
    if err then
      if err:match("No such file or directory%s*$") then
        -- If the directory doesn't exist, treat the list as a success. We will be able to traverse
        -- and edit a not-yet-existing directory.
        return cb()
      else
        return cb(err)
      end
    end
    local any_links = false
    local entries = {}
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
          entries[name] = cache_entry
          cache_entry[FIELD.meta] = meta
          cache.store_entry(url, cache_entry)
        end
      end
    end
    if any_links then
      -- If there were any soft links, then we need to run another ls command with -L so that we can
      -- resolve the type of the link target
      conn:run("ls -fLl" .. path_postfix, function(link_err, link_lines)
        -- Ignore exit code 1. That just means one of the links could not be resolved.
        if link_err and not link_err:match("^1:") then
          return cb(link_err)
        end
        for _, line in ipairs(link_lines) do
          if line ~= "" and not line:match("^total") then
            local ok, name, type, meta = pcall(parse_ls_line, line)
            if ok and name ~= "." and name ~= ".." then
              local cache_entry = entries[name]
              if cache_entry[FIELD.type] == "link" then
                cache_entry[FIELD.meta].link_stat = {
                  type = type,
                  size = meta.size,
                }
              end
            end
          end
        end
        cb()
      end)
    else
      cb()
    end
  end)
end

---@param bufnr integer
---@return boolean
M.is_modifiable = function(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local meta = dir_meta[bufname]
  if not meta then
    -- Directories that don't exist yet are modifiable
    return true
  end
  local conn = get_connection(bufname)
  if not conn.meta.user or not conn.meta.groups then
    return false
  end
  local rwx
  if meta.user == conn.meta.user then
    rwx = bit.rshift(meta.mode, 6)
  elseif vim.tbl_contains(conn.meta.groups, meta.group) then
    rwx = bit.rshift(meta.mode, 3)
  else
    rwx = meta.mode
  end
  return bit.band(rwx, 2) ~= 0
end

---@param url string
M.url_to_buffer_name = function(url)
  local _, rem = util.parse_url(url)
  -- Let netrw handle editing files
  return "scp://" .. rem
end

---@param action oil.Action
---@return string
M.render_action = function(action)
  if action.type == "create" then
    local ret = string.format("CREATE %s", action.url)
    if action.link then
      ret = ret .. " -> " .. action.link
    end
    return ret
  elseif action.type == "delete" then
    return string.format("DELETE %s", action.url)
  elseif action.type == "move" or action.type == "copy" then
    local src = action.src_url
    local dest = action.dest_url
    if config.get_adapter_by_scheme(src) == M then
      local _, path = util.parse_url(dest)
      dest = files.to_short_os_path(path, action.entry_type)
    else
      local _, path = util.parse_url(src)
      src = files.to_short_os_path(path, action.entry_type)
    end
    return string.format("  %s %s -> %s", action.type:upper(), src, dest)
  else
    error(string.format("Bad action type: '%s'", action.type))
  end
end

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  if action.type == "create" then
    local res = parse_url(action.url)
    local conn = get_connection(action.url)
    if action.entry_type == "directory" then
      conn:run(string.format("mkdir -p '%s'", res.path), cb)
    elseif action.entry_type == "link" and action.link then
      conn:run(string.format("ln -s '%s' '%s'", action.link, res.path), cb)
    else
      conn:run(string.format("touch '%s'", res.path), cb)
    end
  elseif action.type == "delete" then
    local res = parse_url(action.url)
    local conn = get_connection(action.url)
    conn:run(string.format("rm -rf '%s'", res.path), cb)
  elseif action.type == "move" then
    local src_adapter = config.get_adapter_by_scheme(action.src_url)
    local dest_adapter = config.get_adapter_by_scheme(action.dest_url)
    if src_adapter == M and dest_adapter == M then
      local src_res = parse_url(action.src_url)
      local dest_res = parse_url(action.dest_url)
      local src_conn = get_connection(action.src_url)
      local dest_conn = get_connection(action.dest_url)
      if src_conn ~= dest_conn then
        shell.run({ "scp", "-r", url_to_scp(src_res), url_to_scp(dest_res) }, function(err)
          if err then
            return cb(err)
          end
          src_conn:run(string.format("rm -rf '%s'", src_res.path), cb)
        end)
      else
        src_conn:run(string.format("mv '%s' '%s'", src_res.path, dest_res.path), cb)
      end
    else
      cb("We should never attempt to move across adapters")
    end
  elseif action.type == "copy" then
    local src_adapter = config.get_adapter_by_scheme(action.src_url)
    local dest_adapter = config.get_adapter_by_scheme(action.dest_url)
    if src_adapter == M and dest_adapter == M then
      local src_res = parse_url(action.src_url)
      local dest_res = parse_url(action.dest_url)
      local src_conn = get_connection(action.src_url)
      local dest_conn = get_connection(action.dest_url)
      if src_conn.host ~= dest_conn.host then
        shell.run({ "scp", "-r", url_to_scp(src_res), url_to_scp(dest_res) }, cb)
      end
      src_conn:run(string.format("cp -r '%s' '%s'", src_res.path, dest_res.path), cb)
    else
      local src_arg
      local dest_arg
      if src_adapter == M then
        src_arg = url_to_scp(parse_url(action.src_url))
        local _, path = util.parse_url(action.dest_url)
        dest_arg = fs.posix_to_os_path(path)
      else
        local _, path = util.parse_url(action.src_url)
        src_arg = fs.posix_to_os_path(path)
        dest_arg = url_to_scp(parse_url(action.dest_url))
      end
      shell.run({ "scp", "-r", src_arg, dest_arg }, cb)
    end
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

M.supports_xfer = { files = true }

return M
