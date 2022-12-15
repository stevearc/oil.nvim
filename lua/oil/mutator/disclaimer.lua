local fs = require("oil.fs")
local ReplLayout = require("oil.repl_layout")
local M = {}

M.show = function(callback)
  local marker_file = fs.join(vim.fn.stdpath("cache"), ".oil_accepted_disclaimer")
  vim.loop.fs_stat(
    marker_file,
    vim.schedule_wrap(function(err, stat)
      if stat and stat.type and not err then
        callback(true)
        return
      end

      local confirmation = "I understand this may destroy my files"
      local lines = {
        "WARNING",
        "This plugin has been tested thoroughly, but it is still new.",
        "There is a chance that there may be bugs that could lead to data loss.",
        "I recommend that you ONLY use it for files that are checked in to version control.",
        "",
        string.format('Please type: "%s" below', confirmation),
        "",
      }
      local hints = {
        "Try again",
        "Not quite!",
        "It's right there ^^^^^^^^^^^",
        "...seriously?",
        "Just type this ^^^^",
      }
      local attempt = 0
      local repl
      repl = ReplLayout.new({
        lines = lines,
        on_submit = function(line)
          if line:upper() ~= confirmation:upper() then
            attempt = attempt % #hints + 1
            vim.api.nvim_buf_set_lines(repl.input_bufnr, 0, -1, true, {})
            vim.bo[repl.view_bufnr].modifiable = true
            vim.api.nvim_buf_set_lines(repl.view_bufnr, 6, 7, true, { hints[attempt] })
            vim.bo[repl.view_bufnr].modifiable = false
            vim.bo[repl.view_bufnr].modified = false
          else
            fs.mkdirp(vim.fn.fnamemodify(marker_file, ":h"))
            fs.touch(
              marker_file,
              vim.schedule_wrap(function(err2)
                if err2 then
                  vim.notify(
                    string.format("Error recording response: %s", err2),
                    vim.log.levels.WARN
                  )
                end
                callback(true)
                repl:close()
              end)
            )
          end
        end,
        on_cancel = function()
          callback(false)
        end,
      })
      local ns = vim.api.nvim_create_namespace("Oil")
      vim.api.nvim_buf_add_highlight(repl.view_bufnr, ns, "DiagnosticError", 0, 0, -1)
    end)
  )
end

return M
