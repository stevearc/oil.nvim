vim.opt.runtimepath:prepend("scripts/benchmark.nvim")
vim.opt.runtimepath:prepend(".")

local bm = require("benchmark")
bm.sandbox()

---@module 'oil'
---@type oil.SetupOpts
local setup_opts = {
  -- columns = { "icon", "permissions", "size", "mtime" },
}

local DIR_SIZE = tonumber(vim.env.DIR_SIZE) or 100000
local ITERATIONS = tonumber(vim.env.ITERATIONS) or 10
local WARM_UP = tonumber(vim.env.WARM_UP) or 1
local OUTLIERS = tonumber(vim.env.OUTLIERS) or math.floor(ITERATIONS / 10)
local TEST_DIR = "perf/tmp/test_" .. DIR_SIZE

vim.fn.mkdir(TEST_DIR, "p")
require("benchmark.files").create_files(TEST_DIR, "file %d.txt", DIR_SIZE)

function _G.jit_profile()
  require("oil").setup(setup_opts)
  local finish = bm.jit_profile({ filename = TEST_DIR .. "/profile.txt" })
  bm.wait_for_user_event("OilEnter", function()
    finish()
  end)
  require("oil").open(TEST_DIR)
end

function _G.flame_profile()
  local start, stop = bm.flame_profile({
    pattern = "oil*",
    filename = "profile.json",
  })
  require("oil").setup(setup_opts)
  start()
  bm.wait_for_user_event("OilEnter", function()
    stop(function()
      vim.cmd.qall({ mods = { silent = true } })
    end)
  end)
  require("oil").open(TEST_DIR)
end

function _G.benchmark()
  require("oil").setup(setup_opts)
  bm.run({ title = "oil.nvim", iterations = ITERATIONS, warm_up = WARM_UP }, function(callback)
    bm.wait_for_user_event("OilEnter", callback)
    require("oil").open(TEST_DIR)
  end, function(times)
    local avg = bm.avg(times, { trim_outliers = OUTLIERS })
    local std_dev = bm.std_dev(times, { trim_outliers = OUTLIERS })
    local lines = {
      table.concat(vim.tbl_map(bm.format_time, times), " "),
      string.format("Average: %s", bm.format_time(avg)),
      string.format("Std deviation: %s", bm.format_time(std_dev)),
    }

    vim.fn.writefile(lines, "perf/tmp/benchmark.txt")
    vim.cmd.qall({ mods = { silent = true } })
  end)
end
