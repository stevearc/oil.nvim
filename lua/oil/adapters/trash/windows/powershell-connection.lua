---@class (exact) oil.PowershellCommand
---@field cmd string
---@field cb fun(err?: string, output?: string)
---@field running? boolean

---@class oil.PowershellConnection
---@field private jid integer
---@field private execution_error? string
---@field private commands oil.PowershellCommand[]
---@field private stdout string[]
---@field private is_reading_data boolean
local PowershellConnection = {}

---@param init_command? string
---@return oil.PowershellConnection
function PowershellConnection.new(init_command)
  local self = setmetatable({
    commands = {},
    stdout = {},
    is_reading_data = false,
  }, { __index = PowershellConnection })

  self:_init(init_command)

  ---@type oil.PowershellConnection
  return self
end

---@param init_command? string
function PowershellConnection:_init(init_command)
  -- For some reason beyond my understanding, at least one of the following
  -- things requires `noshellslash` to avoid the embeded powershell process to
  -- send only "" to the stdout (never calling the callback because
  -- "===DONE(True)===" is never sent to stdout)
  -- * vim.fn.jobstart
  -- * cmd.exe
  -- * powershell.exe
  local saved_shellslash = vim.o.shellslash
  vim.o.shellslash = false

  -- 65001 is the UTF-8 codepage
  -- powershell needs to be launched with the UTF-8 codepage to use it for both stdin and stdout
  local jid = vim.fn.jobstart({
    "cmd",
    "/c",
    '"chcp 65001 && powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -NoExit -Command -"',
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
  vim.o.shellslash = saved_shellslash

  if jid == 0 then
    self:_set_error("passed invalid arguments to 'powershell'")
  elseif jid == -1 then
    self:_set_error("'powershell' is not executable")
  else
    self.jid = jid
  end

  if init_command then
    table.insert(self.commands, { cmd = init_command, cb = function() end })
    self:_consume()
  end
end

---@param command string
---@param cb fun(err?: string, output?: string[])
function PowershellConnection:run(command, cb)
  if self.execution_error then
    cb(self.execution_error)
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
      -- $? contains the execution status of the last command.
      -- see https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.4#section-1
      vim.api.nvim_chan_send(self.jid, cmd.cmd .. '\nWrite-Host "===DONE($?)==="\n')
    end
  end
end

---@param err string
function PowershellConnection:_set_error(err)
  if self.execution_error then
    return
  end
  self.execution_error = err
  local commands = self.commands
  self.commands = {}
  for _, cmd in ipairs(commands) do
    cmd.cb(err)
  end
end

return PowershellConnection
