-- Manual test for minimizing/restoring progress window
local Progress = require("oil.mutator.progress")

local progress = Progress.new()

progress:show({
  cancel = function()
    progress:close()
  end,
})

for i = 1, 10, 1 do
  vim.defer_fn(function()
    progress:set_action({
      type = "create",
      url = string.format("oil:///tmp/test_%d.txt", i),
      entry_type = "file",
    }, i, 10)
  end, (i - 1) * 1000)
end

vim.defer_fn(function()
  progress:close()
end, 10000)

vim.keymap.set("n", "R", function()
  progress:restore()
end, {})
