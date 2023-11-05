local M = {}

---@param path string
---@return string
M.parent = function(path)
  if path == "/" then
    return "/"
  elseif path == "" then
    return ""
  elseif vim.endswith(path, "/") then
    return path:match("^(.*/)[^/]*/$") or ""
  else
    return path:match("^(.*/)[^/]*$") or ""
  end
end

---@param path string
---@return nil|string
M.basename = function(path)
  if path == "/" or path == "" then
    return
  elseif vim.endswith(path, "/") then
    return path:match("^.*/([^/]*)/$")
  else
    return path:match("^.*/([^/]*)$")
  end
end

return M
