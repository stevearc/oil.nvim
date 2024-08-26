require("plenary.async").tests.add_to_env()
local cache = require("oil.cache")
local constants = require("oil.constants")
local mutator = require("oil.mutator")
local test_adapter = require("oil.adapters.test")
local test_util = require("tests.test_util")

local FIELD_ID = constants.FIELD_ID
local FIELD_NAME = constants.FIELD_NAME
local FIELD_TYPE = constants.FIELD_TYPE

a.describe("mutator", function()
  after_each(function()
    test_util.reset_editor()
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
      local file = test_adapter.test_set("/foo/a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "delete", name = "a.txt", id = file[FIELD_ID] },
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
      local file = test_adapter.test_set("/foo/a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "new", name = "b.txt", entry_type = "file", id = file[FIELD_ID] },
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
      local file = test_adapter.test_set("/foo/a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///foo/" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "delete", name = "a.txt", id = file[FIELD_ID] },
        { type = "new", name = "b.txt", entry_type = "file", id = file[FIELD_ID] },
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
      local file = test_adapter.test_set("/a.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "delete", name = "a.txt", id = file[FIELD_ID] },
        { type = "new", name = "b.txt", entry_type = "file", id = file[FIELD_ID] },
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
      local afile = test_adapter.test_set("/a.txt", "file")
      local bfile = test_adapter.test_set("/b.txt", "file")
      vim.cmd.edit({ args = { "oil-test:///" } })
      local bufnr = vim.api.nvim_get_current_buf()
      local diffs = {
        { type = "delete", name = "a.txt", id = afile[FIELD_ID] },
        { type = "new", name = "b.txt", entry_type = "file", id = afile[FIELD_ID] },
        { type = "delete", name = "b.txt", id = bfile[FIELD_ID] },
        { type = "new", name = "a.txt", entry_type = "file", id = bfile[FIELD_ID] },
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

    it("Moves file out of parent before deleting parent", function()
      local move = {
        type = "move",
        src_url = "oil-test:///a/b.txt",
        dest_url = "oil-test:///b.txt",
        entry_type = "file",
      }
      local delete = { type = "delete", url = "oil-test:///a", entry_type = "directory" }
      local actions = { delete, move }
      local ordered_actions = mutator.enforce_action_order(actions)
      assert.are.same({ move, delete }, ordered_actions)
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

    it("Handles a delete inside a moved folder", function()
      -- delete in directory and move directory
      --     DELETE /a/b.txt
      --     MOVE /a/ -> /b/
      local del = {
        type = "delete",
        url = "oil-test:///a/b.txt",
        entry_type = "file",
      }
      local move = {
        type = "move",
        src_url = "oil-test:///a",
        dest_url = "oil-test:///b",
        entry_type = "directory",
      }
      local actions = { move, del }
      local ordered_actions = mutator.enforce_action_order(actions)
      assert.are.same({ del, move }, ordered_actions)
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
          [FIELD_ID] = 1,
          [FIELD_TYPE] = "file",
          [FIELD_NAME] = "a.txt",
        },
      }, files)
    end)

    a.it("deletes entries", function()
      local file = test_adapter.test_set("/a.txt", "file")
      local actions = {
        { type = "delete", url = "oil-test:///a.txt", entry_type = "file" },
      }
      a.wrap(mutator.process_actions, 2)(actions)
      local files = cache.list_url("oil-test:///")
      assert.are.same({}, files)
      assert.is_nil(cache.get_entry_by_id(file[FIELD_ID]))
      assert.has_error(function()
        cache.get_parent_url(file[FIELD_ID])
      end)
    end)

    a.it("moves entries", function()
      local file = test_adapter.test_set("/a.txt", "file")
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
        [FIELD_ID] = file[FIELD_ID],
        [FIELD_TYPE] = "file",
        [FIELD_NAME] = "b.txt",
      }
      assert.are.same({
        ["b.txt"] = new_entry,
      }, files)
      assert.are.same(new_entry, cache.get_entry_by_id(file[FIELD_ID]))
      assert.equals("oil-test:///", cache.get_parent_url(file[FIELD_ID]))
    end)

    a.it("copies entries", function()
      local file = test_adapter.test_set("/a.txt", "file")
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
        [FIELD_ID] = file[FIELD_ID] + 1,
        [FIELD_TYPE] = "file",
        [FIELD_NAME] = "b.txt",
      }
      assert.are.same({
        ["a.txt"] = file,
        ["b.txt"] = new_entry,
      }, files)
    end)
  end)
end)
