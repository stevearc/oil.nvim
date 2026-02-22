local config = require('oil.config')

describe('config', function()
  after_each(function()
    vim.g.oil = nil
  end)

  it('falls back to vim.g.oil when setup() is called with no args', function()
    vim.g.oil = { delete_to_trash = true, cleanup_delay_ms = 5000 }
    config.setup()
    assert.is_true(config.delete_to_trash)
    assert.equals(5000, config.cleanup_delay_ms)
  end)

  it('uses defaults when neither opts nor vim.g.oil is set', function()
    vim.g.oil = nil
    config.setup()
    assert.is_false(config.delete_to_trash)
    assert.equals(2000, config.cleanup_delay_ms)
  end)

  it('prefers explicit opts over vim.g.oil', function()
    vim.g.oil = { delete_to_trash = true }
    config.setup({ delete_to_trash = false })
    assert.is_false(config.delete_to_trash)
  end)
end)
