local node = {}

local Node = {}

function node.new(id, entries, children, type)
  local self = {
    id=id,
    entries=entries or {},
    children=children or {},
    type=type
  }
  setmetatable(self, { __index = Node })
  return self
end

return node