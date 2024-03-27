local value = {}

local Value = {}

local function __tostring(self)
  if self.type then
    return "("..self.type..")"..tostring(self.value)
  else
    return tostring(self.value)
  end
end

function value.new(v, type)
  local self = {
    value=v,
    type=type
  }
  setmetatable(self, {
    __index=Value,
    __tostring=__tostring
  })
  return self
end

return value