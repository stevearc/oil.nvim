local fs = require("oil.fs")

if fs.is_mac then
  return require("oil.adapters.trash.mac")
elseif fs.is_windows then
  return require("oil.adapters.trash.windows")
else
  return require("oil.adapters.trash.freedesktop")
end
