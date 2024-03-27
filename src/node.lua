local node = {}

local Node = {}

local function __tostring(self)
  return self:tostring(0)
end

function Node:tostring(depth)
  local indent = string.rep("    ", depth)
  local typestr = ""
  if self.type then typestr = "("..self.type..")" end
  local s = indent..typestr..self.name
  for k, v in pairs(self.entries) do
    if type(k) == "number" then
      s = s.." "..tostring(v)
    else
      s = s.." "..k.."="..tostring(v)
    end
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

function node.new(name, entries, children, type)
  local self = {
    name=name,
    entries=entries or {},
    children=children or {},
    type=type
  }
  setmetatable(self, {
    __index=Node,
    __tostring=__tostring
  })
  return self
end

return node