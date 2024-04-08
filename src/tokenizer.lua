local utf8 = require "lua-utf8"

local util = require "kdl.util"

local tokenizer = {}

local Tokenizer = {}

local function debom(str)
  if utf8.sub(str, 1, 1) == "\u{FEFF}" then
    return utf8.sub(str, 2)
  end
  return str
end

function string:lines()
  local function char(i)
    if i < 0 or i > utf8.len(self) then
      return nil
    end
    return utf8.sub(self, i, i)
  end

  local lines = {}
  local i = 1
  local buffer = ""
  while i <= utf8.len(self) do
    local c = char(i)
    if c == "\r" and char(i+1) == "\n" then
      table.insert(lines, buffer)
      buffer = ""
      i = i+1
    elseif table.contains(util.NEWLINES, c) then
      table.insert(lines, buffer)
      buffer = ""
    else
      buffer = buffer..c
    end
    i = i+1
  end
  table.insert(lines, buffer)
  return lines
end

function tokenizer.new(str, start)
  local self = {
    str=debom(str),
    start=start or 1,
    index=start or 1,
    context=nil,
    rawstring_hashes=-1,
    buffer="",
    done=false,
    previous_context=nil,
    comment_nesting=0,
    peeked_tokens={},
    in_type=false,
    last_token=nil
  }
  setmetatable(self, { __index = Tokenizer })
  return self
end

function Tokenizer:reset()
  self.index = self.start
end

function Tokenizer:tokens()
  local a = {}
  while not self.done do
    table.insert(a, self:next())
  end
  return a
end

function Tokenizer:set_context(context)
  self.previous_context = self.context
  self.context = context
end

function Tokenizer:peek()
  if #self.peeked_tokens == 0 then
    table.insert(self.peeked_tokens, self:_next())
  end
  return self.peeked_tokens[1]
end

function Tokenizer:peek_next()
  if #self.peeked_tokens == 0 then
    table.insert(self.peeked_tokens, self:_next())
    table.insert(self.peeked_tokens, self:_next())
  elseif #self.peeked_tokens == 1 then
    table.insert(self.peeked_tokens, self:_next())
  end
  return self.peeked_tokens[2]
end

function Tokenizer:next()
  if #self.peeked_tokens > 0 then
    return table.remove(self.peeked_tokens, 1)
  else
    return self:_next()
  end
end

function Tokenizer:_next()
  local token = self:_read_next()
  if token ~= nil and token.type ~= false then self.last_token = token.type end
  return token
end

local function integer_context(n)
  if n == "b" then return "binary" end
  if n == "o" then return "octal" end
  if n == "x" then return "hexadecimal" end
end

local function munch_underscores(s)
  local s2, _ = s:gsub("_", "")
  return s2
end

local function valid_float(s)
  return s:match("^[+-]?%d[0-9_]*(%.%d[0-9_]*)$") or
    s:match("^[+-]?%d[0-9_]*$") or
    s:match("^[+-]?%d[0-9_]*([eE][+-]?%d[0-9_]*)$") or
    s:match("^[+-]?%d[0-9_]*(%.%d[0-9_]*)([eE][+-]?%d[0-9_]*)$")
end

local function valid_integer(s)
  return s:match("^[+-]?%d[0-9_]*$")
end

local function parse_decimal(s)
  if s:match("[.eE]") and valid_float(s) then
    return { type="FLOAT", value=tonumber(munch_underscores(s)) }
  elseif valid_integer(s) then
    return { type="INTEGER", value=tonumber(munch_underscores(s), 10) }
  else
    if table.contains(util.NON_INITIAL_IDENTIFIER_CHARS, utf8.sub(s, 1, 1)) then error("Invalid number: "..s) end
    for i = 2,utf8.len(s) do
      if table.contains(util.NON_IDENTIFIER_CHARS, utf8.sub(s, i, i)) then error("Invalid number: "..s) end
    end
    return { type="IDENT", value=s }
  end
end

local function parse_hexadecimal(s)
  if s:match("^[+-]?%x[0-9a-fA-F_]*$") then
    return { type="INTEGER", value=tonumber(munch_underscores(s), 16)}
  end
  error("Invalid hexadecimal: "..s)
end

local function parse_octal(s)
  if s:match("^[+-]?[0-7][0-7_]*$") then
    return { type="INTEGER", value=tonumber(munch_underscores(s), 8)}
  end
  error("Invalid octal: "..s)
end

local function parse_binary(s)
  if s:match("^[+-]?[01][01_]*$") then
    return { type="INTEGER", value=tonumber(munch_underscores(s), 2)}
  end
  error("Invalid binary: "..s)
end

