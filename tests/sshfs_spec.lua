local sshfs = require("oil.adapters.ssh.sshfs")

describe("oil-ssh filesystem", function()
  it("falls back to an AIX-compatible ls command and caches the result", function()
    local commands = {}
    local responses = {
      { "2: ls: illegal option -- -" },
      { nil, { "aix output" } },
      { nil, { "cached output" } },
    }
    local fs = setmetatable({
      conn = {
        run = function(_, command, callback)
          table.insert(commands, command)
          callback(unpack(table.remove(responses, 1)))
        end,
      },
    }, { __index = sshfs })

    local err, lines
    fs:_run_ls("-lan", " '/tmp'", "", function(ls_err, ls_lines)
      err, lines = ls_err, ls_lines
    end)

    assert.is_nil(err)
    assert.same({ "aix output" }, lines)
    assert.same({
      "LC_ALL=C ls -lan --color=never '/tmp'",
      "LC_ALL=C ls -lan '/tmp'",
    }, commands)

    fs:_run_ls("-lan", " '/var'", "", function(ls_err, ls_lines)
      err, lines = ls_err, ls_lines
    end)

    assert.is_nil(err)
    assert.same({ "cached output" }, lines)
    assert.equals("LC_ALL=C ls -lan '/var'", commands[3])
  end)

  it("keeps using GNU ls when it succeeds", function()
    local command
    local fs = setmetatable({
      conn = {
        run = function(_, value, callback)
          command = value
          callback(nil, { "gnu output" })
        end,
      },
    }, { __index = sshfs })

    local lines
    fs:_run_ls("-land", " '.'", "", function(_, ls_lines)
      lines = ls_lines
    end)

    assert.equals("LC_ALL=C ls -land --color=never '.'", command)
    assert.same({ "gnu output" }, lines)
    assert.is_nil(fs.aix_compatible_ls)
  end)
end)
