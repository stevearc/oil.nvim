local config = require("oil.config")
local constants = require("oil.constants")
local files = require("oil.adapters.files")
local fs = require("oil.fs")
local loading = require("oil.loading")
local pathutil = require("oil.pathutil")
local s3fs = require("oil.adapters.s3.s3fs")
local util = require("oil.util")
local M = {}

local FIELD_META = constants.FIELD_META

---@class (exact) oil.s3Url
---@field scheme string
---@field bucket nil|string
---@field path nil|string



---@param oil_url string
---@return oil.s3Url
M.parse_url = function(oil_url)
  local scheme, url = util.parse_url(oil_url)
  assert(scheme and url, string.format("Malformed input url '%s'", oil_url))
  local ret = { scheme = scheme }
  local bucket, path = url:match("^([^/]+)/?(.*)$")
  ret.bucket = bucket
  ret.path = path
  if not ret.bucket and ret.path then
    error(string.format("Parsing error for s3 url: %s", oil_url))
  end
  ---@cast ret oil.s3Url
  return ret
end

---@param url oil.s3Url
---@return string
local function url_to_str(url)
  local pieces = { url.scheme }
  if url.bucket then
    table.insert(pieces, url.bucket)
    table.insert(pieces, "/")
  end
  if url.path then
    local path = url.path
    -- paths ending with "/-" are usually used for an "empty folder" in s3
    if path and vim.endswith(path, "/-") then
      path = path:sub(1, #path - 1)
    end

    table.insert(pieces, path)
  end
  return table.concat(pieces, "")
end

---@param url oil.s3Url
---@param is_folder boolean
---@return string
local function url_to_s3(url, is_folder)
  local pieces = { "s3://" }
  if url.bucket then
    table.insert(pieces, url.bucket)
    table.insert(pieces, "/")
  end
  if url.path and url.path ~= "" then
    table.insert(pieces, url.path)
    if is_folder and not vim.endswith(url.path, "/") then
      table.insert(pieces, "/")
    end
  end
  return table.concat(pieces, "")
end

local s3_columns = {}
s3_columns.size = {
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
  return s3_columns[name]
end

---@param bufname string
---@return string
M.get_parent = function(bufname)
  local res = M.parse_url(bufname)
  if res.path then
    res.path = pathutil.parent(res.path)
  elseif res.bucket then
    res.bucket = nil
  end
  return url_to_str(res)
end

---@param url string
---@param callback fun(url: string)
M.normalize_url = function(url, callback)
  local res = M.parse_url(url)
  callback(url_to_str(res))
end

---@param url string
---@param column_defs string[]
---@param callback fun(err?: string, entries?: oil.InternalEntry[], fetch_more?: fun())
M.list = function(url, column_defs, callback)
  local res = M.parse_url(url)

  local s3 = s3fs.new()
  s3:list_dir(url, url_to_s3(res, true), callback)
end

---@param bufnr integer
---@return boolean
M.is_modifiable = function(bufnr)
  -- default assumption is that everything is modifiable
  return true
end

---@param action oil.Action
---@return string
M.render_action = function(action)
  if action.type == "create" then
    local extra = action.type == "bucket" and "BUCKET " or ""
    return string.format("CREATE %s%s", extra, action.url)
  elseif action.type == "delete" then
    local extra = action.type == "bucket" and "BUCKET " or ""
    return string.format("DELETE %s%s", extra, action.url)
  elseif action.type == "move" or action.type == "copy" then
    local src = action.src_url
    local dest = action.dest_url
    if config.get_adapter_by_scheme(src) ~= M then
      local _, path = util.parse_url(src)
      assert(path)
      src = files.to_short_os_path(path, action.entry_type)
    elseif config.get_adapter_by_scheme(dest) ~= M then
      local _, path = util.parse_url(dest)
      assert(path)
      dest = files.to_short_os_path(path, action.entry_type)
    end
    return string.format("  %s %s -> %s", action.type:upper(), src, dest)
  else
    error(string.format("Bad action type: '%s'", action.type))
  end
end

---@param action oil.Action
---@param cb fun(err: nil|string)
M.perform_action = function(action, cb)
  local is_folder = action.entry_type == "directory" or action.entry_type == "bucket"
  if action.type == "create" then
    local res = M.parse_url(action.url)
    local s3 = s3fs.new()

    if action.entry_type == "directory" or action.entry_type == "file" then
      s3:touch(url_to_s3(res, is_folder), cb)
    elseif action.entry_type == "bucket" then
      s3:mb(url_to_s3(res, true), cb)
    else
      cb(string.format("Bad entry type on s3 create action: %s", action.entry_type))
    end
  elseif action.type == "delete" then
    local res = M.parse_url(action.url)
    local s3 = s3fs.new()

    if action.entry_type == "directory" or action.entry_type == "file" then
      s3:rm(url_to_s3(res, is_folder), is_folder, cb)
    elseif action.entry_type == "bucket" then
      s3:rb(url_to_s3(res, true), cb)
    else
      cb(string.format("Bad entry type on s3 delete action: %s", action.entry_type))
    end
  elseif action.type == "move" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if (src_adapter ~= M and src_adapter ~= files) or (dest_adapter ~= M or dest_adapter ~= files) then
      cb(string.format(
        "We should never attempt to move from the %s adapter to the %s adapter.",
        src_adapter.name,
        dest_adapter.name
      ))
    end

    local src
    if src_adapter == M then
      local src_res = M.parse_url(action.src_url)
      src = url_to_s3(src_res, is_folder)
    else
      _, src = util.parse_url(action.src_url)
    end
    assert(src)

    local dest
    if dest_adapter == M then
      local dest_res = M.parse_url(action.dest_url)
      dest = url_to_s3(dest_res, is_folder)
    else
      _, dest = util.parse_url(action.dest_url)
    end
    assert(dest)

    local s3 = s3fs.new()
    s3:mv(src, dest, is_folder, cb)
  elseif action.type == "copy" then
    local src_adapter = assert(config.get_adapter_by_scheme(action.src_url))
    local dest_adapter = assert(config.get_adapter_by_scheme(action.dest_url))
    if (src_adapter ~= M and src_adapter ~= files) or (dest_adapter ~= M or dest_adapter ~= files) then
      cb(string.format(
        "We should never attempt to copy from the %s adapter to the %s adapter.",
        src_adapter.name,
        dest_adapter.name
      ))
    end

    local src
    if src_adapter == M then
      local src_res = M.parse_url(action.src_url)
      src = url_to_s3(src_res, is_folder)
    else
      _, src = util.parse_url(action.src_url)
    end
    assert(src)

    local dest
    if dest_adapter == M then
      local dest_res = M.parse_url(action.dest_url)
      dest = url_to_s3(dest_res, is_folder)
    else
      _, dest = util.parse_url(action.dest_url)
    end
    assert(dest)

    local s3 = s3fs.new()
    s3:cp(src, dest, is_folder, cb)
  else
    cb(string.format("Bad action type: %s", action.type))
  end
end

M.supported_cross_adapter_actions = { files = "all" }

---@param bufnr integer
M.read_file = function(bufnr)
  loading.set_loading(bufnr, true)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local url = M.parse_url(bufname)
  local basename = pathutil.basename(bufname)
  local cache_dir = vim.fn.stdpath("cache")
  assert(type(cache_dir) == "string")
  local tmpdir = fs.join(cache_dir, "oil")
  fs.mkdirp(tmpdir)
  local fd, tmpfile = vim.loop.fs_mkstemp(fs.join(tmpdir, "s3_XXXXXX"))
  if fd then
    vim.loop.fs_close(fd)
  end
  local tmp_bufnr = vim.fn.bufadd(tmpfile)

  local s3 = s3fs.new()
  s3:cp(url_to_s3(url, false), tmpfile, false, function(err)
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

    -- TODO: Add M.goto_file similar to ssh
    -- vim.keymap.set("n", "gf", M.goto_file, { buffer = bufnr })
  end)
end

---@param bufnr integer
M.write_file = function(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local url = M.parse_url(bufname)
  local cache_dir = vim.fn.stdpath("cache")
  assert(type(cache_dir) == "string")
  local tmpdir = fs.join(cache_dir, "oil")
  local fd, tmpfile = vim.loop.fs_mkstemp(fs.join(tmpdir, "s3_XXXXXXXX"))
  if fd then
    vim.loop.fs_close(fd)
  end
  vim.cmd.doautocmd({ args = { "BufWritePre", bufname }, mods = { silent = true } })
  vim.bo[bufnr].modifiable = false
  vim.cmd.write({ args = { tmpfile }, bang = true, mods = { silent = true, noautocmd = true } })
  local tmp_bufnr = vim.fn.bufadd(tmpfile)

  local s3 = s3fs.new()
  s3:cp(tmpfile, url_to_s3(url, false), false, function(err)
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

return M
