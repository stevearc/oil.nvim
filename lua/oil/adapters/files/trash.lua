local M = {}

M.recursive_delete = function(path, cb)
  local stdout = {}
  local stderr = {}
  local jid = vim.fn.jobstart({ "trash-put", path }, {
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
    cb(string.format("Passed invalid argument '%s' to 'trash-put'", path))
  elseif jid == -1 then
    cb("'trash-put' is not executable")
  end
end

return M
