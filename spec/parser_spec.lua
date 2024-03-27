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

  it("parses node spacing", function()
    assert.same(document.new{ node.new("node", { value.new(1) }) }, parse("node 1"))
    assert.same(document.new{ node.new("node", { value.new(1) }) }, parse("node\t1"))
    assert.same(document.new{ node.new("node", { value.new(1) }) }, parse("node\t \\ // hello\n 1"))
  end)

  it("parses single line comment", function()
    assert.same(document.new{}, parse("//hello"))
    assert.same(document.new{}, parse("// \thello"))
    assert.same(document.new{}, parse("//hello\n"))
    assert.same(document.new{}, parse("//hello\r\n"))
    assert.same(document.new{}, parse("//hello\n\r"))
    assert.same(document.new{ node.new("world") }, parse("//hello\rworld"))
    assert.same(document.new{ node.new("world") }, parse("//hello\nworld\r\n"))
  end)

  it("parses multi line comment", function()
    assert.same(document.new{}, parse("/*hello*/"));
    assert.same(document.new{}, parse("/*hello*/\n"));
    assert.same(document.new{}, parse("/*\nhello\r\n*/"));
    assert.same(document.new{}, parse("/*\nhello** /\n*/"));
    assert.same(document.new{}, parse("/**\nhello** /\n*/"));
    assert.same(document.new{ node.new("world") }, parse("/*hello*/world"));
  end)

  it("parses esclines", function()
    assert.same(document.new{ node.new("node", { value.new(1) }) }, parse("node\\\n  1"))
    assert.same(document.new{ node.new("node") }, parse("node\\\n"))
    assert.same(document.new{ node.new("node") }, parse("node\\ \n"))
    assert.same(document.new{ node.new("node") }, parse("node\\\n "))
  end)

  it("parses whitespace", function()
    assert.same(document.new{ node.new("node") }, parse(" node"))
    assert.same(document.new{ node.new("node") }, parse("\tnode"))
    assert.same(document.new{ node.new("etc") }, parse("/* \nfoo\r\n */ etc"))
  end)

  it('parses newlines', function()
    assert.same(document.new{ node.new('node1'), node.new('node2') }, parse("node1\nnode2"))
    assert.same(document.new{ node.new('node1'), node.new('node2') }, parse("node1\rnode2"))
    assert.same(document.new{ node.new('node1'), node.new('node2') }, parse("node1\r\nnode2"))
    assert.same(document.new{ node.new('node1'), node.new('node2') }, parse("node1\n\nnode2"))
  end)

  it("pasrses basic", function()
    local doc = parse('title "Hello, World"')
    local nodes = document.new{
      node.new("title", { value.new("Hello, World") })
    }
    assert.same(nodes, doc)
  end)

  it("parses multiple values", function()
    local doc = parse("bookmarks 12 15 188 1234")
    local nodes = document.new{
      node.new("bookmarks", { value.new(12), value.new(15), value.new(188), value.new(1234) })
    }
    assert.same(nodes, doc)
  end)

  it("parses properties", function()
    local doc = parse([[author "Alex Monad" email="alex@example.com" active= #true
foo bar =#true "baz" quux =\
  #false 1 2 3]])
    local nodes = document.new{
      node.new("author", { 
          value.new("Alex Monad"),
          ["email"]=value.new("alex@example.com"),
          ["active"]=value.new(true)
      }),
      node.new("foo", {
        value.new("baz"), value.new(1), value.new(2), value.new(3),
        ["bar"]=value.new(true),
        ["quux"]=value.new(false),
      })
    }
    assert.same(nodes, doc)
  end)

  it("parses nested child nodes", function()
    local doc = parse[[
      contents {
        section "First section" {
          paragraph "This is the first paragraph"
          paragraph "This is the second paragraph"
        }
      }
    ]]
    local nodes = document.new{
      node.new("contents", {}, {
        node.new("section", { value.new("First section") }, {
          node.new("paragraph", { value.new("This is the first paragraph") }),
          node.new("paragraph", { value.new("This is the second paragraph") })
        })
      })
    }
    assert.same(nodes, doc)
  end)

  it("parses semicolons", function()
    local doc = parse("node1; node2; node3;")
    local nodes = document.new{
      node.new("node1"),
      node.new("node2"),
      node.new("node3"),
    }
    assert.same(nodes, doc)
  end)

  it('parses optional child semicolon', function()
    local doc = parse('node {foo;bar;baz}')
    local nodes = document.new{
      node.new('node', {}, {
        node.new('foo'),
        node.new('bar'),
        node.new('baz')
      })
    }
    assert.same(nodes, doc)
  end)

  it("parses raw strings", function()
    local doc = parse[[
      node "this\nhas\tescapes"
      other #"C:\Users\zkat\"#
      other-raw #"hello"world"#
    ]]
    local nodes = document.new{
      node.new("node", { value.new("this\nhas\tescapes") }),
      node.new("other", { value.new("C:\\Users\\zkat\\") }),
      node.new("other-raw", { value.new("hello\"world") })
    }
    assert.same(nodes, doc)
  end)

  it("parses multiline strings", function()
    local doc = parse[[
string "my
multiline
value"
]]
    local nodes = document.new{
      node.new("string", { value.new("my\nmultiline\nvalue") })
    }
    assert.same(nodes, doc)
  end)

  it("parses numbers", function()
    local doc = parse[[
      num 1.234e-42
      my-hex 0xdeadbeef
      my-octal 0o755
      my-binary 0b10101101
      bignum 1_000_000
    ]]
    local nodes = document.new{
      node.new("num", { value.new(1.234e-42) }),
      node.new("my-hex", { value.new(0xdeadbeef) }),
      node.new("my-octal", { value.new(493) }),
      node.new("my-binary", { value.new(173) }),
      node.new("bignum", { value.new(1000000) })
    }
    assert.same(nodes, doc)
  end)

  it("parses comments comments", function()
    local doc = parse[[
      // C style

      /*
      C style multiline
      */

      tag /*foo=#true*/ bar=#false

      /*/*
      hello
      */*/
    ]]
    local nodes = document.new{
      node.new("tag", { ["bar"]=value.new(false) })
    }
    assert.same(nodes, doc)
  end)

  it("parses slash dash", function()
    local doc = parse[[
      /-mynode "foo" key=1 {
        a
        b
        c
      }

      mynode /- "commented" "not commented" /-key="value" /-{
        a
        b
      }
    ]]
    local nodes = document.new{
      node.new("mynode", { value.new("not commented") })
    }
    assert.same(nodes, doc)
  end)

  it("parses multiline nodes", function()
    local doc = parse[[
      title \
        "Some title"

      my-node 1 2 \  // comments are ok after \
        3 4
    ]]
    local nodes = document.new{
      node.new("title", { value.new("Some title") }),
      node.new("my-node", { value.new(1), value.new(2), value.new(3), value.new(4) })
    }
    assert.same(nodes, doc)
  end)

  it("parses utf8", function()
    local doc = parse[[
      smile "😁"
      ノード お名前＝"☜(ﾟヮﾟ☜)"
    ]]
    local nodes = document.new{
      node.new("smile", { value.new("😁") }),
      node.new("ノード", { ["お名前"]=value.new("☜(ﾟヮﾟ☜)") })
    }
    assert.same(nodes, doc)
  end)

  it("parses node names", function()
    local doc = parse[[
      "!@$@$%Q$%~@!40" "1.2.3" "!!!!!"=#true
      foo123~!@$%^&*.:'|?+ "weeee"
      - 1
    ]]
    local nodes = document.new{
      node.new("!@$@$%Q$%~@!40", { value.new("1.2.3"), ["!!!!!"]=value.new(true) }),
      node.new("foo123~!@$%^&*.:'|?+", { value.new("weeee") }),
      node.new("-", { value.new(1) })
    }
    assert.same(nodes, doc)
  end)

  it("parses escapes", function()
    local doc = parse[[
      node1 "\u{1f600}"
      node2 "\n\t\r\\\"\f\b"
    ]]
    local nodes = document.new{
      node.new("node1", { value.new("😀") }),
      node.new("node2", { value.new("\n\t\r\\\"\f\b") })
    }
    assert.same(nodes, doc)
  end)

  it("parses node types", function()
    local doc = parse("(foo)node")
    local nodes = document.new{
      node.new("node", {}, {}, "foo")
    }
    assert.same(nodes, doc)
  end)

  it("parses value types", function()
    local doc = parse('node (foo)"bar"')
    local nodes = document.new{
      node.new("node", { value.new("bar", "foo") }),
    }
    assert.same(nodes, doc)
  end)

  it("parses property types", function()
    local doc = parse('node baz=(foo)"bar"')
    local nodes = document.new{
      node.new("node", { ["baz"]=value.new("bar", "foo") }),
    }
    assert.same(nodes, doc)
  end)

  it("parses child types", function()
    local doc = parse[[
      node {
        (foo)bar
      }
    ]]
    local nodes = document.new{
      node.new("node", {}, {
        node.new("bar", {}, {}, "foo"),
      })
    }
    assert.same(nodes, doc)
  end)
end)