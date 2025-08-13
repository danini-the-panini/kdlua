local kdl = { _version = "dev" }

local parser = require "kdl.parser"
local tokenizer = require "kdl.tokenizer"
local parser_v1 = require "kdl.v1.parser"

function kdl.parse_document(str, version)
  if not version then
    local t = tokenizer.new(str)
    version = t:version_directive()
    if not version then
      local success, result = pcall(parser.parse, str)
      if success then return result end
      return parser_v1.parse(str)
    end
  end

  if version == 1 then
    return parser_v1.parse(str)
  elseif version == 2 then
    return parser.parse(str)
  else
    error("Unrecognised version '"..version.."'")
  end
end

return kdl
