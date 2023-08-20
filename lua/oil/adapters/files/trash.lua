local config = require("oil.config")
local M = {}

M.recursive_delete = function(path, cb)
  local stdout = {}
  local stderr = {}
  local cmd
  if config.trash_command:find("%s") then
    cmd = string.format("%s %s", config.trash_command, vim.fn.shellescape(path))
  else
    cmd = { config.trash_command, path }
  end
  local jid = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(j, output)
      stdout = output
    end,
    on_stderr = function(j, output)
      stderr = output
    end,
    on_exit = function(j, exit_code)
      if exit_code == 0 then
        cb()
      else
        cb(
          string.format(
            "Error moving '%s' to trash:\n  stdout: %s\n  stderr: %s",
            path,
            table.concat(stdout, "\n  "),
            table.concat(stderr, "\n  ")
          )
        )
      end
    end,
  })
  if jid == 0 then
    cb(string.format("Passed invalid argument '%s' to '%s'", path, config.trash_command))
  elseif jid == -1 then
    cb(string.format("'%s' is not executable", config.trash_command))
  end
end

return M
