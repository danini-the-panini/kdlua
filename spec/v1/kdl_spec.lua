local lfs = require "lfs"
local kdl = require "kdl"
require "spec.support"

describe("kdl", function()
  local ignore_list = {"escline_comment_node"}
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

  local TEST_CASES = "spec/v1/kdl-org/tests/test_cases"
  for file in lfs.dir(TEST_CASES.."/input") do
    local ignored = false
    for _, i in ipairs(ignore_list) do
      if file:match(i) then ignored = true; break end
    end
    if not ignored and file ~= "." and file ~= ".." then
      local input = TEST_CASES.."/input/"..file
      local expected = TEST_CASES.."/expected_kdl/"..file
      if exists(expected) then
        it("parses "..input, function()
          assert.valid_kdl(readfile(input), readfile(expected), 1)
        end)
      else
        it("does not parse "..input, function()
          assert.is_not.valid_kdl(readfile(input), 1)
        end)
      end
    end
  end
end)
