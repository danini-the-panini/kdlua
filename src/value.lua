local value = {}

local Value = {}

function value.new(v, type)
  local self = {
    value=v,
    type=type
  }
  setmetatable(self, { __index=Value })
  return self
end

return value