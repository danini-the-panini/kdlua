local utf8 = require "lua-utf8"

local util = require "kdl.util"

local stringdumper = {}

local FORBIDDEN = { "(", ")", "[", "]", "/", "\\", '"', "#" }
for k, _ in pairs(util.SYMBOLS) do table.insert(FORBIDDEN, k) end
for _, v in pairs(util.WHITESPACE) do table.insert(FORBIDDEN, v) end
for _, v in pairs(util.NEWLINES) do table.insert(FORBIDDEN, v) end
for i=0,0x20 do table.insert(FORBIDDEN, utf8.char(i)) end

local function is_identifier(string)
  if string == "" or
  string == "true" or
  string == "false" or
  string == "null" or
  string == "inf" or
  string == "-inf" or
  string == "nan" or
  string:match("^%.?%d") then
    return false
  end

  for i=1,utf8.len(string) do
    if table.contains(FORBIDDEN, utf8.sub(string,i,i)) then
      return false
    end
  end

  return true
end

local function escape(c)
  if c == "\n" then return "\\n" end
  if c == "\r" then return "\\r" end
  if c == "\t" then return "\\t" end
  if c == "\\" then return "\\\\" end
  if c == '"' then return '\\"' end
  if c == "\b" then return "\\b" end
  if c == "\f" then return "\\f" end
  return c
end

function stringdumper.dump(string)
  if is_identifier(string) then return string end

  local s = '"'
  for i=1,utf8.len(string) do
    s = s..escape(utf8.sub(string,i,i))
  end
  return s..'"'
end

return stringdumper