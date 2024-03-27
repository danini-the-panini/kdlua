local utf8 = require "lua-utf8"

function table.contains(t, x)
  for _, value in pairs(t) do
    if value == x then return true end
  end
  return false
end

function string:starts(with)
  return utf8.sub(self,1,utf8.len(with)) == with
end

local util = {}

util.EQUALS = {"=", "﹦", "＝", "🟰"}

util.SYMBOLS = {
  ["{"]="LBRACE",
  ["}"]="RBRACE",
  [";"]="SEMICOLON"
}
for _, value in pairs(util.EQUALS) do
  util.SYMBOLS[value] = "EQUALS"
end

util.DIGITS = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }

util.WHITESPACE = {
  "\u{0009}", "\u{000B}", "\u{0020}", "\u{00A0}",
  "\u{1680}", "\u{2000}", "\u{2001}", "\u{2002}",
  "\u{2003}", "\u{2004}", "\u{2005}", "\u{2006}",
  "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}",
  "\u{202F}", "\u{205F}", "\u{3000}"
}

util.NEWLINES = { "\u{000A}", "\u{0085}", "\u{000C}", "\u{2028}", "\u{2029}" }

util.NON_IDENTIFIER_CHARS = {
  nil,
  "\r", "\\", "[", "]", "(", ")", '"', "/", "#"
}
for _, value in pairs(util.WHITESPACE) do table.insert(util.NON_IDENTIFIER_CHARS, value) end
for _, value in pairs(util.NEWLINES) do table.insert(util.NON_IDENTIFIER_CHARS, value) end
for key, _ in pairs(util.SYMBOLS) do table.insert(util.NON_IDENTIFIER_CHARS, key) end
for i = 0x0000, 0x0020 do table.insert(util.NON_IDENTIFIER_CHARS, utf8.char(i)) end

util.NON_INITIAL_IDENTIFIER_CHARS = {}
for _, value in pairs(util.NON_IDENTIFIER_CHARS) do table.insert(util.NON_INITIAL_IDENTIFIER_CHARS, value) end
for _, value in pairs(util.DIGITS) do table.insert(util.NON_INITIAL_IDENTIFIER_CHARS, value) end

util.FORBIDDEN = { "\u{007F}", "\u{FEFF}" }
for i = 0x0000, 0x0008 do table.insert(util.FORBIDDEN, utf8.char(i)) end
for i = 0x000E, 0x001F do table.insert(util.FORBIDDEN, utf8.char(i)) end
for i = 0x200E, 0x200F do table.insert(util.FORBIDDEN, utf8.char(i)) end
for i = 0x202A, 0x202E do table.insert(util.FORBIDDEN, utf8.char(i)) end
for i = 0x2066, 0x2069 do table.insert(util.FORBIDDEN, utf8.char(i)) end

util.RESERVED = { "true", "false", "null", "inf", "-inf", "nan" }

return util