local function convert_escapes(str)
  local function char(i)
    if i < 0 or i > utf8.len(str) then
      return nil
    end
    return utf8.sub(str, i, i)
  end

  local i = 1
  local buffer = ""
  while i <= utf8.len(str) do
    local c = char(i)
    if c == nil then
      return buffer
    elseif c == "\\" then
      local c2 = char(i+1)
      if c2 == nil then return buffer
      elseif c2 == "n" then buffer = buffer.."\n"; i = i+1
      elseif c2 == "r" then buffer = buffer.."\r"; i = i+1
      elseif c2 == "t" then buffer = buffer.."\t"; i = i+1
      elseif c2 == "\\" then buffer = buffer.."\\"; i = i+1
      elseif c2 == '"' then buffer = buffer..'"'; i = i+1
      elseif c2 == "b" then buffer = buffer.."\b"; i = i+1
      elseif c2 == "f" then buffer = buffer.."\f"; i = i+1
      elseif c2 == "s" then buffer = buffer.." "; i = i+1
      elseif c2 == "u" then
        local c2 = char(i+2)
        if c2 ~= "{" then error("Invalid unicode escape") end
        local hex = ""
        local j = i+3
        local cj = char(j)
        while cj and cj:match("%x") do
          hex = hex..cj
          j = j+1
          cj = char(j)
        end
        if #hex > 6 or char(j) ~= "}" then error("Invalid unicode escape: \\u{"..hex.."}") end
        local code = tonumber(hex, 16)
        if not code then error("Invalid unicode escape: "..hex) end
        if code < 0 or code > 0x10FFFF then error(string.format("Invalid code point \\u{%x}", code)) end
        i = j
        buffer = buffer..utf8.char(code)
      elseif table.contains(util.WHITESPACE, c2) or table.contains(util.NEWLINES, c2) then
        local j = i+2
        local cj = char(j)
        while table.contains(util.WHITESPACE, cj) or table.contains(util.NEWLINES, cj) do
          j = j+1
          cj = char(j)
        end
        i = j-1
      else
        error("Unexpected escape: \\"..c2)
      end
    else buffer = buffer..c
    end
    i = i+1
  end

  return buffer
end

