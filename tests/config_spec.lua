require("plenary.async").tests.add_to_env()
local oil = require("oil")
local test_util = require("tests.test_util")

a.describe("config", function()
  after_each(function()
    test_util.reset_editor()
  end)

  a.it("user keymaps override defaults written with different casing", function()
    oil.setup({
      adapters = { ["oil-test://"] = "test" },
      keymaps = {
        ["<c-t>"] = false,
        ["<c-S>"] = { "actions.close", mode = "n" },
      },
    })
    test_util.oil_open()
    assert.equals("", vim.fn.maparg("<C-t>", "n"))
    assert.equals(
      "Close oil and restore original buffer",
      vim.fn.maparg("<C-s>", "n", false, true).desc
    )
    -- Defaults that the user didn't touch are still mapped
    assert.equals("Open the entry under the cursor", vim.fn.maparg("<CR>", "n", false, true).desc)
  end)
end)
