local M = {}

---@class PasswdEntry
---@field username string
---@field uid integer
---@field gid integer

---@type {[integer]: PasswdEntry}
M.passwd_entries = {}

---@class GroupEntry
---@field name string
---@field gid integer

---@type {[integer]: GroupEntry}
M.group_entries = {}

-- TODO use async uv io

M.parse_passwd = function()
  local entry_pat = [[\v^([a-zA-Z0-9-_\.]+):[^:]+:(\d+):(\d+):%([^:]+)?:[^:]+:[^:]+$]]
  for entry in io.lines('/etc/passwd') do
    local m = vim.fn.matchlist(entry, entry_pat)
    if m == nil then -- invalid entry, skip
      goto continue
    end

    local uid, gid = tonumber(m[3]), tonumber(m[4])
    if uid ~= nil and gid ~= nil then
      M.passwd_entries[uid] = {
        username = m[2],
        uid = uid,
        gid = gid,
      }
    end
    ::continue::
  end
end

M.parse_groups = function()
  local entry_pat = [[\v^([a-zA-Z0-9-_\.]+):%([^:]+)?:(\d+):%([^:]+)?$]]
  for entry in io.lines('/etc/group') do
    local m = vim.fn.matchlist(entry, entry_pat)
    if m == nil then
      goto continue
    end

    local gid = tonumber(m[3])
    if gid ~= nil then
      M.group_entries[gid] = {
        name = m[2],
        gid = gid,
      }
    end
    ::continue::
  end
end

return M
