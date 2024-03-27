describe("kdl", function()
  local lfs = require "lfs"
  local kdl = require "kdl"

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

  local function parse(str)
    local ok, r = xpcall(kdl.parse_document, debug.traceback, str)
    if ok then return r else error(r) end
  end

  local TEST_CASES = "spec/kdl-org/tests/test_cases"
  for file in lfs.dir(TEST_CASES.."/input") do
    if file ~= "." and file ~= ".." then
      local input = TEST_CASES.."/input/"..file
      local expected = TEST_CASES.."/expected_kdl/"..file
      if exists(expected) then
        it("parses "..input, function()
          assert.equals(readfile(expected), tostring(parse(readfile(input))))
        end)
      else
        it("does not parse "..input, function()
          assert.has_error(function() kdl.parse_document(readfile(input)) end)
        end)
      end
    end
  end
end)
