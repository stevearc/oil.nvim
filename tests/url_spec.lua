local oil = require("oil")
local util = require("oil.util")

local uv = vim.uv or vim.loop

describe("url", function()
  it("get_url_for_path", function()
    local cases = {
      { "", "oil://" .. util.addslash(vim.fn.getcwd()), skip_on_windows = true },
      {
        "term://~/oil.nvim//52953:/bin/sh",
        "oil://" .. vim.loop.os_homedir() .. "/oil.nvim/",
        skip_on_windows = true,
      },
      { "/foo/bar.txt", "oil:///foo/", "bar.txt", skip_on_windows = true },
      { "oil:///foo/bar.txt", "oil:///foo/", "bar.txt" },
      { "oil:///", "oil:///" },
      { "oil-ssh://user@hostname:8888//bar.txt", "oil-ssh://user@hostname:8888//", "bar.txt" },
      { "oil-ssh://user@hostname:8888//", "oil-ssh://user@hostname:8888//" },
    }
    for _, case in ipairs(cases) do
      local is_skip = case.skip_on_windows and uv.os_uname().version:match("Windows")
      if not is_skip then
        local input, expected, expected_basename = unpack(case)
        local output, basename = oil.get_buffer_parent_url(input, true)
        assert.equals(expected, output, string.format('Parent url for path "%s" failed', input))
        assert.equals(
          expected_basename,
          basename,
          string.format('Basename for path "%s" failed', input)
        )
      end
    end
  end)
end)
