local TmpDir = require('spec.tmpdir')
local files = require('oil.adapters.files')
local test_util = require('spec.test_util')

describe('files adapter', function()
  local tmpdir
  before_each(function()
    tmpdir = TmpDir.new()
  end)
  after_each(function()
    if tmpdir then
      tmpdir:dispose()
    end
    test_util.reset_editor()
  end)

  it('tmpdir creates files and asserts they exist', function()
    tmpdir:create({ 'a.txt', 'foo/b.txt', 'foo/c.txt', 'bar/' })
    tmpdir:assert_fs({
      ['a.txt'] = 'a.txt',
      ['foo/b.txt'] = 'foo/b.txt',
      ['foo/c.txt'] = 'foo/c.txt',
      ['bar/'] = true,
    })
  end)

  it('Creates files', function()
    local err = test_util.await(files.perform_action, 2, {
      url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'a.txt',
      entry_type = 'file',
      type = 'create',
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ['a.txt'] = '',
    })
  end)

  it('Creates directories', function()
    local err = test_util.await(files.perform_action, 2, {
      url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'a',
      entry_type = 'directory',
      type = 'create',
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ['a/'] = true,
    })
  end)

  it('Deletes files', function()
    tmpdir:create({ 'a.txt' })
    local url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'a.txt'
    local err = test_util.await(files.perform_action, 2, {
      url = url,
      entry_type = 'file',
      type = 'delete',
    })
    assert.is_nil(err)
    tmpdir:assert_fs({})
  end)

  it('Deletes directories', function()
    tmpdir:create({ 'a/' })
    local url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'a'
    local err = test_util.await(files.perform_action, 2, {
      url = url,
      entry_type = 'directory',
      type = 'delete',
    })
    assert.is_nil(err)
    tmpdir:assert_fs({})
  end)

  it('Moves files', function()
    tmpdir:create({ 'a.txt' })
    local src_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'a.txt'
    local dest_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'b.txt'
    local err = test_util.await(files.perform_action, 2, {
      src_url = src_url,
      dest_url = dest_url,
      entry_type = 'file',
      type = 'move',
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ['b.txt'] = 'a.txt',
    })
  end)

  it('Moves directories', function()
    tmpdir:create({ 'a/a.txt' })
    local src_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'a'
    local dest_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'b'
    local err = test_util.await(files.perform_action, 2, {
      src_url = src_url,
      dest_url = dest_url,
      entry_type = 'directory',
      type = 'move',
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ['b/a.txt'] = 'a/a.txt',
      ['b/'] = true,
    })
  end)

  it('Copies files', function()
    tmpdir:create({ 'a.txt' })
    local src_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'a.txt'
    local dest_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'b.txt'
    local err = test_util.await(files.perform_action, 2, {
      src_url = src_url,
      dest_url = dest_url,
      entry_type = 'file',
      type = 'copy',
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ['a.txt'] = 'a.txt',
      ['b.txt'] = 'a.txt',
    })
  end)

  it('Recursively copies directories', function()
    tmpdir:create({ 'a/a.txt' })
    local src_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'a'
    local dest_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'b'
    local err = test_util.await(files.perform_action, 2, {
      src_url = src_url,
      dest_url = dest_url,
      entry_type = 'directory',
      type = 'copy',
    })
    assert.is_nil(err)
    tmpdir:assert_fs({
      ['b/a.txt'] = 'a/a.txt',
      ['b/'] = true,
      ['a/a.txt'] = 'a/a.txt',
      ['a/'] = true,
    })
  end)

  it('Editing a new oil://path/ creates an oil buffer', function()
    local tmpdir_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. '/'
    vim.cmd.edit({ args = { tmpdir_url } })
    test_util.wait_oil_ready()
    local new_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'newdir'
    vim.cmd.edit({ args = { new_url } })
    test_util.wait_oil_ready()
    assert.equals('oil', vim.bo.filetype)
    assert.equals(new_url .. '/', vim.api.nvim_buf_get_name(0))
  end)

  it('Editing a new oil://file.rb creates a normal buffer', function()
    local tmpdir_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. '/'
    vim.cmd.edit({ args = { tmpdir_url } })
    test_util.wait_for_autocmd('BufReadPost')
    local new_url = 'oil://' .. vim.fn.fnamemodify(tmpdir.path, ':p') .. 'file.rb'
    vim.cmd.edit({ args = { new_url } })
    test_util.wait_for_autocmd('BufReadPost')
    assert.equals('ruby', vim.bo.filetype)
    assert.equals(vim.fn.fnamemodify(tmpdir.path, ':p') .. 'file.rb', vim.api.nvim_buf_get_name(0))
    assert.equals(tmpdir.path .. '/file.rb', vim.fn.bufname())
  end)
end)
