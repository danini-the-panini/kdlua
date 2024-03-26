local tokenizer = {}

local Tokenizer = { str="" }

function Tokenizer:peek()
  return {}
end

function Tokenizer:peek_next()
  return {}
end

function Tokenizer:next()
  return {}
end

function tokenizer:new()
  local self = {}
  setmetatable(self, { __index = Tokenizer })
  return self
end

return tokenizer