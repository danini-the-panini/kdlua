local stringdumper = require "kdl.stringdumper"
local dump = stringdumper.dump

local value = {}

local Value = {}

local function __tostring(self)
  local s
  if type(self.value) == "string" then
    s = dump(self.value)
  elseif type(self.value) == "number" then
    if self.value == math.huge then
      s = "#inf"
    elseif self.value == -math.huge then
      s = "#-inf"
    elseif self.value ~= self.value then
      s = "#nan"
    else
      s = tostring(self.value)
    end
  elseif self.value == true then
    s = "#true"
  elseif self.value == false then
    s = "#false"
  elseif self.value == nil then
    s = "#null"
  end

  if self.type then
    return "("..dump(self.type)..")"..s
  else
    return s
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