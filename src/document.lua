local document = {}

local Document = {}

function document.new(nodes)
  local self = {
    nodes=nodes or {}
  }
  setmetatable(self, { __index = Document })
  return self
end

return document