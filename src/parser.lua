local tokenizer = require "kdl.tokenizer"
local document = require "kdl.document"
local node = require "kdl.node"
local value = require "kdl.value"

local parser = {}

local Parser = {}

function Parser:document()
  local nodes = self:nodes()
  self:linespaces()
  self:eof()
  return document.new(nodes)
end

function Parser:nodes()
  local nodes = {}
  local n
  repeat
    n = self:node()
    if n then table.insert(nodes, n) end
  until n == false
  return nodes
end

function Parser:node()
  self:linespaces()

  local commented = false
  if self.tokenizer:peek().type == "SLASHDASH" then
    self.tokenizer:next()
    self:ws()
    commented = true
  end

  local type = self:type()
  if not self:peek_identifier() then return false end
  local n = node.new(self:identifier())

  local t = self.tokenizer:peek().type
  if t == "WS" or t == "LBRACE" then self:entries(n)
  elseif t == "SEMICOLON" then self.tokenizer:next()
  elseif t == "LPAREN" then error("Unexpected '('")
  end

  if commented then return nil end
  if type ~= nil then n.type = type end

  return n
end

function Parser:is_identifier(t)
  return t.type == "IDENT" or t.type == "STRING" or t.type == "RAWSTRING"
end

function Parser:peek_identifier()
  local t = self.tokenizer:peek()
  if self:is_identifier(t) then return t end
  return nil
end

function Parser:identifier()
  local t = self.tokenizer:peek()
  if self:is_identifier(t) then return self.tokenizer:next().value end
  error("Expected identifier, got "..t.type)
end

function Parser:ws()
  local t = self.tokenizer:peek()
  while t.type == "WS" do
    self.tokenizer:next()
    t = self.tokenizer:peek()
  end
end

function Parser:linespaces()
  while self:is_linespace(self.tokenizer:peek()) do
    self.tokenizer:next()
  end
end

function Parser:is_linespace(t)
  return t.type == "NEWLINE" or t.type == "WS"
end

function Parser:entries(n)
  local commented = false
  while true do
    self:ws()
    local p = self.tokenizer:peek().type
    if p == "IDENT" then
      if self.tokenizer:peek_next().type == "EQUALS" then
        local k, v = self:prop()
        if not commented then n.entries[k] = v end
      else
        local v = self:value()
        if not commented then table.insert(n.entries, v) end
      end
      commented = false
    elseif p == "LBRACE" then
      self.depth = self.depth + 1
      local children = self:children()
      if not commented then n.children = children end
      self:node_term()
      return
    elseif p == "RBRACE" then
      if self.depth == 0 then error("Unexpected '}'") end
      self.depth = self.depth - 1
      return
    elseif p == "SLASHDASH" then
      commented = true
      self.tokenizer:next()
      self:ws()
    elseif p == "NEWLINE" or p == "EOF" or p == "SEMICOLON" then
      self.tokenizer:next()
      return
    elseif p == "STRING" then
      if self.tokenizer:peek_next().type == "EQUALS" then
        local k, v = self:prop()
        if not commented then n.entries[k] = v end
      else
        local v = self:value()
        if not commented then table.insert(n.entries, v) end
      end
      commented = false
    else
      local v = self:value()
      if not commented then table.insert(n.entries, v) end
      commented = false
    end
  end
end

function Parser:prop()
  local name = self:identifier()
  self:expect("EQUALS")
  local value = self:value()
  return name, value
end

function Parser:children()
  self:expect("LBRACE")
  local nodes = self:nodes()
  self:linespaces()
  self:expect("RBRACE")
  return nodes
end

function Parser:value()
  local type = self:type()
  local t = self.tokenizer:next()
  if t.type == "IDENT" or
    t.type == "STRING" or
    t.type == "RAWSTRING" or
    t.type == "INTEGER" or
    t.type == "FLOAT" or
    t.type == "TRUE" or
    t.type == "FALSE" or
    t.type == "NULL" then
      return value.new(t.value, type)
    end
  error("Expected value, got "..t.type)
end

function Parser:type()
  if self.tokenizer:peek().type ~= "LPAREN" then return nil end
  self:expect("LPAREN")
  self:ws()
  local type = self:identifier()
  self:ws()
  self:expect("RPAREN")
  self:ws()
  return type
end

function Parser:expect(type)
  local t = self.tokenizer:peek().type
  if t == type then return self.tokenizer:next()
  else error("Expected "..type..", got "..t) end
end

function Parser:node_term()
  self:ws()
  local t = self.tokenizer:peek().type
  if t == "NEWLINE" or t == "SEMICOLON" or t == "EOF" then
    return self.tokenizer:next()
  elseif t ~= "RBRACE" then
    error("Unexpected "..t)
  end
end

function Parser:eof()
  local t = self.tokenizer:peek().type
  if t == "EOF" or t == false then return end

  error("Expected EOF, got "..t)
end

function parser.parse(str)
  local p = {
    tokenizer=tokenizer.new(str),
    depth=0
  }
  setmetatable(p, { __index = Parser })
  return p:document()
end

return parser