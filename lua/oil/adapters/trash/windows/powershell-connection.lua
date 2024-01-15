---@class (exact) oil.PowershellCommand
---@field cmd string
---@field cb fun(err?: string, output?: string)
---@field running? boolean

---@class oil.PowershellConnection
---@field private jid integer
---@field commands oil.PowershellCommand[]
---@field stdout string[]
---@field is_reading_data boolean
local PowershellConnection = {}

---@return oil.PowershellConnection
function PowershellConnection.new()
  local self = setmetatable({
    commands = {},
    stdout = {},
    is_reading_data = false,
  }, { __index = PowershellConnection })

  local jid = vim.fn.jobstart({
    "powershell",
    "-NoProfile",
    "-NoLogo",
    "-ExecutionPolicy",
    "Bypass",
    "-NoExit",
    "-Command",
    "-",
  }, {
    ---@param data string[]
    on_stdout = function(_, data)
      for _, fragment in ipairs(data) do
        if fragment:find("===DONE%((%a+)%)===") then
          self.is_reading_data = false
          local output = table.concat(self.stdout, "")
          local cb = self.commands[1].cb
          table.remove(self.commands, 1)
          local success = fragment:match("===DONE%((%a+)%)===")
          if success == "True" then
            cb(nil, output)
          elseif success == "False" then
            cb(success .. ": " .. output, output)
          end
          self.stdout = {}
          self:_consume()
        elseif self.is_reading_data then
          table.insert(self.stdout, fragment)
        end
      end
    end,
  })

  if jid == 0 then
    self:_set_connection_error("passed invalid arguments to 'powershell'")
  elseif jid == -1 then
    self:_set_connection_error("'powershell' is not executable")
  else
    self.jid = jid
  end

  return self
end

---@param command string
---@param cb fun(err?: string, output?: string[])
function PowershellConnection:run(command, cb)
  if self.connection_error then
    cb(self.connection_error)
  else
    table.insert(self.commands, { cmd = command, cb = cb })
    self:_consume()
  end
end

function PowershellConnection:_consume()
  if not vim.tbl_isempty(self.commands) then
    local cmd = self.commands[1]
    if not cmd.running then
      cmd.running = true
      self.is_reading_data = true
      vim.api.nvim_chan_send(self.jid, cmd.cmd .. '\nWrite-Host "===DONE($?)==="\n')
    end
  end
end

---@param err string
function PowershellConnection:_set_connection_error(err)
  if self.connection_error then
    return
  end
  self.connection_error = err
  local commands = self.commands
  self.commands = {}
  for _, cmd in ipairs(commands) do
    cmd.cb(err)
  end
end

return PowershellConnection
