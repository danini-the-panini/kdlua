local tokenizer = require "kdl.v1.tokenizer"
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

function Parser:check_version()
  local doc_version = self.tokenizer:version_directive()
  if not doc_version then return end
  if doc_version ~= 1 then
    error("Version mismatch, expected 1, got "..doc_version)
  end
end

local function fail(message, token)
  error(message.." ("..token.line..":"..token.column..")")
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
  if not type and not self:peek_identifier() then return false end
  local n = node.new(self:identifier())

  self:entries(n)

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
  fail("Expected identifier, got "..t.type, t)
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
    local peek = self.tokenizer:peek()
    if peek.type == "IDENT" then
      local k, v = self:prop()
      if not commented then n:insert(k, v) end
      commented = false
    elseif peek.type == "LBRACE" then
      local child_nodes = self:children()
      if not commented then n.children = child_nodes end
      self:node_term()
      return
    elseif peek.type == "SLASHDASH" then
      commented = true
      self.tokenizer:next()
      self:ws()
    elseif peek.type == "NEWLINE" or
        peek.type == "EOF" or
        peek.type == "SEMICOLON" then
      self.tokenizer:next()
      return
    elseif peek.type == "STRING" then
      local t = self.tokenizer:peek_next()
      if t.type == "EQUALS" then
        local k, v = self:prop()
        if not commented then n:insert(k, v) end
      else
        local v = self:value()
        if not commented then n:insert(v) end
      end
      commented = false
    else
      local v = self:value()
      if not commented then n:insert(v) end
      commented = false
    end
  end
end

function Parser:prop()
  local name = self:identifier()
  self:expect("EQUALS")
  local val = self:value()
  return name, val
end

function Parser:children()
  self:expect("LBRACE")
  local node_list = self:nodes()
  self:linespaces()
  self:expect("RBRACE")
  return node_list
end

function Parser:value()
  local type = self:type()
  local t = self.tokenizer:next()
  if t.type == "STRING" or
    t.type == "RAWSTRING" or
    t.type == "INTEGER" or
    t.type == "FLOAT" or
    t.type == "TRUE" or
    t.type == "FALSE" or
    t.type == "NULL" then
      return value.new(t.value, type)
    end
  fail("Expected value, got "..t.type, t)
end

function Parser:type()
  if self.tokenizer:peek().type ~= "LPAREN" then return nil end
  self:expect("LPAREN")
  local type = self:identifier()
  self:expect("RPAREN")
  return type
end

function Parser:expect(type)
  local t = self.tokenizer:peek()
  if t.type == type then return self.tokenizer:next()
  else fail("Expected "..type..", got "..t.type, t) end
end

function Parser:node_term()
  self:ws()
  local t = self.tokenizer:peek()
  if t.type == "NEWLINE" or t.type == "SEMICOLON" or t.type == "EOF" then
    self.tokenizer:next()
  else
    fail("Unexpected "..t.type, t)
  end
end

function Parser:eof()
  local t = self.tokenizer:peek()
  if t.type == "EOF" then return end

  fail("Expected EOF, got "..t.type, t)
end

function parser.parse(str)
  local p = {
    tokenizer=tokenizer.new(str),
    depth=0
  }
  setmetatable(p, { __index = Parser })
  p:check_version()
  return p:document()
end

return parser
