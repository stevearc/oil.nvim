local config = require("oil.config")
local constants = require("oil.constants")
local files = require("oil.adapters.files")
local fs = require("oil.fs")
local loading = require("oil.loading")
local pathutil = require("oil.pathutil")
local permissions = require("oil.adapters.files.permissions")
local shell = require("oil.shell")
local sshfs = require("oil.adapters.ssh.sshfs")
local util = require("oil.util")
local M = {}

local FIELD_NAME = constants.FIELD_NAME
local FIELD_META = constants.FIELD_META

---@class (exact) oil.sshUrl
---@field scheme string
---@field host string
---@field user nil|string
---@field port nil|integer
---@field path string

---@param args string[]
local function scp(args, ...)
  local cmd = vim.list_extend({ "scp", "-C" }, config.extra_scp_args)
  vim.list_extend(cmd, args)
  shell.run(cmd, ...)
end

---@param oil_url string
---@return oil.sshUrl
M.parse_url = function(oil_url)
  local scheme, url = util.parse_url(oil_url)
  assert(scheme and url, string.format("Malformed input url '%s'", oil_url))
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

  ---@cast ret oil.sshUrl
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

---@param url1 oil.sshUrl
---@param url2 oil.sshUrl
---@return boolean
local function url_hosts_equal(url1, url2)
  return url1.host == url2.host and url1.port == url2.port and url1.user == url2.user
end

local _connections = {}
---@param url string
---@param allow_retry nil|boolean
---@return oil.sshFs
local function get_connection(url, allow_retry)
  local res = M.parse_url(url)
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
    return meta and permissions.mode_to_str(meta.mode)
  end,

  parse = function(line, conf)
    return permissions.parse(line)
  end,

  compare = function(entry, parsed_value)
    local meta = entry[FIELD_META]
    if parsed_value and meta and meta.mode then
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
    local res = M.parse_url(action.url)
    local conn = get_connection(action.url)
    conn:chmod(action.value, res.path, callback)
  end,
}

