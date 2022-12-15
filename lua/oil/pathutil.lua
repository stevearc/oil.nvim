local fs = require("oil.fs")
local M = {}

---@param path string
---@return string
M.parent = function(path)
  -- Do I love this hack? No I do not.
  -- Does it work? Yes. Mostly. For now.
  if fs.is_windows then
    if path:match("^/%a+/?$") then
      return path
    end
  end
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
