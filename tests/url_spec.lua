local oil = require("oil")
local util = require("oil.util")

local uv = vim.uv or vim.loop

describe("url", function()
  it("get parent url for empty string path", function()
    if uv.os_uname().version:match("Windows") then
      pending("Skipping this test on Windows because it relies on a unix styled current directory")
      return
    end
    local input = ""
    local expected = "oil://" .. util.addslash(vim.fn.getcwd())

    local output, basename = oil.get_buffer_parent_url(input, true)
    assert.equals(expected, output, string.format('Parent url for path "%s" failed', input))
    assert.equals(nil, basename, string.format('Basename for path "%s" failed', input))
  end)

  it("get parent url for term name", function()
    if uv.os_uname().version:match("Windows") then
      pending(
        "Skipping this test on Windows because it relies on a unix styled current home directory"
      )
      return
    end
    local input = "term://~/oil.nvim//52953:/bin/sh"
    local expected = "oil://" .. vim.loop.os_homedir() .. "/oil.nvim/"
    local output, basename = oil.get_buffer_parent_url(input, true)
    assert.equals(expected, output, string.format('Parent url for path "%s" failed', input))
    assert.equals(nil, basename, string.format('Basename for path "%s" failed', input))
  end)

  it("get parent url for unix path", function()
    if uv.os_uname().version:match("Windows") then
      pending("Skipping this test on Windows because it relies on a unix styled absolute path")
      return
    end
    local input = "/foo/bar.txt"
    local expected = "oil:///foo/"
    local expected_basename = "bar.txt"
    local output, basename = oil.get_buffer_parent_url(input, true)
    assert.equals(expected, output, string.format('Parent url for path "%s" failed', input))
    assert.equals(
      expected_basename,
      basename,
      string.format('Basename for path "%s" failed', input)
    )
  end)

  it("get parent url for oil path", function()
    local input = "oil:///foo/bar.txt"
    local expected = "oil:///foo/"
    local expected_basename = "bar.txt"
    local output, basename = oil.get_buffer_parent_url(input, true)
    assert.equals(expected, output, string.format('Parent url for path "%s" failed', input))
    assert.equals(
      expected_basename,
      basename,
      string.format('Basename for path "%s" failed', input)
    )
  end)

  it("get parent url for base oil path", function()
    local input = "oil:///"
    local expected = "oil:///"
    local output, basename = oil.get_buffer_parent_url(input, true)
    assert.equals(expected, output, string.format('Parent url for path "%s" failed', input))
    assert.equals(nil, basename, string.format('Basename for path "%s" failed', input))
  end)

  it("get parent url for oil ssh path", function()
    local input = "oil-ssh://user@hostname:8888//bar.txt"
    local expected = "oil-ssh://user@hostname:8888//"
    local expected_basename = "bar.txt"
    local output, basename = oil.get_buffer_parent_url(input, true)
    assert.equals(expected, output, string.format('Parent url for path "%s" failed', input))
    assert.equals(
      expected_basename,
      basename,
      string.format('Basename for path "%s" failed', input)
    )
  end)

  it("get parent url for base oil ssh path", function()
    local input = "oil-ssh://user@hostname:8888//"
    local expected = "oil-ssh://user@hostname:8888//"
    local output, basename = oil.get_buffer_parent_url(input, true)
    assert.equals(expected, output, string.format('Parent url for path "%s" failed', input))
    assert.equals(nil, basename, string.format('Basename for path "%s" failed', input))
  end)
end)
