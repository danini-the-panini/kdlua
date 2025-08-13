local lfs = require "lfs"
local kdl = require "kdl"
require "spec.support"

describe("kdl", function()
  it("detects version", function()
    -- parses either v1 or v2
    assert.valid_kdl("node foo #true", "node foo #true")
    assert.valid_kdl("node \"foo\" true", "node foo #true")

    -- chooses parser based on version directive
    assert.valid_kdl("/- kdl-version 1\nnode \"foo\" true", "node foo #true")
    assert.valid_kdl("/- kdl-version 2\nnode foo #true", "node foo #true")

    -- fails parsing if syntax does not match version directive
    assert.is_not.valid_kdl("/- kdl-version 1\nnode foo #true", "Expected EQUALS, got WS (2:9)")
    assert.is_not.valid_kdl("/- kdl-version 2\nnode \"foo\" true", "Identifier cannot be a literal (2:12)")

    -- fails parsing mixed syntax
    assert.is_not.valid_kdl("node foo true", "Expected EQUALS, got WS (1:9)")
    assert.is_not.valid_kdl("node r\"foo\" #true", "Expected EQUALS, got EOF (1:18)")
  end)

  local function exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
  end

  local function readfile(filename)
    local f = assert(io.open(filename, "r"))
    local s = f:read("a")
    f:close()
    return s
  end

  local TEST_CASES = "spec/kdl-org/tests/test_cases"
  for file in lfs.dir(TEST_CASES.."/input") do
    if file ~= "." and file ~= ".." then
      local input = TEST_CASES.."/input/"..file
      local expected = TEST_CASES.."/expected_kdl/"..file
      if exists(expected) then
        it("parses "..input, function()
          assert.valid_kdl(readfile(input), readfile(expected), 2)
        end)
      else
        it("does not parse "..input, function()
          assert.is_not.valid_kdl(readfile(input), 2)
        end)
      end
    end
  end
end)
