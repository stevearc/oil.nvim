local M = {}

M.run = function(cmd, opts, callback)
  if not callback then
    callback = opts
    opts = {}
  end
  local stdout
  local stderr = {}
  local jid = vim.fn.jobstart(
    cmd,
    vim.tbl_deep_extend("keep", opts, {
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
          local cmd_str = type(cmd) == "string" and cmd or table.concat(cmd, " ")
          callback(string.format("Error running command '%s'\n%s", cmd_str, err))
        end
      end),
    })
  )
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
