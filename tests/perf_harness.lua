vim.fn.mkdir("tests/perf/.env", "p")
local root = vim.fn.fnamemodify("./tests/perf/.env", ":p")

for _, name in ipairs({ "config", "data", "state", "runtime", "cache" }) do
  vim.env[("XDG_%s_HOME"):format(name:upper())] = root .. name
end

vim.opt.runtimepath:prepend(vim.fn.fnamemodify(".", ":p"))

---@module 'oil'
---@type oil.SetupOpts
local setup_opts = {
  -- columns = { "icon", "permissions", "size", "mtime" },
}

local num_files = 100000

if not vim.uv.fs_stat(string.format("tests/perf/file %d.txt", num_files)) then
  vim.notify("Creating files")
  for i = 1, num_files, 1 do
    local filename = ("tests/perf/file %d.txt"):format(i)
    local fd = vim.uv.fs_open(filename, "a", 420)
    assert(fd)
    vim.uv.fs_close(fd)
  end
end

local function wait_for_done(callback)
  vim.api.nvim_create_autocmd("User", {
    pattern = "OilEnter",
    once = true,
    callback = callback,
  })
end

function _G.jit_profile()
  require("oil").setup(setup_opts)
  local outfile = "tests/perf/profile.txt"
  require("jit.p").start("3Fpli1s", outfile)
  local start = vim.uv.hrtime()
  require("oil").open("tests/perf")

  wait_for_done(function()
    local delta = vim.uv.hrtime() - start
    require("jit.p").stop()
    print("Elapsed:", delta / 1e6, "ms")
    vim.cmd.edit({ args = { outfile } })
  end)
end

function _G.benchmark(iterations)
  require("oil").setup(setup_opts)
  local num_outliers = math.floor(0.1 * iterations)
  local times = {}

  local run_profile
  run_profile = function()
    -- Clear out state
    vim.cmd.enew()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(bufnr) and bufnr ~= vim.api.nvim_get_current_buf() then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end

    local start = vim.uv.hrtime()
    wait_for_done(function()
      local delta = vim.uv.hrtime() - start
      table.insert(times, delta / 1e6)
      if #times < iterations then
        vim.schedule(run_profile)
      else
        -- Remove the outliers
        table.sort(times)
        for _ = 1, num_outliers do
          table.remove(times, 1)
          table.remove(times)
        end

        local total = 0
        for _, time in ipairs(times) do
          total = total + time
        end

        local lines = {
          table.concat(
            vim.tbl_map(function(t)
              return string.format("%dms", math.floor(t))
            end, times),
            " "
          ),
          string.format("Average: %dms", math.floor(total / #times)),
        }
        vim.fn.writefile(lines, "tests/perf/benchmark.txt")
        vim.cmd.qall()
      end
    end)
    require("oil").open("tests/perf")
  end

  run_profile()
end

function _G.flame_profile()
  if not vim.uv.fs_stat("tests/perf/profile.nvim") then
    vim
      .system({ "git", "clone", "https://github.com/stevearc/profile.nvim", "tests/perf/profile.nvim" })
      :wait()
  end
  vim.opt.runtimepath:prepend(vim.fn.fnamemodify("./tests/perf/profile.nvim", ":p"))
  local profile = require("profile")
  profile.instrument_autocmds()
  profile.instrument("oil*")

  require("oil").setup(setup_opts)
  profile.start()
  require("oil").open("tests/perf")
  wait_for_done(function()
    profile.stop("profile.json")
    vim.cmd.qall()
  end)
end
