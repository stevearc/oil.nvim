require("plenary.async").tests.add_to_env()
local fs = require("oil.fs")

local function set_env_windows()
  fs.is_windows = true
  fs.is_mac = false
  fs.is_linux = false
  fs.sep = "\\"
end

local function set_env_linux()
  fs.is_windows = false
  fs.is_mac = false
  fs.is_linux = true
  fs.sep = "/"
end

a.describe("File system", function()
  after_each(function()
    fs._initialize_environment()
  end)

  a.it("converts linux path to posix", function()
    set_env_linux()
    assert.equals("/a/b/c", fs.os_to_posix_path("/a/b/c"))
  end)

  a.it("converts Windows local path to posix", function()
    set_env_windows()
    assert.equals("/C/a/b/c", fs.os_to_posix_path("C:\\a\\b\\c"))
  end)

  a.it("converts Windows UNC path to posix", function()
    set_env_windows()
    assert.equals("//a/b/c", fs.os_to_posix_path("\\\\a\\b\\c"))
  end)

  a.it("converts posix to linux path", function()
    set_env_linux()
    assert.equals("/a/b/c", fs.posix_to_os_path("/a/b/c"))
  end)

  a.it("converts posix to Windows local path", function()
    set_env_windows()
    assert.equals("C:\\a\\b\\c", fs.posix_to_os_path("/C/a/b/c"))
  end)

  a.it("converts posix to Windows UNC path", function()
    set_env_windows()
    assert.equals("\\\\a\\b\\c", fs.posix_to_os_path("//a/b/c"))
  end)
end)
