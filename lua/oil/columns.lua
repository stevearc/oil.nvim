local config = require("oil.config")
local constants = require("oil.constants")
local util = require("oil.util")
local M = {}

local FIELD_NAME = constants.FIELD_NAME
local FIELD_TYPE = constants.FIELD_TYPE
local FIELD_META = constants.FIELD_META

local all_columns = {}

---@alias oil.ColumnSpec string|{[1]: string, [string]: any}

---@class (exact) oil.ColumnDefinition
---@field render fun(entry: oil.InternalEntry, conf: nil|table, bufnr: integer): nil|oil.TextChunk
---@field parse fun(line: string, conf: nil|table): nil|string, nil|string
---@field compare? fun(entry: oil.InternalEntry, parsed_value: any): boolean
---@field render_action? fun(action: oil.ChangeAction): string
---@field perform_action? fun(action: oil.ChangeAction, callback: fun(err: nil|string))
---@field get_sort_value? fun(entry: oil.InternalEntry): number|string
---@field create_sort_value_factory? fun(num_entries: integer): fun(entry: oil.InternalEntry): number|string

---@param name string
---@param column oil.ColumnDefinition
M.register = function(name, column)
  all_columns[name] = column
end

---@param adapter oil.Adapter
---@param defn oil.ColumnSpec
---@return nil|oil.ColumnDefinition
M.get_column = function(adapter, defn)
  local name = util.split_config(defn)
  return all_columns[name] or adapter.get_column(name)
end

---@param adapter_or_scheme string|oil.Adapter
---@return oil.ColumnSpec[]
M.get_supported_columns = function(adapter_or_scheme)
  local adapter
  if type(adapter_or_scheme) == "string" then
    adapter = config.get_adapter_by_scheme(adapter_or_scheme)
  else
    adapter = adapter_or_scheme
  end
  assert(adapter)
  local ret = {}
  for _, def in ipairs(config.columns) do
    if M.get_column(adapter, def) then
      table.insert(ret, def)
    end
  end
  return ret
end

local EMPTY = { "-", "Comment" }

M.EMPTY = EMPTY

---@param adapter oil.Adapter
---@param col_def oil.ColumnSpec
---@param entry oil.InternalEntry
---@param bufnr integer
---@return oil.TextChunk
M.render_col = function(adapter, col_def, entry, bufnr)
  local name, conf = util.split_config(col_def)
  local column = M.get_column(adapter, name)
  if not column then
    -- This shouldn't be possible because supports_col should return false
    return EMPTY
  end

  local chunk = column.render(entry, conf, bufnr)
  if type(chunk) == "table" then
    if chunk[1]:match("^%s*$") then
      return EMPTY
    end
  else
    if not chunk or chunk:match("^%s*$") then
      return EMPTY
    end
    if conf and conf.highlight then
      local highlight = conf.highlight
      if type(highlight) == "function" then
        highlight = conf.highlight(chunk)
      end
      return { chunk, highlight }
    end
  end
  return chunk
end

---@param adapter oil.Adapter
---@param line string
---@param col_def oil.ColumnSpec
---@return nil|string
---@return nil|string
M.parse_col = function(adapter, line, col_def)
  local name, conf = util.split_config(col_def)
  -- If rendering failed, there will just be a "-"
  local empty_col, rem = line:match("^(-%s+)(.*)$")
  if empty_col then
    return nil, rem
  end
  local column = M.get_column(adapter, name)
  if column then
    return column.parse(line, conf)
  end
end

---@param adapter oil.Adapter
---@param col_name string
---@param entry oil.InternalEntry
---@param parsed_value any
---@return boolean
M.compare = function(adapter, col_name, entry, parsed_value)
  local column = M.get_column(adapter, col_name)
  if column and column.compare then
    return column.compare(entry, parsed_value)
  else
    return false
  end
end

---@param adapter oil.Adapter
---@param action oil.ChangeAction
---@return string
M.render_change_action = function(adapter, action)
  local column = M.get_column(adapter, action.column)
  if not column then
    error(string.format("Received change action for nonexistant column %s", action.column))
  end
  if column.render_action then
    return column.render_action(action)
  else
    return string.format("CHANGE %s %s = %s", action.url, action.column, action.value)
  end
end

---@param adapter oil.Adapter
---@param action oil.ChangeAction
---@param callback fun(err: nil|string)
M.perform_change_action = function(adapter, action, callback)
  local column = M.get_column(adapter, action.column)
  if not column then
    return callback(
      string.format("Received change action for nonexistant column %s", action.column)
    )
  end
  column.perform_action(action, callback)
end

local icon_provider = util.get_icon_provider()
if icon_provider then
  M.register("icon", {
    render = function(entry, conf)
      local field_type = entry[FIELD_TYPE]
      local name = entry[FIELD_NAME]
      local meta = entry[FIELD_META]
      if field_type == "link" and meta then
        if meta.link then
          name = meta.link
        end
        if meta.link_stat then
          field_type = meta.link_stat.type
        end
      end
      if meta and meta.display_name then
        name = meta.display_name
      end
      local icon, hl = icon_provider(field_type, name, conf)
      if not conf or conf.add_padding ~= false then
        icon = icon .. " "
      end
      if conf and conf.highlight then
        if type(conf.highlight) == "function" then
          hl = conf.highlight(icon)
        else
          hl = conf.highlight
        end
      end
      return { icon, hl }
    end,

    parse = function(line, conf)
      return line:match("^(%S+)%s+(.*)$")
    end,
  })
end

local default_type_icons = {
  directory = "dir",
  socket = "sock",
}
---@param entry oil.InternalEntry
---@return boolean
local function is_entry_directory(entry)
  local type = entry[FIELD_TYPE]
  if type == "directory" then
    return true
  elseif type == "link" then
    local meta = entry[FIELD_META]
    return meta and meta.link_stat and meta.link_stat.type == "directory"
  else
    return false
  end
end
M.register("type", {
  render = function(entry, conf)
    local entry_type = entry[FIELD_TYPE]
    if conf and conf.icons then
      return conf.icons[entry_type] or entry_type
    else
      return default_type_icons[entry_type] or entry_type
    end
  end,

  parse = function(line, conf)
    return line:match("^(%S+)%s+(.*)$")
  end,

  get_sort_value = function(entry)
    if is_entry_directory(entry) then
      return 1
    else
      return 2
    end
  end,
})

local function pad_number(int)
  return string.format("%012d", int)
end

M.register("name", {
  render = function(entry, conf)
    error("Do not use the name column. It is for sorting only")
  end,

  parse = function(line, conf)
    error("Do not use the name column. It is for sorting only")
  end,

  create_sort_value_factory = function(num_entries)
    if
      config.view_options.natural_order == false
      or (config.view_options.natural_order == "fast" and num_entries > 5000)
    then
      if config.view_options.case_insensitive then
        return function(entry)
          return entry[FIELD_NAME]:lower()
        end
      else
        return function(entry)
          return entry[FIELD_NAME]
        end
      end
    else
      if config.view_options.case_insensitive then
        return function(entry)
          return entry[FIELD_NAME]:gsub("%d+", pad_number):lower()
        end
      else
        return function(entry)
          return entry[FIELD_NAME]:gsub("%d+", pad_number)
        end
      end
    end
  end,
})

return M
