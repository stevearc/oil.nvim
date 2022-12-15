local M = {}

M.run = function(cmd, callback)
  local stdout
  local stderr = {}
  local jid = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(j, output)
      stdout = output
    end,
    on_stderr = function(j, output)
      stderr = output
    end,
    on_exit = vim.schedule_wrap(function(j, code)
      if code == 0 then
        callback(nil, stdout)
      else
        local err = table.concat(stderr, "\n")
        if err == "" then
          err = "Unknown error"
        end
        callback(err)
      end
    end),
  })
  local exe
  if type(cmd) == "string" then
    exe = vim.split(cmd, "%s+")[1]
  else
    exe = cmd[1]
  end
  if jid == 0 then
    callback(string.format("Passed invalid arguments to '%s'", exe))
  elseif jid == -1 then
    callback(string.format("'%s' is not executable", exe))
  end
end

return M
