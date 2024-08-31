local config = require("oil.config")
local layout = require("oil.layout")
local util = require("oil.util")

---@class (exact) oil.sshCommand
---@field cmd string|string[]
---@field cb fun(err?: string, output?: string[])
---@field running? boolean

---@class (exact) oil.sshConnection
---@field new fun(url: oil.sshUrl): oil.sshConnection
---@field create_ssh_command fun(url: oil.sshUrl): string[]
---@field meta {user?: string, groups?: string[]}
---@field connection_error nil|string
---@field connected boolean
---@field private term_bufnr integer
---@field private jid integer
---@field private term_winid nil|integer
---@field private commands oil.sshCommand[]
---@field private _stdout string[]
local SSHConnection = {}

local function output_extend(agg, output)
  local start = #agg
  if vim.tbl_isempty(agg) then
    for _, line in ipairs(output) do
      line = line:gsub("\r", "")
      table.insert(agg, line)
    end
  else
    for i, v in ipairs(output) do
      v = v:gsub("\r", "")
      if i == 1 then
        agg[#agg] = agg[#agg] .. v
      else
        table.insert(agg, v)
      end
    end
  end
  return start
end

---@param bufnr integer
---@param num_lines integer
---@return string[]
local function get_last_lines(bufnr, num_lines)
  local end_line = vim.api.nvim_buf_line_count(bufnr)
  num_lines = math.min(num_lines, end_line)
  local lines = {}
  while end_line > 0 and #lines < num_lines do
    local need_lines = num_lines - #lines
    lines = vim.list_extend(
      vim.api.nvim_buf_get_lines(bufnr, end_line - need_lines, end_line, false),
      lines
    )
    while not vim.tbl_isempty(lines) and lines[#lines]:match("^%s*$") do
      table.remove(lines)
    end
    end_line = end_line - need_lines
  end
  return lines
end

---@param url oil.sshUrl
---@return string[]
function SSHConnection.create_ssh_command(url)
  local host = url.host
  if url.user then
    host = url.user .. "@" .. host
  end
  local command = {
    "ssh",
    host,
  }
  if url.port then
    table.insert(command, "-p")
    table.insert(command, url.port)
  end
  return command
end

---@param url oil.sshUrl
---@return oil.sshConnection
function SSHConnection.new(url)
  local command = SSHConnection.create_ssh_command(url)
  vim.list_extend(command, {
    "/bin/sh",
    "-c",
    -- HACK: For some reason in my testing if I just have "echo READY" it doesn't appear, but if I echo
    -- anything prior to that, it *will* appear. The first line gets swallowed.
    "echo '_make_newline_'; echo '===READY==='; exec /bin/sh",
  })
  local term_bufnr = vim.api.nvim_create_buf(false, true)
  local self = setmetatable({
    meta = {},
    commands = {},
    connected = false,
    connection_error = nil,
    term_bufnr = term_bufnr,
  }, {
    __index = SSHConnection,
  })

  local term_id
  local mode = vim.api.nvim_get_mode().mode
  util.run_in_fullscreen_win(term_bufnr, function()
    term_id = vim.api.nvim_open_term(term_bufnr, {
      on_input = function(_, _, _, data)
        ---@diagnostic disable-next-line: invisible
        pcall(vim.api.nvim_chan_send, self.jid, data)
      end,
    })
  end)
  self.term_id = term_id
  vim.api.nvim_chan_send(term_id, string.format("ssh %s\r\n", url.host))
  util.hack_around_termopen_autocmd(mode)

  -- If it takes more than 2 seconds to connect, pop open the terminal
  vim.defer_fn(function()
    if not self.connected and not self.connection_error then
      self:open_terminal()
    end
  end, 2000)
  self._stdout = {}
  local jid = vim.fn.jobstart(command, {
    pty = true, -- This is require for interactivity
    on_stdout = function(j, output)
      pcall(vim.api.nvim_chan_send, self.term_id, table.concat(output, "\r\n"))
      ---@diagnostic disable-next-line: invisible
      local new_i_start = output_extend(self._stdout, output)
      self:_handle_output(new_i_start)
    end,
    on_exit = function(j, code)
      pcall(
        vim.api.nvim_chan_send,
        self.term_id,
        string.format("\r\n[Process exited %d]\r\n", code)
      )
      -- Defer to allow the deferred terminal output handling to kick in first
      vim.defer_fn(function()
        if code == 0 then
          self:_set_connection_error("SSH connection terminated gracefully")
        else
          self:_set_connection_error(
            'Unknown SSH error\nTo see more, run :lua require("oil.adapters.ssh").open_terminal()'
          )
        end
      end, 20)
    end,
  })
  local exe = command[1]
  if jid == 0 then
    self:_set_connection_error(string.format("Passed invalid arguments to '%s'", exe))
  elseif jid == -1 then
    self:_set_connection_error(string.format("'%s' is not executable", exe))
  else
    self.jid = jid
  end
  self:run("id -u", function(err, lines)
    if err then
      vim.notify(string.format("Error fetching ssh connection user: %s", err), vim.log.levels.WARN)
    else
      assert(lines)
      self.meta.user = vim.trim(table.concat(lines, ""))
    end
  end)
  self:run("id -G", function(err, lines)
    if err then
      vim.notify(
        string.format("Error fetching ssh connection user groups: %s", err),
        vim.log.levels.WARN
      )
    else
      assert(lines)
      self.meta.groups = vim.split(table.concat(lines, ""), "%s+", { trimempty = true })
    end
  end)

  ---@cast self oil.sshConnection
  return self
end

---@param err string
function SSHConnection:_set_connection_error(err)
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

function SSHConnection:_handle_output(start_i)
  if not self.connected then
    for i = start_i, #self._stdout - 1 do
      local line = self._stdout[i]
      if line == "===READY===" then
        if self.term_winid then
          if vim.api.nvim_win_is_valid(self.term_winid) then
            vim.api.nvim_win_close(self.term_winid, true)
          end
          self.term_winid = nil
        end
        self.connected = true
        self._stdout = util.tbl_slice(self._stdout, i + 1)
        self:_handle_output(1)
        self:_consume()
        return
      end
    end
  else
    for i = start_i, #self._stdout - 1 do
      ---@type string
      local line = self._stdout[i]
      if line:match("^===BEGIN===%s*$") then
        self._stdout = util.tbl_slice(self._stdout, i + 1)
        self:_handle_output(1)
        return
      end
      -- We can't be as strict with the matching (^$) because since we're using a pty the stdout and
      -- stderr can be interleaved. If the command had an error, the stderr may interfere with a
      -- clean print of the done line.
      local exit_code = line:match("===DONE%((%d+)%)===")
      if exit_code then
        local output = util.tbl_slice(self._stdout, 1, i - 1)
        local cb = self.commands[1].cb
        self._stdout = util.tbl_slice(self._stdout, i + 1)
        if exit_code == "0" then
          cb(nil, output)
        else
          cb(exit_code .. ": " .. table.concat(output, "\n"), output)
        end
        table.remove(self.commands, 1)
        self:_handle_output(1)
        self:_consume()
        return
      end
    end
  end

  local function check_last_line()
    local last_lines = get_last_lines(self.term_bufnr, 1)
    local last_line = last_lines[1]
    if last_line:match("^Are you sure you want to continue connecting") then
      self:open_terminal()
    elseif last_line:match("Password:%s*$") then
      self:open_terminal()
    elseif last_line:match(": Permission denied %(.+%)%.") then
      self:_set_connection_error(last_line:match(": (Permission denied %(.+%).)"))
    elseif last_line:match("^ssh: .*Connection refused%s*$") then
      self:_set_connection_error("Connection refused")
    elseif last_line:match("^Connection to .+ closed by remote host.%s*$") then
      self:_set_connection_error("Connection closed by remote host")
    end
  end
  -- We have to defer this so the terminal buffer has time to update
  vim.defer_fn(check_last_line, 10)
end

function SSHConnection:open_terminal()
  if self.term_winid and vim.api.nvim_win_is_valid(self.term_winid) then
    vim.api.nvim_set_current_win(self.term_winid)
    return
  end
  local min_width = 120
  local min_height = 20
  local total_height = layout.get_editor_height()
  local width = math.min(min_width, vim.o.columns - 2)
  local height = math.min(min_height, total_height - 3)
  local row = math.floor((total_height - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  self.term_winid = vim.api.nvim_open_win(self.term_bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.ssh.border,
  })
  vim.cmd.startinsert()
end

---@param command string
---@param callback fun(err: nil|string, lines: nil|string[])
function SSHConnection:run(command, callback)
  if self.connection_error then
    callback(self.connection_error)
  else
    table.insert(self.commands, { cmd = command, cb = callback })
    self:_consume()
  end
end

function SSHConnection:_consume()
  if self.connected and not vim.tbl_isempty(self.commands) then
    local cmd = self.commands[1]
    if not cmd.running then
      cmd.running = true
      vim.api.nvim_chan_send(
        self.jid,
        -- HACK: Sleep briefly to help reduce stderr/stdout interleaving.
        -- I want to find a way to flush the stderr before the echo DONE, but haven't yet.
        -- This was causing issues when ls directory that doesn't exist (b/c ls prints error)
        'echo "===BEGIN==="; '
          .. cmd.cmd
          .. '; CODE=$?; sleep .01; echo "===DONE($CODE)==="\r'
      )
    end
  end
end

return SSHConnection
