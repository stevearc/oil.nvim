---@class oil.Ringbuf
---@field private size integer
---@field private tail integer
---@field private buf string[]
local Ringbuf = {}
function Ringbuf.new(size)
  local self = setmetatable({
    size = size,
    buf = {},
    tail = 0,
  }, { __index = Ringbuf })
  return self
end

---@param val string
function Ringbuf:push(val)
  self.tail = self.tail + 1
  if self.tail > self.size then
    self.tail = 1
  end
  self.buf[self.tail] = val
end

---@return string
function Ringbuf:as_str()
  local postfix = ""
  for i = 1, self.tail, 1 do
    postfix = postfix .. self.buf[i]
  end
  local prefix = ""
  for i = self.tail + 1, #self.buf, 1 do
    prefix = prefix .. self.buf[i]
  end
  return prefix .. postfix
end

return Ringbuf
