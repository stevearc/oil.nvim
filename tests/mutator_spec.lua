require("plenary.async").tests.add_to_env()
local FIELD = require("oil.constants").FIELD
local view = require("oil.view")
local cache = require("oil.cache")
local mutator = require("oil.mutator")
local parser = require("oil.mutator.parser")
local test_adapter = require("oil.adapters.test")
local util = require("oil.util")

local function set_lines(bufnr, lines)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end

a.describe("mutator", function()
  after_each(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    cache.clear_everything()
  end)

  describe("parser", function()
    it("detects new files", function()
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {
        "a.txt",
      })
      local diffs = parser.parse(bufnr)
      assert.are.same({ { entry_type = "file", name = "a.txt", type = "new" } }, diffs)
    end)

    it("detects new directories", function()
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {
        "foo/",
      })
      local diffs = parser.parse(bufnr)
      assert.are.same({ { entry_type = "directory", name = "foo", type = "new" } }, diffs)
    end)

    it("detects deleted files", function()
      local file = cache.create_and_store_entry("oil-test:///foo/", "a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {})
      local diffs = parser.parse(bufnr)
      assert.are.same({
        { name = "a.txt", type = "delete", id = file[FIELD.id] },
      }, diffs)
    end)

    it("detects deleted directories", function()
      local dir = cache.create_and_store_entry("oil-test:///foo/", "bar", "directory")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {})
      local diffs = parser.parse(bufnr)
      assert.are.same({
        { name = "bar", type = "delete", id = dir[FIELD.id] },
      }, diffs)
    end)

    it("ignores empty lines", function()
      local file = cache.create_and_store_entry("oil-test:///foo/", "a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local cols = view.format_entry_cols(file, {}, {}, test_adapter)
      local lines = util.render_table({ cols }, {})
      table.insert(lines, "")
      table.insert(lines, "     ")
      set_lines(bufnr, lines)
      local diffs = parser.parse(bufnr)
      assert.are.same({}, diffs)
    end)

    it("errors on missing filename", function()
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {
        "/008",
      })
      local _, errors = parser.parse(bufnr)
      assert.are_same({
        {
          message = "Malformed ID at start of line",
          lnum = 0,
          col = 0,
        },
      }, errors)
    end)

    it("errors on empty dirname", function()
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {
        "/008 /",
      })
      local _, errors = parser.parse(bufnr)
      assert.are.same({
        {
          message = "No filename found",
          lnum = 1,
          col = 0,
        },
      }, errors)
    end)

    it("ignores new dirs with empty name", function()
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {
        "/",
      })
      local diffs = parser.parse(bufnr)
      assert.are.same({}, diffs)
    end)

    it("parses a rename as a delete + new", function()
      local file = cache.create_and_store_entry("oil-test:///foo/", "a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {
        string.format("/%d b.txt", file[FIELD.id]),
      })
      local diffs = parser.parse(bufnr)
      assert.are.same({
        { type = "new", id = file[FIELD.id], name = "b.txt", entry_type = "file" },
        { type = "delete", id = file[FIELD.id], name = "a.txt" },
      }, diffs)
    end)

    it("detects renamed files that conflict", function()
      local afile = cache.create_and_store_entry("oil-test:///foo/", "a.txt", "file")
      local bfile = cache.create_and_store_entry("oil-test:///foo/", "b.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      set_lines(bufnr, {
        string.format("/%d a.txt", bfile[FIELD.id]),
        string.format("/%d b.txt", afile[FIELD.id]),
      })
      local diffs = parser.parse(bufnr)
      local first_two = { diffs[1], diffs[2] }
      local last_two = { diffs[3], diffs[4] }
      table.sort(first_two, function(a, b)
        return a.id < b.id
      end)
      table.sort(last_two, function(a, b)
        return a.id < b.id
      end)
      assert.are.same({
        { name = "b.txt", type = "new", id = afile[FIELD.id], entry_type = "file" },
        { name = "a.txt", type = "new", id = bfile[FIELD.id], entry_type = "file" },
      }, first_two)
      assert.are.same({
        { name = "a.txt", type = "delete", id = afile[FIELD.id] },
        { name = "b.txt", type = "delete", id = bfile[FIELD.id] },
      }, last_two)
    end)
  end)

  describe("build actions", function()
    it("empty diffs produce no actions", function()
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local actions = mutator.create_actions_from_diffs({
        [bufnr] = {},
      })
      assert.are.same({}, actions)
    end)

    it("constructs CREATE actions", function()
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "new", name = "a.txt", entry_type = "file" },
      }
      local actions = mutator.create_actions_from_diffs({
        [bufnr] = diffs,
      })
      assert.are.same({
        {
          type = "create",
          entry_type = "file",
          url = "oil-test:///foo/a.txt",
        },
      }, actions)
    end)

    it("constructs DELETE actions", function()
      local file = cache.create_and_store_entry("oil-test:///foo/", "a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "delete", name = "a.txt", id = file[FIELD.id] },
      }
      local actions = mutator.create_actions_from_diffs({
        [bufnr] = diffs,
      })
      assert.are.same({
        {
          type = "delete",
          entry_type = "file",
          url = "oil-test:///foo/a.txt",
        },
      }, actions)
    end)

    it("constructs COPY actions", function()
      local file = cache.create_and_store_entry("oil-test:///foo/", "a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "new", name = "b.txt", entry_type = "file", id = file[FIELD.id] },
      }
      local actions = mutator.create_actions_from_diffs({
        [bufnr] = diffs,
      })
      assert.are.same({
        {
          type = "copy",
          entry_type = "file",
          src_url = "oil-test:///foo/a.txt",
          dest_url = "oil-test:///foo/b.txt",
        },
      }, actions)
    end)

    it("constructs MOVE actions", function()
      local file = cache.create_and_store_entry("oil-test:///foo/", "a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "delete", name = "a.txt", id = file[FIELD.id] },
        { type = "new", name = "b.txt", entry_type = "file", id = file[FIELD.id] },
      }
      local actions = mutator.create_actions_from_diffs({
        [bufnr] = diffs,
      })
      assert.are.same({
        {
          type = "move",
          entry_type = "file",
          src_url = "oil-test:///foo/a.txt",
          dest_url = "oil-test:///foo/b.txt",
        },
      }, actions)
    end)

    it("correctly orders MOVE + CREATE", function()
      local file = cache.create_and_store_entry("oil-test:///", "a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "delete", name = "a.txt", id = file[FIELD.id] },
        { type = "new", name = "b.txt", entry_type = "file", id = file[FIELD.id] },
        { type = "new", name = "a.txt", entry_type = "file" },
      }
      local actions = mutator.create_actions_from_diffs({
        [bufnr] = diffs,
      })
      assert.are.same({
        {
          type = "move",
          entry_type = "file",
          src_url = "oil-test:///a.txt",
          dest_url = "oil-test:///b.txt",
        },
        {
          type = "create",
          entry_type = "file",
          url = "oil-test:///a.txt",
        },
      }, actions)
    end)

    it("resolves MOVE loops", function()
      local afile = cache.create_and_store_entry("oil-test:///", "a.txt", "file")
      local bfile = cache.create_and_store_entry("oil-test:///", "b.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "delete", name = "a.txt", id = afile[FIELD.id] },
        { type = "new", name = "b.txt", entry_type = "file", id = afile[FIELD.id] },
        { type = "delete", name = "b.txt", id = bfile[FIELD.id] },
        { type = "new", name = "a.txt", entry_type = "file", id = bfile[FIELD.id] },
      }
      math.randomseed(2983982)
      local actions = mutator.create_actions_from_diffs({
        [bufnr] = diffs,
      })
      local tmp_url = "oil-test:///a.txt__oil_tmp_510852"
      assert.are.same({
        {
          type = "move",
          entry_type = "file",
          src_url = "oil-test:///a.txt",
          dest_url = tmp_url,
        },
        {
          type = "move",
          entry_type = "file",
          src_url = "oil-test:///b.txt",
          dest_url = "oil-test:///a.txt",
        },
        {
          type = "move",
          entry_type = "file",
          src_url = tmp_url,
          dest_url = "oil-test:///b.txt",
        },
      }, actions)
    end)
  end)

  describe("order actions", function()
    it("Creates files inside dir before move", function()
      local move = {
        type = "move",
        src_url = "oil-test:///a",
        dest_url = "oil-test:///b",
        entry_type = "directory",
      }
      local create = { type = "create", url = "oil-test:///a/hi.txt", entry_type = "file" }
      local actions = { move, create }
      local ordered_actions = mutator.enforce_action_order(actions)
      assert.are.same({ create, move }, ordered_actions)
    end)

    it("Handles parent child move ordering", function()
      -- move parent into a child and child OUT of parent
      --     MOVE /a/b -> /b
      --     MOVE /a -> /b/a
      local move1 = {
        type = "move",
        src_url = "oil-test:///a/b",
        dest_url = "oil-test:///b",
        entry_type = "directory",
      }
      local move2 = {
        type = "move",
        src_url = "oil-test:///a",
        dest_url = "oil-test:///b/a",
        entry_type = "directory",
      }
      local actions = { move2, move1 }
      local ordered_actions = mutator.enforce_action_order(actions)
      assert.are.same({ move1, move2 }, ordered_actions)
    end)

    it("Detects move directory loops", function()
      local move = {
        type = "move",
        src_url = "oil-test:///a",
        dest_url = "oil-test:///a/b",
        entry_type = "directory",
      }
      assert.has_error(function()
        mutator.enforce_action_order({ move })
      end)
    end)

    it("Detects copy directory loops", function()
      local move = {
        type = "copy",
        src_url = "oil-test:///a",
        dest_url = "oil-test:///a/b",
        entry_type = "directory",
      }
      assert.has_error(function()
        mutator.enforce_action_order({ move })
      end)
    end)

    it("Detects nested copy directory loops", function()
      local move = {
        type = "copy",
        src_url = "oil-test:///a",
        dest_url = "oil-test:///a/b/a",
        entry_type = "directory",
      }
      assert.has_error(function()
        mutator.enforce_action_order({ move })
      end)
    end)

    describe("change", function()
      it("applies CHANGE after CREATE", function()
        local create = { type = "create", url = "oil-test:///a/hi.txt", entry_type = "file" }
        local change = {
          type = "change",
          url = "oil-test:///a/hi.txt",
          entry_type = "file",
          column = "TEST",
          value = "TEST",
        }
        local actions = { change, create }
        local ordered_actions = mutator.enforce_action_order(actions)
        assert.are.same({ create, change }, ordered_actions)
      end)

      it("applies CHANGE after COPY src", function()
        local copy = {
          type = "copy",
          src_url = "oil-test:///a/hi.txt",
          dest_url = "oil-test:///b.txt",
          entry_type = "file",
        }
        local change = {
          type = "change",
          url = "oil-test:///a/hi.txt",
          entry_type = "file",
          column = "TEST",
          value = "TEST",
        }
        local actions = { change, copy }
        local ordered_actions = mutator.enforce_action_order(actions)
        assert.are.same({ copy, change }, ordered_actions)
      end)

      it("applies CHANGE after COPY dest", function()
        local copy = {
          type = "copy",
          src_url = "oil-test:///b.txt",
          dest_url = "oil-test:///a/hi.txt",
          entry_type = "file",
        }
        local change = {
          type = "change",
          url = "oil-test:///a/hi.txt",
          entry_type = "file",
          column = "TEST",
          value = "TEST",
        }
        local actions = { change, copy }
        local ordered_actions = mutator.enforce_action_order(actions)
        assert.are.same({ copy, change }, ordered_actions)
      end)

      it("applies CHANGE after MOVE dest", function()
        local move = {
          type = "move",
          src_url = "oil-test:///b.txt",
          dest_url = "oil-test:///a/hi.txt",
          entry_type = "file",
        }
        local change = {
          type = "change",
          url = "oil-test:///a/hi.txt",
          entry_type = "file",
          column = "TEST",
          value = "TEST",
        }
        local actions = { change, move }
        local ordered_actions = mutator.enforce_action_order(actions)
        assert.are.same({ move, change }, ordered_actions)
      end)
    end)
  end)

  a.describe("perform actions", function()
    a.it("creates new entries", function()
      local actions = {
        { type = "create", url = "oil-test:///a.txt", entry_type = "file" },
      }
      a.wrap(mutator.process_actions, 2)(actions)
      local files = cache.list_url("oil-test:///")
      assert.are.same({
        ["a.txt"] = {
          [FIELD.id] = 1,
          [FIELD.type] = "file",
          [FIELD.name] = "a.txt",
        },
      }, files)
    end)

    a.it("deletes entries", function()
      local file = cache.create_and_store_entry("oil-test:///", "a.txt", "file")
      local actions = {
        { type = "delete", url = "oil-test:///a.txt", entry_type = "file" },
      }
      a.wrap(mutator.process_actions, 2)(actions)
      local files = cache.list_url("oil-test:///")
      assert.are.same({}, files)
      assert.is_nil(cache.get_entry_by_id(file[FIELD.id]))
      assert.has_error(function()
        cache.get_parent_url(file[FIELD.id])
      end)
    end)

    a.it("moves entries", function()
      local file = cache.create_and_store_entry("oil-test:///", "a.txt", "file")
      local actions = {
        {
          type = "move",
          src_url = "oil-test:///a.txt",
          dest_url = "oil-test:///b.txt",
          entry_type = "file",
        },
      }
      a.wrap(mutator.process_actions, 2)(actions)
      local files = cache.list_url("oil-test:///")
      local new_entry = {
        [FIELD.id] = file[FIELD.id],
        [FIELD.type] = "file",
        [FIELD.name] = "b.txt",
      }
      assert.are.same({
        ["b.txt"] = new_entry,
      }, files)
      assert.are.same(new_entry, cache.get_entry_by_id(file[FIELD.id]))
      assert.equals("oil-test:///", cache.get_parent_url(file[FIELD.id]))
    end)

    a.it("copies entries", function()
      local file = cache.create_and_store_entry("oil-test:///", "a.txt", "file")
      local actions = {
        {
          type = "copy",
          src_url = "oil-test:///a.txt",
          dest_url = "oil-test:///b.txt",
          entry_type = "file",
        },
      }
      a.wrap(mutator.process_actions, 2)(actions)
      local files = cache.list_url("oil-test:///")
      local new_entry = {
        [FIELD.id] = file[FIELD.id] + 1,
        [FIELD.type] = "file",
        [FIELD.name] = "b.txt",
      }
      assert.are.same({
        ["a.txt"] = file,
        ["b.txt"] = new_entry,
      }, files)
    end)
  end)
end)