ssh_columns.size = {
  render = function(entry, conf)
    local meta = entry[FIELD_META]
    if not meta or not meta.size then
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

  get_sort_value = function(entry)
    local meta = entry[FIELD_META]
    if meta and meta.size then
      return meta.size
    else
      return 0
    end
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
  local res = M.parse_url(bufname)
  res.path = pathutil.parent(res.path)
  return url_to_str(res)
end

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  local res = M.parse_url(url)
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
---@param callback fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, callback)
  local res = M.parse_url(url)

  local conn = get_connection(url)
  conn:list_dir(url, res.path, callback)
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
      assert(path)
      dest = files.to_short_os_path(path, action.entry_type)
    else
      local _, path = util.parse_url(src)
      assert(path)
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
    local res = M.parse_url(action.url)
    local conn = get_connection(action.url)
    if action.entry_type == "directory" then
      conn:mkdir(res.path, cb)
    elseif action.entry_type == "link" and action.link then
      conn:mklink(res.path, action.link, cb)
    else
      conn:touch(res.path, cb)
    end
  elseif action.type == "delete" then
    local res = M.parse_url(action.url)
    local conn = get_connection(action.url)
    conn:rm(res.path, cb)
  elseif action.type == "move" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if src_adapter == M and dest_adapter == M then
      local src_res = M.parse_url(action.src_url)
      local dest_res = M.parse_url(action.dest_url)
      local src_conn = get_connection(action.src_url)
      local dest_conn = get_connection(action.dest_url)
      if src_conn ~= dest_conn then
        scp({ "-r", url_to_scp(src_res), url_to_scp(dest_res) }, function(err)
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
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if src_adapter == M and dest_adapter == M then
      local src_res = M.parse_url(action.src_url)
      local dest_res = M.parse_url(action.dest_url)
      if not url_hosts_equal(src_res, dest_res) then
        scp({ "-r", url_to_scp(src_res), url_to_scp(dest_res) }, cb)
      else
        local src_conn = get_connection(action.src_url)
        src_conn:cp(src_res.path, dest_res.path, cb)
      end
    else
      local src_arg
      local dest_arg
      if src_adapter == M then
        src_arg = url_to_scp(M.parse_url(action.src_url))
        local _, path = util.parse_url(action.dest_url)
        assert(path)
        dest_arg = fs.posix_to_os_path(path)
      else
        local _, path = util.parse_url(action.src_url)
        assert(path)
        src_arg = fs.posix_to_os_path(path)
        dest_arg = url_to_scp(M.parse_url(action.dest_url))
      end
      scp({ "-r", src_arg, dest_arg }, cb)
    end
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

M.supported_cross_adapter_actions = { files = "copy" }

---@param bufnr integer
M.read_file = function(bufnr)
  loading.set_loading(bufnr, true)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local url = M.parse_url(bufname)
  local scp_url = url_to_scp(url)
  local basename = pathutil.basename(bufname)
  local cache_dir = vim.fn.stdpath("cache")
  assert(type(cache_dir) == "string")
  local tmpdir = fs.join(cache_dir, "oil")
  fs.mkdirp(tmpdir)
  local fd, tmpfile = vim.loop.fs_mkstemp(fs.join(tmpdir, "ssh_XXXXXX"))
  if fd then
    vim.loop.fs_close(fd)
  end
  local tmp_bufnr = vim.fn.bufadd(tmpfile)

  scp({ scp_url, tmpfile }, function(err)
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
    local filetype = vim.filetype.match({ buf = bufnr, filename = basename })
    if filetype then
      vim.bo[bufnr].filetype = filetype
    end
    vim.cmd.doautocmd({ args = { "BufReadPost", bufname }, mods = { silent = true } })
    vim.api.nvim_buf_delete(tmp_bufnr, { force = true })
    vim.keymap.set("n", "gf", M.goto_file, { buffer = bufnr })
  end)
end

---@param bufnr integer
M.write_file = function(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local url = M.parse_url(bufname)
  local scp_url = url_to_scp(url)
  local cache_dir = vim.fn.stdpath("cache")
  assert(type(cache_dir) == "string")
  local tmpdir = fs.join(cache_dir, "oil")
  local fd, tmpfile = vim.loop.fs_mkstemp(fs.join(tmpdir, "ssh_XXXXXXXX"))
  if fd then
    vim.loop.fs_close(fd)
  end
  vim.cmd.doautocmd({ args = { "BufWritePre", bufname }, mods = { silent = true } })
  vim.bo[bufnr].modifiable = false
  vim.cmd.write({ args = { tmpfile }, bang = true, mods = { silent = true, noautocmd = true } })
  local tmp_bufnr = vim.fn.bufadd(tmpfile)

  scp({ tmpfile, scp_url }, function(err)
    vim.bo[bufnr].modifiable = true
    if err then
      vim.notify(string.format("Error writing file: %s", err), vim.log.levels.ERROR)
    else
      vim.bo[bufnr].modified = false
      vim.cmd.doautocmd({ args = { "BufWritePost", bufname }, mods = { silent = true } })
    end
    vim.loop.fs_unlink(tmpfile)
    vim.api.nvim_buf_delete(tmp_bufnr, { force = true })
  end)
end

M.goto_file = function()
  local url = M.parse_url(vim.api.nvim_buf_get_name(0))
  local fname = vim.fn.expand("<cfile>")
  local fullpath = fname
  if not fs.is_absolute(fname) then
    local pardir = vim.fs.dirname(url.path)
    fullpath = fs.join(pardir, fname)
  end
  url.path = vim.fs.dirname(fullpath)
  local parurl = url_to_str(url)

  ---@cast M oil.Adapter
  util.adapter_list_all(M, parurl, {}, function(err, entries)
    if err then
      vim.notify(string.format("Error finding file '%s': %s", fname, err), vim.log.levels.ERROR)
      return
    end
    assert(entries)
    local name_map = {}
    for _, entry in ipairs(entries) do
      name_map[entry[FIELD_NAME]] = entry
    end

    local basename = vim.fs.basename(fullpath)
    if name_map[basename] then
      url.path = fullpath
      vim.cmd.edit({ args = { url_to_str(url) } })
      return
    end
    for suffix in vim.gsplit(vim.o.suffixesadd, ",", { plain = true, trimempty = true }) do
      local suffixname = basename .. suffix
      if name_map[suffixname] then
        url.path = fullpath .. suffix
        vim.cmd.edit({ args = { url_to_str(url) } })
        return
      end
    end
    vim.notify(string.format("Can't find file '%s'", fname), vim.log.levels.ERROR)
  end)
end

return M
