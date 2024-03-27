local document = {}

local Document = {}

local function __tostring(self)
  if #self.nodes == 0 then return "\n" end

  local s = ""
  for _, node in pairs(self.nodes) do
    s = s..tostring(node).."\n"
  end
  return s
end

function document.new(nodes)
  local self = {
    nodes=nodes or {}
  }
  setmetatable(self, {
    __index=Document,
    __tostring=__tostring
  })
  return self
end

return document