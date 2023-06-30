local cache = require("oil.cache")
local config = require("oil.config")
local constants = require("oil.constants")
local fs = require("oil.fs")
local files = require("oil.adapters.files")
local loading = require("oil.loading")
local permissions = require("oil.adapters.files.permissions")
local sshfs = require("oil.adapters.ssh.sshfs")
local pathutil = require("oil.pathutil")
local shell = require("oil.shell")
local util = require("oil.util")
local M = {}

local FIELD_META = constants.FIELD_META

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
  local escaped_path = util.url_escape(url.path)
  table.insert(pieces, escaped_path)
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
  if not conn or (allow_retry and conn:get_connection_error()) then
    conn = sshfs.new(res)
    _connections[key] = conn
  end
  return conn
end

local ssh_columns = {}
ssh_columns.permissions = {
  render = function(entry, conf)
    local meta = entry[FIELD_META]
    return permissions.mode_to_str(meta.mode)
  end,

  parse = function(line, conf)
    return permissions.parse(line)
  end,

  compare = function(entry, parsed_value)
    local meta = entry[FIELD_META]
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
    conn:chmod(action.value, res.path, callback)
  end,
}

ssh_columns.size = {
  render = function(entry, conf)
    local meta = entry[FIELD_META]
    if not meta.size then
      return ""
    elseif meta.size >= 1e9 then
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

  conn:realpath(path, function(err, abspath)
    if err then
      vim.notify(string.format("Error normalizing url %s: %s", url, err), vim.log.levels.WARN)
      callback(url)
    else
      res.path = abspath
      callback(url_to_str(res))
    end
  end)
end

---@param url string
---@param column_defs string[]
---@param callback fun(err: nil|string, entries: nil|oil.InternalEntry[])
M.list = function(url, column_defs, callback)
  local res = parse_url(url)

  cache.begin_update_url(url)
  local conn = get_connection(url)
  conn:list_dir(url, res.path, function(err, data)
    if err or not data then
      cache.end_update_url(url)
    end
    callback(err, data)
  end)
end

---@param bufnr integer
---@return boolean
M.is_modifiable = function(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local conn = get_connection(bufname)
  local dir_meta = conn:get_dir_meta(bufname)
  if not dir_meta then
    -- Directories that don't exist yet are modifiable
    return true
  end
  local meta = conn:get_meta()
  if not meta.user or not meta.groups then
    return false
  end
  local rwx
  if dir_meta.user == meta.user then
    rwx = bit.rshift(dir_meta.mode, 6)
  elseif vim.tbl_contains(meta.groups, dir_meta.group) then
    rwx = bit.rshift(dir_meta.mode, 3)
  else
    rwx = dir_meta.mode
  end
  return bit.band(rwx, 2) ~= 0
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
      conn:mkdir(res.path, cb)
    elseif action.entry_type == "link" and action.link then
      conn:mklink(res.path, action.link, cb)
    else
      conn:touch(res.path, cb)
    end
  elseif action.type == "delete" then
    local res = parse_url(action.url)
    local conn = get_connection(action.url)
    conn:rm(res.path, cb)
  elseif action.type == "move" then
    local src_adapter = config.get_adapter_by_scheme(action.src_url)
    local dest_adapter = config.get_adapter_by_scheme(action.dest_url)
    if src_adapter == M and dest_adapter == M then
      local src_res = parse_url(action.src_url)
      local dest_res = parse_url(action.dest_url)
      local src_conn = get_connection(action.src_url)
      local dest_conn = get_connection(action.dest_url)
      if src_conn ~= dest_conn then
        shell.run({ "scp", "-C", "-r", url_to_scp(src_res), url_to_scp(dest_res) }, function(err)
          if err then
            return cb(err)
          end
          src_conn:rm(src_res.path, cb)
        end)
      else
        src_conn:mv(src_res.path, dest_res.path, cb)
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
        shell.run({ "scp", "-C", "-r", url_to_scp(src_res), url_to_scp(dest_res) }, cb)
      end
      src_conn:cp(src_res.path, dest_res.path, cb)
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
      shell.run({ "scp", "-C", "-r", src_arg, dest_arg }, cb)
    end
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

M.supports_xfer = { files = true }

---@param bufnr integer
M.read_file = function(bufnr)
  loading.set_loading(bufnr, true)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local url = parse_url(bufname)
  local scp_url = url_to_scp(url)
  local basename = pathutil.basename(bufname)
  local tmpdir = fs.join(vim.fn.stdpath("cache"), "oil")
  fs.mkdirp(tmpdir)
  local fd, tmpfile = vim.loop.fs_mkstemp(fs.join(tmpdir, "ssh_XXXXXX"))
  vim.loop.fs_close(fd)
  local tmp_bufnr = vim.fn.bufadd(tmpfile)

  shell.run({ "scp", "-C", scp_url, tmpfile }, function(err)
    loading.set_loading(bufnr, false)
    vim.bo[bufnr].modifiable = true
    vim.cmd.doautocmd({ args = { "BufReadPre", bufname }, mods = { silent = true } })
    if err then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.split(err, "\n"))
    else
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, {})
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd.read({ args = { tmpfile }, mods = { silent = true } })
      end)
      vim.loop.fs_unlink(tmpfile)
      vim.api.nvim_buf_set_lines(bufnr, 0, 1, true, {})
    end
    vim.bo[bufnr].modified = false
    vim.bo[bufnr].filetype = vim.filetype.match({ buf = bufnr, filename = basename })
    vim.cmd.doautocmd({ args = { "BufReadPost", bufname }, mods = { silent = true } })
    vim.api.nvim_buf_delete(tmp_bufnr, { force = true })
  end)
end

---@param bufnr integer
M.write_file = function(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  vim.bo[bufnr].modifiable = false
  local url = parse_url(bufname)
  local scp_url = url_to_scp(url)
  local tmpdir = fs.join(vim.fn.stdpath("cache"), "oil")
  local fd, tmpfile = vim.loop.fs_mkstemp(fs.join(tmpdir, "ssh_XXXXXXXX"))
  vim.loop.fs_close(fd)
  vim.cmd.doautocmd({ args = { "BufWritePre", bufname }, mods = { silent = true } })
  vim.cmd.write({ args = { tmpfile }, bang = true, mods = { silent = true } })
  local tmp_bufnr = vim.fn.bufadd(tmpfile)

  shell.run({ "scp", "-C", tmpfile, scp_url }, function(err)
    if err then
      vim.notify(string.format("Error writing file: %s", err), vim.log.levels.ERROR)
    end
    vim.bo[bufnr].modifiable = true
    vim.bo[bufnr].modified = false
    vim.cmd.doautocmd({ args = { "BufWritePost", bufname }, mods = { silent = true } })
    vim.loop.fs_unlink(tmpfile)
    vim.api.nvim_buf_delete(tmp_bufnr, { force = true })
  end)
end

return M
