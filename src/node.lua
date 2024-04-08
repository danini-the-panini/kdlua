require "kdl.util"

local stringdumper = require "kdl.stringdumper"
local dump = stringdumper.dump

local node = {}

local Node = {}

local function __tostring(self)
  return self:tostring(0)
end

function Node:tostring(depth)
  local indent = string.rep("    ", depth)
  local typestr = ""
  if self.type then typestr = "("..dump(self.type)..")" end
  local s = indent..typestr..dump(self.name)
  for _, v in ipairs(self.entries) do
    s = s.." "..tostring(v)
  end
  for _, k in pairs(self.keys) do
    local v = self.entries[k]
    s = s.." "..dump(k).."="..tostring(v)
  end
  if #self.children > 0 then
    s = s.." {\n"
    for _, child in pairs(self.children) do
      s = s..child:tostring(depth + 1).."\n"
    end
    s = s..indent.."}"
  end
  return s
end

function node.new(name, entries, children, ty)
  local keys = {}
  for k, _ in pairs(entries or {}) do
    if type(k) ~= "number" then table.insert(keys, k) end
  end
  local self = {
    name=name,
    entries=entries or {},
    keys=keys,
    children=children or {},
    type=ty
  }
  setmetatable(self, {
    __index=Node,
    __tostring=__tostring
  })
  return self
end

function Node:insert(k, v)
  if v == nil then
    table.insert(self.entries, k)
    return
  end

  if not table.contains(self.keys, k) then
    table.insert(self.keys, k)
  end

  self.entries[k] = v
end

return node