local pathutil = require("oil.pathutil")
describe("pathutil", function()
  it("calculates parent path", function()
    local cases = {
      { "/foo/bar", "/foo/" },
      { "/foo/bar/", "/foo/" },
      { "/", "/" },
      { "", "" },
      { "foo/bar/", "foo/" },
      { "foo", "" },
    }
    for _, case in ipairs(cases) do
      local input, expected = unpack(case)
      local output = pathutil.parent(input)
      assert.equals(expected, output, string.format('Parent path "%s" failed', input))
    end
  end)

  it("calculates basename", function()
    local cases = {
      { "/foo/bar", "bar" },
      { "/foo/bar/", "bar" },
      { "/", nil },
      { "", nil },
    }
    for _, case in ipairs(cases) do
      local input, expected = unpack(case)
      local output = pathutil.basename(input)
      assert.equals(expected, output, string.format('Basename "%s" failed', input))
    end
  end)
end)
