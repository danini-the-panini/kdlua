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
    last_token=nil,
    line=1,
    column=1,
    line_at_start=1,
    column_at_start=1
  }
  setmetatable(self, { __index = Tokenizer })
  return self
end

function Tokenizer:version_directive()
  local match = self.str:match(util.VERSION_PATTERN)
  return match and tonumber(match)
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

local function unescape_ws(str)
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
      elseif c2 == "\\" then buffer = buffer.."\\"; i = i+1
      elseif c2 == "s" then buffer = buffer.." "; i = i+1
      elseif table.contains(util.WHITESPACE, c2) or table.contains(util.NEWLINES, c2) then
        local j = i+2
        local cj = char(j)
        while table.contains(util.WHITESPACE, cj) or table.contains(util.NEWLINES, cj) do
          j = j+1
          cj = char(j)
        end
        i = j-1
      else buffer = buffer + c
      end
    else buffer = buffer..c
    end
    i = i+1
  end

  return buffer
end

local function convert_escapes(str, ws)
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
        c2 = char(i+2)
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
        if code < 0 or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF) then
          error(string.format("Invalid code point \\u{%x}", code))
        end
        i = j
        buffer = buffer..utf8.char(code)
      elseif ws and (table.contains(util.WHITESPACE, c2) or table.contains(util.NEWLINES, c2)) then
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

local function unescape(str)
  return convert_escapes(str, true)
end

local function unescape_non_ws(str)
  return convert_escapes(str, false)
end

