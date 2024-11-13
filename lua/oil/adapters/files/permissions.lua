local M = {}

---@param exe_modifier false|string
---@param num integer
---@return string
local function perm_to_str(exe_modifier, num)
  local str = (bit.band(num, 4) ~= 0 and "r" or "-") .. (bit.band(num, 2) ~= 0 and "w" or "-")
  if exe_modifier then
    if bit.band(num, 1) ~= 0 then
      return str .. exe_modifier
    else
      return str .. exe_modifier:upper()
    end
  else
    return str .. (bit.band(num, 1) ~= 0 and "x" or "-")
  end
end

---@param mode integer
---@return string
M.mode_to_str = function(mode)
  local extra = bit.rshift(mode, 9)
  return perm_to_str(bit.band(extra, 4) ~= 0 and "s", bit.rshift(mode, 6))
    .. perm_to_str(bit.band(extra, 2) ~= 0 and "s", bit.rshift(mode, 3))
    .. perm_to_str(bit.band(extra, 1) ~= 0 and "t", mode)
end

---@param mode integer
---@return string
M.mode_to_octal_str = function(mode)
  local mask = 7
  return tostring(bit.band(mask, bit.rshift(mode, 9)))
    .. tostring(bit.band(mask, bit.rshift(mode, 6)))
    .. tostring(bit.band(mask, bit.rshift(mode, 3)))
    .. tostring(bit.band(mask, mode))
end

---@param str string String of 3 characters
---@return nil|integer
local function str_to_mode(str)
  local r, w, x = unpack(vim.split(str, "", {}))
  local mode = 0
  if r == "r" then
    mode = bit.bor(mode, 4)
  elseif r ~= "-" then
    return nil
  end
  if w == "w" then
    mode = bit.bor(mode, 2)
  elseif w ~= "-" then
    return nil
  end
  -- t means sticky and executable
  -- T means sticky, not executable
  -- s means setuid/setgid and executable
  -- S means setuid/setgid and not executable
  if x == "x" or x == "t" or x == "s" then
    mode = bit.bor(mode, 1)
  elseif x ~= "-" and x ~= "T" and x ~= "S" then
    return nil
  end
  return mode
end

---@param perm string
---@return integer
local function parse_extra_bits(perm)
  perm = perm:lower()
  local mode = 0
  if perm:sub(3, 3) == "s" then
    mode = bit.bor(mode, 4)
  end
  if perm:sub(6, 6) == "s" then
    mode = bit.bor(mode, 2)
  end
  if perm:sub(9, 9) == "t" then
    mode = bit.bor(mode, 1)
  end
  return mode
end

---@param line string
---@return nil|integer
---@return nil|string
M.parse = function(line)
  local strval, rem = line:match("^([r%-][w%-][xsS%-][r%-][w%-][xsS%-][r%-][w%-][xtT%-])%s*(.*)$")
  if not strval then
    return
  end
  local user_mode = str_to_mode(strval:sub(1, 3))
  local group_mode = str_to_mode(strval:sub(4, 6))
  local any_mode = str_to_mode(strval:sub(7, 9))
  local extra = parse_extra_bits(strval)
  if not user_mode or not group_mode or not any_mode then
    return
  end
  local mode = bit.bor(bit.lshift(user_mode, 6), bit.lshift(group_mode, 3))
  mode = bit.bor(mode, any_mode)
  mode = bit.bor(mode, bit.lshift(extra, 9))
  return mode, rem
end

return M
