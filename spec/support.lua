local assert = require 'luassert.assert'
local util = require "luassert.util"
local say = require "say"
local kdl = require "kdl"

local function valid_kdl(state, args)
  local expected = args[2]
  local version = args[3]
  args[3] = nil
  args.nofmt = { true, true, true}
  if not version and type(expected) == "number" then
    version = expected
    expected = nil
    args[2] = nil
  end
  local success, result = pcall(kdl.parse_document, args[1], version)
  local result_str = tostring(result)
  if expected then
    args[2] = tostring(expected)
    if success then
      table.insert(args, result_str)
      if type(expected) == "string" then
        if result_str == expected then return true end
        local s, r = pcall(kdl.parse_document, expected, version)
        if s then return util.deepcompare(result, r, true) end
        return true
      else
        return util.deepcompare(result, expected, true) or
          result_str == tostring(expected)
      end
    else
      result_str = result_str:gsub('^.-:%d+: ', '', 1)
      table.insert(args, result_str)
      return result_str ~= tostring(expected)
    end
  else
    if success then table.insert(args, "(error)")
    else table.insert(args, "(no error)") end
    table.insert(args, result_str)
  end
  return success
end

say:set("assertion.valid_kdl.positive", "Expected valid KDL.\nInput:\n%s\nExpected:\n%s\nActual:\n%s")
say:set("assertion.valid_kdl.negative", "Expected invalid KDL.\nInput:\n%s\nExpected:\n%s\nActual:\n%s")
assert:register("assertion", "valid_kdl", valid_kdl, "assertion.valid_kdl.positive", "assertion.valid_kdl.negative")