local function dedent(str)
  local lines = util.lines(str)
  local indent = table.remove(lines, #lines)
  if not indent:match("^"..util.wss.."$") then
    error("Invalid multi-line string final line")
  end

  local valid = indent.."(.*)"

  local result = {}
  for _,line in ipairs(lines) do
    if line:match("^"..util.wss.."$") then
      table.insert(result, '')
      goto continue
    end
    local m = line:match(valid)
    if m then
      table.insert(result, m)
      goto continue
    end
    error("Invalid multi-line string indentation")
    ::continue::
  end

  return table.join(result, "\n")
end

function Tokenizer:_read_next()
  self.context = nil
  self.previous_context = nil
  while true do
    ::continue::
    local c = self:char(self.index)
    if self.context == nil then
      if c == nil then
        if self.done then
          return self:_token("EOF", nil)
        end
        self.done = true
        return self:_token("EOF", "")
      elseif c == '"' then
        self.buffer = ""
        if self:char(self.index + 1) == '"' and self:char(self.index + 2) == '"' then
          local nl = self:expect_newline(self.index + 3)
          self:set_context("multi_line_string")
          self:traverse(3 + utf8.len(nl))
        else
          self:set_context("string")
          self:traverse(1)
        end
      elseif c == "#" then
        if self:char(self.index + 1) == '"' then
          self.buffer = ""
          self.rawstring_hashes = 1
          if self:char(self.index + 2) == '"' and self:char(self.index + 3) == '"' then
            local nl = self:expect_newline(self.index + 4)
            self:set_context("multi_line_rawstring")
            self:traverse(utf8.len(nl) + 4)
          else
            self:set_context("rawstring")
            self:traverse(2)
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
            if self:char(i + 1) == '"' and self:char(i + 2) == '"' then
              local nl = self:expect_newline(i + 3)
              self:set_context("multi_line_rawstring")
              self:traverse(self.rawstring_hashes + 3 + utf8.len(nl))
            else
              self:set_context("rawstring")
              self:traverse(self.rawstring_hashes + 1)
            end
            goto continue
          end
        end
        self:set_context("keyword")
        self.buffer = c
        self:traverse(1)
      elseif c == "-" then
        local n = self:char(self.index + 1)
        local n2 = self:char(self.index + 2)
        if n ~= nil and n:match("%d") then
          if n == "0" and n2 ~= nil and n2:match("[box]") then
            self:set_context(integer_context(n2))
            self:traverse(2)
          else
            self:set_context("decimal")
          end
        else
          self:set_context("ident")
        end
        self.buffer = c
        self:traverse(1)
      elseif c ~= nil and c:match("[0-9+]") then
        local n = self:char(self.index + 1)
        local n2 = self:char(self.index + 2)
        if c == "0" and n ~= nil and n:match("[box]") then
          self.buffer = ""
          self:set_context(integer_context(n))
          self:traverse(2)
        elseif c == "+" and n == "0" and n2 ~= nil and n2:match("[box]") then
          self.buffer = c
          self:set_context(integer_context(n2))
          self:traverse(3)
        else
          self.buffer = c
          self:set_context("decimal")
          self:traverse(1)
        end
      elseif c == "\\" then
        local t = tokenizer.new(self.str, self.index + 1)
        local la = t:next()
        if la.type == "NEWLINE" or la.type == "EOF" then
          self.buffer = c..la.value
          self:set_context("whitespace")
          self:traverse_to(t.index)
          goto continue
        elseif la.type == "WS" then
          local lan = t:next()
          if lan.type == "NEWLINE" or lan.type == "EOF" then
            self.buffer = c..la.value
            if lan.type == "NEWLINE" then
              self.buffer = self.buffer.."\n"
            end
            self:set_context("whitespace")
            self:traverse_to(t.index)
            goto continue
          end
        end
        error([[Unexpected '\']])
      elseif c == "=" then
        self.buffer = c
        self:set_context("equals")
        self:traverse(1)
      elseif util.SYMBOLS[c] then
        self:traverse(1)
        return self:_token(util.SYMBOLS[c], c)
      elseif c == "\r" or table.contains(util.NEWLINES, c) then
        local nl = self:expect_newline(self.index)
        self:traverse(utf8.len(nl))
        return self:_token("NEWLINE", nl)
      elseif c == "/" then
        local n = self:char(self.index + 1)
        if n == "/" then
          if self.in_type or self.last_token == "RPAREN" then error("Unexpected '/'") end
          self:set_context("single_line_comment")
          self:traverse(2)
        elseif n == "*" then
          self:set_context("multi_line_comment")
          self.comment_nesting = 1
          self:traverse(2)
        elseif n == "-" then
          self:traverse(2)
          return self:_token("SLASHDASH", "/-")
        else
          error("Unexpected '"..c.."'")
        end
      elseif table.contains(util.WHITESPACE, c) then
        self.buffer = c
        self:set_context("whitespace")
        self:traverse(1)
      elseif not table.contains(util.NON_INITIAL_IDENTIFIER_CHARS, c) then
        self.buffer = c
        self:set_context("ident")
        self:traverse(1)
      elseif c == "(" then
        self.in_type = true
        self:traverse(1)
        return self:_token("LPAREN", c)
      elseif c == ")" then
        self.in_type = false
        self:traverse(1)
        return self:_token("RPAREN", c)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "ident" then
      if c ~= nil and not table.contains(util.NON_IDENTIFIER_CHARS, c) then
        self.buffer = self.buffer..c
        self:traverse(1)
      else
        if table.contains(util.RESERVED, self.buffer) then
          error("Identifier cannot be a literal")
        elseif self.buffer:match("^%.%d") then
          error("Identifier cannot look like an illegal float")
        else
          return self:_token("IDENT", self.buffer)
        end
      end
    elseif self.context == "keyword" then
      if c ~= nil and c:match("[a-z%-]") then
        self.buffer = self.buffer..c
        self:traverse(1)
      else
        if self.buffer == "#true" then return self:_token("TRUE", true) end
        if self.buffer == "#false" then return self:_token("FALSE", false) end
        if self.buffer == "#null" then return self:_token("NULL", nil) end
        if self.buffer == "#inf" then return self:_token("FLOAT", math.huge) end
        if self.buffer == "#-inf" then return self:_token("FLOAT", -math.huge) end
        if self.buffer == "#nan" then return self:_token("FLOAT", -(0/0)) end
        error("Unknown keyword "..self.buffer)
      end
    elseif self.context == "string" then
      if c == "\\" then
        self.buffer = self.buffer..c
        local c2 = self:char(self.index + 1)
        self.buffer = self.buffer..c2
        if table.contains(util.NEWLINES, c2) then
          local i = 2
          c2 = self:char(self.index + i)
          while table.contains(util.NEWLINES, c2) do
            self.buffer = self.buffer..c2
            i = i + 1
            c2 = self:char(self.index + i)
          end
          self:traverse(i)
        else
          self:traverse(2)
        end
      elseif c == '"' then
        self:traverse(1)
        return self:_token("STRING", unescape(self.buffer))
      elseif c == "" or c == nil then
        error("Unterminated string literal")
      else
        if table.contains(util.NEWLINES, c) then
          error("Unexpected NEWLINE in single-line string")
        end
        self.buffer = self.buffer..c
        self:traverse(1)
      end
    elseif self.context == "multi_line_string" then
      if c == "\\" then
        self.buffer = self.buffer..c..self:char(self.index + 1)
        self:traverse(1)
      elseif c == '"' then
        if self:char(self.index + 1) == '"' and self:char(self.index + 2) == '"' then
          self:traverse(3)
          return self:_token("STRING", unescape_non_ws(dedent(unescape_ws(self.buffer))))
        end
        self.buffer = self.buffer..c
        self:traverse(1)
      elseif c == "" or c == nil then
        error("Unterminated multi-line string literal")
      else
        self.buffer = self.buffer..c
        self:traverse(1)
      end
    elseif self.context == "rawstring" then
      if c == nil or c == "" then
        error("Unterminated rawstring literal")
      end

      if c == '"' then
        local h = 0
        while self:char(self.index + 1 + h) == "#" and h < self.rawstring_hashes do
          h = h + 1
        end
        if h == self.rawstring_hashes then
          self:traverse(1 + h)
          return self:_token("RAWSTRING", self.buffer)
        end
      elseif table.contains(util.NEWLINES, c) then
        error("Unexpected NEWLINE in single-line rawstring")
      end

      self.buffer = self.buffer..c
      self:traverse(1)
    elseif self.context == "multi_line_rawstring" then
      if c == nil or c == "" then
        error("Unterminated multi-line rawstring literal")
      end

      if c == '"' and
        self:char(self.index + 1) == '"' and
        self:char(self.index + 2) == '"' and
        self:char(self.index + 3) == '#' then

        local h = 1
        while self:char(self.index + 3 + h) == "#" and h < self.rawstring_hashes do
          h = h + 1
        end
        if h == self.rawstring_hashes then
          self:traverse(h + 3)
          return self:_token("RAWSTRING", dedent(self.buffer))
        end
      end

      self.buffer = self.buffer..c
      self:traverse(1)
    elseif self.context == "decimal" then
      if c ~= nil and c:match("[0-9%.%-+_eE]") then
        self.buffer = self.buffer..c
        self:traverse(1)
      elseif table.contains(util.WHITESPACE, c) or table.contains(util.NEWLINES, c) or c == nil then
        return parse_decimal(self.buffer)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "hexadecimal" then
      if c ~= nil and c:match("[0-9a-fA-F_]") then
        self.buffer = self.buffer..c
        self:traverse(1)
      elseif table.contains(util.WHITESPACE, c) or table.contains(util.NEWLINES, c) or c == nil then
        return parse_hexadecimal(self.buffer)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "octal" then
      if c ~= nil and c:match("[0-7_]") then
        self.buffer = self.buffer..c
        self:traverse(1)
      elseif table.contains(util.WHITESPACE, c) or table.contains(util.NEWLINES, c) or c == nil then
        return parse_octal(self.buffer)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "binary" then
      if c ~= nil and c:match("[01_]") then
        self.buffer = self.buffer..c
        self:traverse(1)
      elseif table.contains(util.WHITESPACE, c) or table.contains(util.NEWLINES, c) or c == nil then
        return parse_binary(self.buffer)
      else
        error("Unexpected '"..c.."'")
      end
    elseif self.context == "single_line_comment" then
      if table.contains(util.NEWLINES, c) or c == "\r" then
        self:set_context(nil)
        self.column_at_start = self.column
        goto continue
      elseif c == nil then
        self.done = true
        return self:_token("EOF", "")
      else
        self:traverse(1)
      end
    elseif self.context == "multi_line_comment" then
      local n = self:char(self.index + 1)
      if c == "/" and n == "*" then
        self.comment_nesting = self.comment_nesting + 1
        self:traverse(2)
      elseif c == "*" and n == "/" then
        self.comment_nesting = self.comment_nesting - 1
        self:traverse(2)
        if self.comment_nesting == 0 then self:revert_context() end
      else
        self:traverse(1)
      end
    elseif self.context == "whitespace" then
      if table.contains(util.WHITESPACE, c) then
        self.buffer = self.buffer..c
        self:traverse(1)
      elseif c == "=" then
        self.buffer = self.buffer..c
        self:set_context("equals")
        self:traverse(1)
      elseif c == "\\" then
        local t = tokenizer.new(self.str, self.index + 1)
        local la = t:next()
        if la.type == "NEWLINE" or la.type == "EOF" then
          self.buffer = self.buffer..c..la.value
          self:traverse_to(t.index)
          goto continue
        elseif la.type == "WS" then
          local lan = t:next()
          if lan.type == "NEWLINE" or lan.type == "EOF" then
            self.buffer = self.buffer..c..la.value
            if lan.type == "NEWLINE" then
              self.buffer = self.buffer.."\n"
            end
            self:traverse_to(t.index)
            goto continue
          end
        end
        error([[Unexpected '\']])
      elseif c == "/" and self:char(self.index + 1) == "*" then
        self.comment_nesting = 1
        self:set_context("multi_line_comment")
        self:traverse(2)
      else
        return self:_token("WS", self.buffer)
      end
    elseif self.context == "equals" then
      local t = tokenizer.new(self.str, self.index)
      local la = t:next()
      if la.type == "WS" then
        self.buffer = self.buffer..la.value
        self:traverse_to(t.index)
      end
      return self:_token("EQUALS", self.buffer)
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

function Tokenizer:_token(type, value)
  return { type=type, value=value, line=self.line_at_start, column=self.column_at_start }
end

function Tokenizer:traverse(n)
  n = n or 1
  for i = 0,n-1 do
    local c = self:char(self.index + i)
    if c == "\r" then
      self.column = 1
    elseif table.contains(util.NEWLINES, c) then
      self.line = self.line + 1
      self.column = 1
    else
      self.column = self.column + 1
    end
  end
  self.index = self.index + n
end

function Tokenizer:traverse_to(i)
  self:traverse(i - self.index)
end

function Tokenizer:revert_context()
  self.context = self.previous_context
  self.previous_context = nil
end

function Tokenizer:expect_newline(i)
  local c = self:char(i)
  if c == "\r" then
    local n = self:char(i + 1)
    if n == "\n" then return c..n end
  elseif not table.contains(util.NEWLINES, c) then
    error("Expected NEWLINE, found '"..c.."'")
  end
  return c
end

return tokenizer
