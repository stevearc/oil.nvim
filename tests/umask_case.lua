local files = require("oil.adapters.files")
local fs = require("oil.fs")

local uv = vim.uv or vim.loop

local M = {}

local function create(action)
  local done = false
  local action_err
  files.perform_action(action, function(err)
    action_err = err
    done = true
  end)
  assert(
    vim.wait(1000, function()
      return done
    end),
    "Timed out creating " .. action.url
  )
  assert(not action_err, action_err)
end

local function get_mode(path)
  local stat = assert(uv.fs_stat(path))
  return bit.band(stat.mode, 511)
end

function M.run(expected_file_mode, expected_directory_mode)
  local root = vim.fn.tempname()
  local file_path = fs.join(root, "file")
  local directory_path = fs.join(root, "directory")
  assert(uv.fs_mkdir(root, 511))

  local ok, err = xpcall(function()
    create({
      url = "oil://" .. fs.os_to_posix_path(file_path),
      entry_type = "file",
      type = "create",
    })
    create({
      url = "oil://" .. fs.os_to_posix_path(directory_path),
      entry_type = "directory",
      type = "create",
    })
    assert(
      get_mode(file_path) == expected_file_mode,
      string.format("Expected file mode %o, got %o", expected_file_mode, get_mode(file_path))
    )
    assert(
      get_mode(directory_path) == expected_directory_mode,
      string.format(
        "Expected directory mode %o, got %o",
        expected_directory_mode,
        get_mode(directory_path)
      )
    )
  end, debug.traceback)

  uv.fs_unlink(file_path)
  uv.fs_rmdir(directory_path)
  uv.fs_rmdir(root)
  assert(ok, err)
end

return M