local function unindent(s)
  local all = s:lines()
  local indent = all[#all]
  local lines = {}
  table.move(all, 1, #all-1, 1, lines)

  if #indent ~= 0 then
    for i=1,utf8.len(indent) do
      if not table.contains(util.WHITESPACE, utf8.sub(indent,i,i)) then
        error("Invalid muliline string final line: '"..indent.."'")
      end
    end
    for _, line in pairs(lines) do
      if not line:starts(indent) then
        error("Invalid multiline string indentation")
      end
    end
  end

  local result = ""
  for i, line in pairs(lines) do
    result = result..utf8.sub(line, utf8.len(indent)+1)
    if i < #lines then result = result.."\n" end
  end

  return result
end

function Tokenizer:_read_next()
  self.context = nil
  self.previous_context = nil
  while true do
    ::continue::
    local c = self:char(self.index)
    if self.context == nil then
      if c == '"' then
        self.buffer = ""
        if self:char(self.index + 1) == "\n" then
          self:set_context("multi_line_string")
          self.index = self.index + 2
        else
          self:set_context("string")
          self.index = self.index + 1
        end
      elseif c == "#" then
        if self:char(self.index + 1) == '"' then
          self.rawstring_hashes = 1
          self.buffer = ""
          if self:char(self.index + 2) == "\n" then
            self:set_context("multi_line_rawstring")
            self.index = self.index + 3
          else
            self:set_context("rawstring")
            self.index = self.index + 2
          end
          goto continue
        elseif self:char(self.index + 1) == "#" then
          local i = self.index + 1
          self.rawstring_hashes = 1
          while self:char(i) == "#" do
            self.rawstring_hashes = self.rawstring_hashes + 1
            i = i + 1
          end
          if self:char(i) == '"' then
            self.buffer = ""
            if self:char(i + 1) == "\n" then
              self:set_context("multi_line_rawstring")
              self.index = i + 2
            else
              self:set_context("rawstring")
              self.index = i + 1
            end
            goto continue
          end
        end
        self:set_context("keyword")
        self.buffer = c
        self.index = self.index + 1
      elseif c == "-" then
        local n = self:char(self.index + 1)
        local n2 = self:char(self.index + 2)
        if n ~= nil and n:match("%d") then
          if n == "0" and n2 ~= nil and n2:match("[box]") then
            self:set_context(integer_context(n2))
            self.index = self.index + 2
          else
            self:set_context("decimal")
          end
        else
          self:set_context("ident")
        end
        self.buffer = c
        self.index = self.index + 1
      elseif c ~= nil and c:match("[0-9+]") then
        local n = self:char(self.index + 1)
        local n2 = self:char(self.index + 2)
        if c == "0" and n ~= nil and n:match("[box]") then
          self.index = self.index + 2
          self.buffer = ""
          self:set_context(integer_context(n))
        elseif c == "+" and n == "0" and n2 ~= nil and n2:match("[box]") then
          self.index = self.index + 3
          self.buffer = c
          self:set_context(integer_context(n2))
        else
          self:set_context("decimal")
          self.index = self.index + 1
          self.buffer = c
        end
      elseif c == "\\" then
        local t = tokenizer.new(self.str, self.index + 1)
        local la = t:next()
        if la.type == "NEWLINE" or la.type == "EOF" then
          self.index = t.index
          self:set_context("whitespace")
          self.buffer = c..la.value
          goto continue
        elseif la.type == "WS" then
          local lan = t:next()
          if lan.type == "NEWLINE" or lan.type == "EOF" then
            self.index = t.index
            self:set_context("whitespace")
            self.buffer = c..la.value
            if lan.type == "NEWLINE" then
              self.buffer = self.buffer.."\n"
            end
            goto continue
          end
        end
        error("Unexpected '\\")
      elseif table.contains(util.EQUALS, c) then
        self:set_context("equals")
        self.buffer = c
        self.index = self.index + 1
      elseif util.SYMBOLS[c] then
        self.index = self.index + 1
        return { type=util.SYMBOLS[c], value=c }
      elseif c == "\r" then
        local n = self:char(self.index + 1)
        if n == "\n" then
          self.index = self.index + 2
          return { type="NEWLINE", value=c..n }
        else
          self.index = self.index + 1
          return { type="NEWLINE", value=c }
        end
      elseif table.contains(util.NEWLINES, c) then
        self.index = self.index + 1
        return { type="NEWLINE", value=c }
      elseif c == "/" then
        local n = self:char(self.index + 1)
        if n == "/" then
          if self.in_type or self.last_token == "RPAREN" then error("Unexpected '/'") end
          self:set_context("single_line_comment")
          self.index = self.index + 2
        elseif n == "*" then
          self:set_context("multi_line_comment")
          self.comment_nesting = 1
          self.index = self.index + 2
        elseif n == "-" then
          self.index = self.index + 2
          return { type="SLASHDASH", value="/-" }
        else
          error("Unexpected '"..c.."'")
        end
      elseif table.contains(util.WHITESPACE, c) then
        self:set_context("whitespace")
        self.buffer = c
        self.index = self.index + 1
      elseif c == nil then
        if self.done then return { type=false, value=false } end
        self.done = true
        return { type="EOF", value="" }
      elseif not table.contains(util.NON_INITIAL_IDENTIFIER_CHARS, c) then
        self:set_context("ident")
        self.buffer = c
        self.index = self.index + 1
      elseif c == "(" then
        self.in_type = true
        self.index = self.index + 1
        return { type="LPAREN", value=c }
      elseif c == ")" then
        self.in_type = false
        self.index = self.index + 1
        return { type="RPAREN", value=c }
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "ident" then
      if c ~= nil and not table.contains(util.NON_IDENTIFIER_CHARS, c) then
        self.index = self.index + 1
        self.buffer = self.buffer..c
      else
        if table.contains(util.RESERVED, self.buffer) then
          error("Identifier cannot be a literal")
        elseif self.buffer:match("^%.%d") then
          error("Identifier cannot look like an illegal float")
        else
          return { type="IDENT", value=self.buffer }
        end
      end
    elseif self.context == "keyword" then
      if c ~= nil and c:match("[a-z%-]") then
        self.index = self.index + 1
        self.buffer = self.buffer..c
      else
        if self.buffer == "#true" then return { type="TRUE", value=true } end
        if self.buffer == "#false" then return { type="FALSE", value=false } end
        if self.buffer == "#null" then return { type="NULL", value=nil } end
        if self.buffer == "#inf" then return { type="FLOAT", value=math.huge } end
        if self.buffer == "#-inf" then return { type="FLOAT", value=-math.huge } end
        if self.buffer == "#nan" then return { type="FLOAT", value=-(0/0) } end
        error("Unknown keyword "..self.buffer)
      end
    elseif self.context == "string" or self.context == "multi_line_string" then
      if c == "\\" then
        self.buffer = self.buffer..c
        self.buffer = self.buffer..self:char(self.index + 1)
        self.index = self.index + 2
      elseif c == '"' then
        self.index = self.index + 1
        local string = self.buffer
        if self.context == "multi_line_string" then string = unindent(string) end
        string = convert_escapes(string)
        return { type="STRING", value=string }
      elseif c == nil or c == "" then
        error("Unterminated string literal")
      else
        self.buffer = self.buffer..c
        self.index = self.index + 1
      end
    elseif self.context == "rawstring" or self.context == "multi_line_rawstring" then
      if c == nil or c == "" then
        error("Unterminated rawstring literal")
      end

      if c == '"' then
        local h = 0
        while self:char(self.index + 1 + h) == "#" and h < self.rawstring_hashes do
          h = h + 1
        end
        if h == self.rawstring_hashes then
          self.index = self.index + 1 + h
          local string = self.buffer
          if self.context == "multi_line_rawstring" then string = unindent(string) end
          return { type="RAWSTRING", value=string }
        end
      end

      self.buffer = self.buffer..c
      self.index = self.index + 1
    elseif self.context == "decimal" then
      if c ~= nil and c:match("[0-9%.%-+_eE]") then
        self.index = self.index + 1
        self.buffer = self.buffer..c
      elseif table.contains(util.WHITESPACE, c) or table.contains(util.NEWLINES, c) or c == nil then
        return parse_decimal(self.buffer)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "hexadecimal" then
      if c ~= nil and c:match("[0-9a-fA-F_]") then
        self.index = self.index + 1
        self.buffer = self.buffer..c
      elseif table.contains(util.WHITESPACE, c) or table.contains(util.NEWLINES, c) or c == nil then
        return parse_hexadecimal(self.buffer)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "octal" then
      if c ~= nil and c:match("[0-7_]") then
        self.index = self.index + 1
        self.buffer = self.buffer..c
      elseif table.contains(util.WHITESPACE, c) or table.contains(util.NEWLINES, c) or c == nil then
        return parse_octal(self.buffer)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "binary" then
      if c ~= nil and c:match("[01_]") then
        self.index = self.index + 1
        self.buffer = self.buffer..c
      elseif table.contains(util.WHITESPACE, c) or table.contains(util.NEWLINES, c) or c == nil then
        return parse_binary(self.buffer)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "single_line_comment" then
      if table.contains(util.NEWLINES, c) or c == "\r" then
        self:set_context(nil)
        goto continue
      elseif c == nil then
        self.done = true
        return { type="EOF", value="" }
      else
        self.index = self.index + 1
      end
    elseif self.context == "multi_line_comment" then
      local n = self:char(self.index + 1)
      if c == "/" and n == "*" then
        self.comment_nesting = self.comment_nesting + 1
        self.index = self.index + 2
      elseif c == "*" and n == "/" then
        self.comment_nesting = self.comment_nesting - 1
        self.index = self.index + 2
        if self.comment_nesting == 0 then self:revert_context() end
      else
        self.index = self.index + 1
      end
    elseif self.context == "whitespace" then
      if table.contains(util.WHITESPACE, c) then
        self.index = self.index + 1
        self.buffer = self.buffer..c
      elseif table.contains(util.EQUALS, c) then
        self:set_context("equals")
        self.buffer = self.buffer..c
        self.index = self.index + 1
      elseif c == "\\" then
        local t = tokenizer.new(self.str, self.index + 1)
        local la = t:next()
        if la.type == "NEWLINE" or la.type == "EOF" then
          self.index = t.index
          self.buffer = self.buffer..c..la.value
          goto continue
        elseif la.type == "WS" then
          local lan = t:next()
          if lan.type == "NEWLINE" or lan.type == "EOF" then
            self.index = t.index
            self.buffer = self.buffer..c..la.value
            if lan.type == "NEWLINE" then
              self.buffer = self.buffer.."\n"
            end
            goto continue
          end
        end
        error("Unexpected '\\'")
      elseif c == "/" and self:char(self.index + 1) == "*" then
        self:set_context("multi_line_comment")
        self.comment_nesting = 1
        self.index = self.index + 2
      else
        return { type="WS", value=self.buffer }
      end
    elseif self.context == "equals" then
      local t = tokenizer.new(self.str, self.index)
      local la = t:next()
      if la.type == "WS" then
        self.buffer = self.buffer..la.value
        self.index = t.index
      end
      return { type="EQUALS", value=self.buffer }
    elseif self.context == nil then
      error("Unexpected nil context")
    else
      error("Unexpected context "..self.context)
    end
  end
end

function Tokenizer:char(i)
  if i < 1 or i > utf8.len(self.str) then return nil end
  local c = utf8.sub(self.str, i, i)
  for _, value in pairs(util.FORBIDDEN) do
    if c == value then error("Forbidden character: "..c) end
  end
  return c
end

function Tokenizer:revert_context()
  self.context = self.previous_context
  self.previous_context = nil
end

return tokenizer