local util = require("oil.util")
describe("util", function()
  it("url_escape", function()
    local cases = {
      { "foobar", "foobar" },
      { "foo bar", "foo%20bar" },
      { "/foo/bar", "%2Ffoo%2Fbar" },
    }
    for _, case in ipairs(cases) do
      local input, expected = unpack(case)
      local output = util.url_escape(input)
      assert.equals(expected, output)
    end
  end)

  it("url_unescape", function()
    local cases = {
      { "foobar", "foobar" },
      { "foo%20bar", "foo bar" },
      { "%2Ffoo%2Fbar", "/foo/bar" },
      { "foo%%bar", "foo%%bar" },
    }
    for _, case in ipairs(cases) do
      local input, expected = unpack(case)
      local output = util.url_unescape(input)
      assert.equals(expected, output)
    end
  end)

  it("uses a highlight for the default file icon", function()
    local old_devicons = package.loaded["nvim-web-devicons"]
    local old_mini_icons = _G.MiniIcons
    _G.MiniIcons = nil
    package.loaded["nvim-web-devicons"] = {
      get_icon = function()
        return nil, nil
      end,
    }

    local icon_provider = util.get_icon_provider()
    assert.not_nil(icon_provider)
    local icon, hl = icon_provider("file", "unknown", { default_file = "file" })
    assert.equals("file", icon)
    assert.equals("OilDefaultFileIcon", hl)

    icon, hl = icon_provider("directory", "dir", { directory = "dir" })
    assert.equals("dir", icon)
    assert.equals("OilDirIcon", hl)

    package.loaded["nvim-web-devicons"] = old_devicons
    _G.MiniIcons = old_mini_icons
  end)
end)
