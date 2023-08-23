local fs = require("oil.fs")

if fs.is_mac then
  return require("oil.adapters.trash.mac")
elseif fs.is_windows then
  error("Trash is not implemented yet on Windows")
else
  return require("oil.adapters.trash.freedesktop")
end
