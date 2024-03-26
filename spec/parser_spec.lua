describe("parser", function()
  local parser = require "kdl.parser"
  local document = require "kdl.document"
  local node = require "kdl.node"
  local value = require "kdl.value"

  local function parse(str)
    local ok, r = xpcall(parser.parse, debug.traceback, str)
    if ok then return r else error(r) end
  end

  it("parses empty string", function()
    assert.same(document.new(), parse(""))
    assert.same(document.new(), parse(" "))
    assert.same(document.new(), parse("\n"))
  end)

  it("parses nodes", function()
    assert.same(document.new{ node.new("node") }, parse("node"))
    assert.same(document.new{ node.new("node") }, parse("node\n"))
    assert.same(document.new{ node.new("node") }, parse("\nnode\n"))
    assert.same(
      document.new{
        node.new("node1"),
        node.new("node2")
      },
      parse("node1\nnode2")
    )
  end)

  it("parses node entries", function()
    assert.same(document.new{ node.new("node") }, parse("node;"))
    assert.same(document.new{ node.new("node", { value.new(1) }) }, parse("node 1"))
    assert.same(
      document.new{
        node.new("node", {
          value.new(1),
          value.new(2),
          value.new("3"),
          value.new(true),
          value.new(false),
          value.new(nil)
        }),
      },
      parse('node 1 2 "3" #true #false #null')
    )
    assert.same(document.new{ node.new("node", {}, { node.new("node2") }) }, parse("node {\n  node2\n}"))
    assert.same(document.new{ node.new("node", {}, { node.new("node2") }) }, parse("node {\n    node2    \n}"))
    assert.same(document.new{ node.new("node", {}, { node.new("node2") }) }, parse("node { node2; }"))
    assert.same(document.new{ node.new("node", {}, { node.new("node2") }) }, parse("node { node2 }"))
    assert.same(document.new{ node.new("node", {}, { node.new("node2"), node.new("node3") }) }, parse("node { node2; node3 }"))
  end)

  it("parses slashdash nodes", function()
    assert.same(document.new(), parse("/-node"))
    assert.same(document.new(), parse("/- node"))
    assert.same(document.new(), parse("/- node\n"))
    assert.same(document.new(), parse("/-node 1 2 3"))
    assert.same(document.new(), parse("/-node key=#false"))
    assert.same(document.new(), parse("/-node{\nnode\n}"))
    assert.same(document.new(), parse("/-node 1 2 3 key=\"value\" \\\n{\nnode\n}"))
  end);

  it("parses slashdash args", function()
    assert.same(document.new{ node.new("node") }, parse("node /-1"))
    assert.same(document.new{ node.new("node", { value.new(2) }) }, parse("node /-1 2"))
    assert.same(document.new{ node.new("node", { value.new(1), value.new(3) }) }, parse("node 1 /- 2 3"))
    assert.same(document.new{ node.new("node") }, parse("node /--1"))
    assert.same(document.new{ node.new("node") }, parse("node /- -1"))
    assert.same(document.new{ node.new("node") }, parse("node \\\n/- -1"))
  end)

  it("parses slashdash props", function()
    assert.same(document.new{ node.new("node") }, parse("node /-key=1"))
    assert.same(document.new{ node.new("node") }, parse("node /- key=1"))
    assert.same(document.new{ node.new("node", { ["key"]=value.new(1) }) }, parse("node key=1 /-key2=2"))
  end)

  it("parses slashdash children", function()
    assert.same(document.new{ node.new("node") }, parse("node /-{}"))
    assert.same(document.new{ node.new("node") }, parse("node /- {}"))
    assert.same(document.new{ node.new("node") }, parse("node /-{\nnode2\n}"))
  end)

  it('parses strings', function()
    assert.same(document.new{ node.new('node', { value.new("") }) }, parse('node ""'))
    assert.same(document.new{ node.new('node', { value.new("hello") }) }, parse('node "hello"'))
    assert.same(document.new{ node.new('node', { value.new("hello\nworld") }) }, parse([[node "hello\nworld"]]))
    assert.same(document.new{ node.new('node', { value.new("-flag") }) }, parse([[node -flag]]))
    assert.same(document.new{ node.new('node', { value.new("--flagg") }) }, parse([[node --flagg]]))
    assert.same(document.new{ node.new('node', { value.new("\u{10FFF}") }) }, parse([[node "\u{10FFF}"]]))
    assert.same(document.new{ node.new('node', { value.new("\"\\\u{08}\u{0C}\n\r\t") }) }, parse([[node "\"\\\b\f\n\r\t"]]))
    assert.same(document.new{ node.new('node', { value.new("\u{10}") }) }, parse([[node "\u{10}"]]))
    assert.has_error(function() parser.parse([[node "\i"]]) end, "Unexpected escape: \\i")
    assert.has_error(function() parser.parse([[node "\u{c0ffee}"]]) end, "Invalid code point \\u{c0ffee}")
  end)

  it("parses unindented multiline strings", function()
    assert.same(document.new{ node.new("node", { value.new("foo\nbar\n  baz\nqux") }) }, parse("node \"\n  foo\n  bar\n    baz\n  qux\n  \""))
    assert.same(document.new{ node.new("node", { value.new("foo\nbar\n  baz\nqux") }) }, parse("node #\"\n  foo\n  bar\n    baz\n  qux\n  \"#"))
    assert.has_error(function() parser.parse("node \"\n    foo\n  bar\n    baz\n    \"") end, "Invalid multiline string indentation")
    assert.has_error(function() parser.parse("node \"\n    foo\n  bar\n    baz\n  qux\"") end, "Invalid muliline string final line: '  qux'")
    assert.has_error(function() parser.parse("node #\"\n    foo\n  bar\n    baz\n    \"#") end, "Invalid multiline string indentation")
  end)

  it("parses floats", function()
    assert.same(document.new{ node.new("node", { value.new(1.0) }) }, parse("node 1.0"))
    assert.same(document.new{ node.new("node", { value.new(0.0) }) }, parse("node 0.0"))
    assert.same(document.new{ node.new("node", { value.new(-1.0) }) }, parse("node -1.0"))
    assert.same(document.new{ node.new("node", { value.new(1.0) }) }, parse("node +1.0"))
    assert.same(document.new{ node.new("node", { value.new(1.0e10) }) }, parse("node 1.0e10"))
    assert.same(document.new{ node.new("node", { value.new(1.0e-10) }) }, parse("node 1.0e-10"))
    assert.same(document.new{ node.new("node", { value.new(123456789.0) }) }, parse("node 123_456_789.0"))
    assert.same(document.new{ node.new("node", { value.new(123456789.0) }) }, parse("node 123_456_789.0_"))
    assert.has_error(function() parser.parse("node 1._0") end, "Invalid number: 1._0")
    assert.has_error(function() parser.parse("node 1.") end, "Invalid number: 1.")
    assert.has_error(function() parser.parse("node 1.0v2") end, "Unexpected 'v'")
    assert.has_error(function() parser.parse("node -1em") end, "Unexpected 'm'")
    assert.has_error(function() parser.parse("node .0") end, "Identifier cannot look like an illegal float")
  end)

  it("parses integers", function()
    assert.same(document.new{ node.new("node", { value.new(0) }) }, parse("node 0"))
    assert.same(document.new{ node.new("node", { value.new(123456789) }) }, parse("node 0123456789"))
    assert.same(document.new{ node.new("node", { value.new(123456789) }) }, parse("node 0123_456_789"))
    assert.same(document.new{ node.new("node", { value.new(123456789) }) }, parse("node 0123_456_789_"))
    assert.same(document.new{ node.new("node", { value.new(123456789) }) }, parse("node +0123456789"))
    assert.same(document.new{ node.new("node", { value.new(-123456789) }) }, parse("node -0123456789"))
  end)

  it("parses octal", function()
    assert.same(document.new{ node.new("node", { value.new(342391) }) }, parse("node 0o01234567"))
    assert.same(document.new{ node.new("node", { value.new(342391) }) }, parse("node 0o0123_4567"))
    assert.same(document.new{ node.new("node", { value.new(342391) }) }, parse("node 0o01234567_"))
    assert.has_error(function() parser.parse("node 0o_123") end, "Invalid octal: _123")
    assert.has_error(function() parser.parse("node 0o8") end, "Unexpected '8'")
    assert.has_error(function() parser.parse("node 0oo") end, "Unexpected 'o'")
  end)

  it("parses binary", function()
    assert.same(document.new{ node.new("node", { value.new(5) }) }, parse("node 0b0101"))
    assert.same(document.new{ node.new("node", { value.new(6) }) }, parse("node 0b01_10"))
    assert.same(document.new{ node.new("node", { value.new(6) }) }, parse("node 0b01___10"))
    assert.same(document.new{ node.new("node", { value.new(6) }) }, parse("node 0b0110_"))
    assert.has_error(function() parser.parse("node 0b_0110") end, "Invalid binary: _0110")
    assert.has_error(function() parser.parse("node 0b20") end, "Unexpected '2'")
    assert.has_error(function() parser.parse("node 0bb") end, "Unexpected 'b'")
  end)

  it("parses raw strings", function()
    assert.same(document.new{ node.new("node", { value.new("foo") }) }, parse([[node #"foo"#]]))
    assert.same(document.new{ node.new("node", { value.new([[foo\nbar]]) }) }, parse([[node #"foo\nbar"#]]))
    assert.same(document.new{ node.new("node", { value.new("foo") }) }, parse([[node #"foo"#]]))
    assert.same(document.new{ node.new("node", { value.new("foo") }) }, parse([[node ##"foo"##]]))
    assert.same(document.new{ node.new("node", { value.new([[\nfoo\r]]) }) }, parse([[node #"\nfoo\r"#]]))
    assert.has_error(function() parser.parse('node ##"foo"#') end, "Unterminated rawstring literal")
  end)

  it("parses booleans", function()
    assert.same(document.new{ node.new("node", { value.new(true) }) }, parse("node #true"))
    assert.same(document.new{ node.new("node", { value.new(false) }) }, parse("node #false"))
  end)

  it("parses nulls", function()
    assert.same(document.new{ node.new("node", { value.new(nil) }) }, parse("node #null"))
  end)
end)