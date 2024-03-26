local kdl = { _version = "dev" }

local parser = require "kdl.parser"

function kdl.parse_document(str)
  return parser.parse(str)
end

return kdl