local assert = require 'luassert.assert'
local util = require "luassert.util"
local say = require "say"
local kdl = require "kdl"

local function valid_kdl(state, args)
  local success, result = pcall(kdl.parse_document, args[1])
  local result_str = tostring(result)
  local expected = args[2]
  if expected then
    args[2] = tostring(expected)
    table.insert(args, result_str)
    if success then
      if type(expected) == "string" then
        return result_str == expected or
          util.deepcompare(result, kdl.parse_document(expected), true)
      else
        return util.deepcompare(result, expected, true) or
          result_str == tostring(expected)
      end
    else
      return result:gsub('^.-:%d+: ', '', 1) ~= tostring(expected)
    end
  else
    if success then table.insert(args, "(error)")
    else table.insert(args, "(no error)") end
    table.insert(args, result_str)
  end
  return success
end

say:set("assertion.valid_kdl.positive", "Expected valid KDL.\nInput:\n%s\nExpected:\n%s\nActual:\n'%s'")
say:set("assertion.valid_kdl.negative", "Expected invalid KDL.\nInput:\n%s\nExpected:\n%s\nActual:\n'%s'")
assert:register("assertion", "valid_kdl", valid_kdl, "assertion.valid_kdl.positive", "assertion.valid_kdl.negative")
