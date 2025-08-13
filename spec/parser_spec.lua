require "spec.support"

describe("parser", function()
  local parser = require "kdl.parser"
  local document = require "kdl.document"
  local node = require "kdl.node"
  local value = require "kdl.value"

  local function n(name, args, children, ty, fn)
    if type(args) == "function" then
      fn = args
      args = nil
      children = nil
      ty = nil
    end
    if type(children) == "function" then
      fn = children
      children = nil
      ty = nil
    end
    if type(ty) == "function" then
      fn = ty
      ty = nil
    end
    local nd = node.new(name, args, children, ty)
    if fn then fn(nd) end
    return nd
  end

  it("parses empty string", function()
    assert.valid_kdl("", document.new(), 2)
    assert.valid_kdl(" ", document.new(), 2)
    assert.valid_kdl("\n", document.new(), 2)
  end)

  it("parses nodes", function()
    assert.valid_kdl("node", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node\n", document.new{ node.new("node") }, 2)
    assert.valid_kdl("\nnode\n", document.new{ node.new("node") }, 2)
    assert.valid_kdl(
      "node1\nnode2",
      document.new{
        node.new("node1"),
        node.new("node2")
      },
      2
    )
  end)

  it("parses node entries", function()
    assert.valid_kdl("node;", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node 1", document.new{ node.new("node", { value.new(1) }) }, 2)
    assert.valid_kdl(
      'node 1 2 "3" #true #false #null',
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
      2
    )
    assert.valid_kdl("node {\n  node2\n}", document.new{ node.new("node", {}, { node.new("node2") }) }, 2)
    assert.valid_kdl("node {\n    node2    \n}", document.new{ node.new("node", {}, { node.new("node2") }) }, 2)
    assert.valid_kdl("node { node2; }", document.new{ node.new("node", {}, { node.new("node2") }) }, 2)
    assert.valid_kdl("node { node2 }", document.new{ node.new("node", {}, { node.new("node2") }) }, 2)
    assert.valid_kdl("node { node2; node3 }", document.new{ node.new("node", {}, { node.new("node2"), node.new("node3") }) }, 2)
  end)

  it("parses slashdash nodes", function()
    assert.valid_kdl("/-node", document.new(), 2)
    assert.valid_kdl("/- node", document.new(), 2)
    assert.valid_kdl("/- node\n", document.new(), 2)
    assert.valid_kdl("/-node 1 2 3", document.new(), 2)
    assert.valid_kdl("/-node key=#false", document.new(), 2)
    assert.valid_kdl("/-node{\nnode\n}", document.new(), 2)
    assert.valid_kdl("/-node 1 2 3 key=\"value\" \\\n{\nnode\n}", document.new(), 2)
  end);

  it("parses slashdash args", function()
    assert.valid_kdl("node /-1", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node /-1 2", document.new{ node.new("node", { value.new(2) }) }, 2)
    assert.valid_kdl("node 1 /- 2 3", document.new{ node.new("node", { value.new(1), value.new(3) }) }, 2)
    assert.valid_kdl("node /--1", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node /- -1", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node \\\n/- -1", document.new{ node.new("node") }, 2)
  end)

  it("parses slashdash props", function()
    assert.valid_kdl("node /-key=1", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node /- key=1", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node key=1 /-key2=2", document.new{ node.new("node", { ["key"]=value.new(1) }) }, 2)
  end)

  it("parses slashdash children", function()
    assert.valid_kdl("node /-{}", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node /- {}", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node /-{\nnode2\n}", document.new{ node.new("node") }, 2)
  end)

  it('parses strings', function()
    assert.valid_kdl('node ""', document.new{ node.new('node', { value.new("") }) }, 2)
    assert.valid_kdl('node "hello"', document.new{ node.new('node', { value.new("hello") }) }, 2)
    assert.valid_kdl([[node "hello\nworld"]], document.new{ node.new('node', { value.new("hello\nworld") }) }, 2)
    assert.valid_kdl([[node -flag]], document.new{ node.new('node', { value.new("-flag") }) }, 2)
    assert.valid_kdl([[node --flagg]], document.new{ node.new('node', { value.new("--flagg") }) }, 2)
    assert.valid_kdl([[node "\u{10FFF}"]], document.new{ node.new('node', { value.new("\u{10FFF}") }) }, 2)
    assert.valid_kdl([[node "\"\\\b\f\n\r\t"]], document.new{ node.new('node', { value.new("\"\\\u{08}\u{0C}\n\r\t") }) }, 2)
    assert.valid_kdl([[node "\u{10}"]], document.new{ node.new('node', { value.new("\u{10}") }) }, 2)
    assert.is_not.valid_kdl([[node "\i"]], "Unexpected escape: \\i (1:6)", 2)
    assert.is_not.valid_kdl([[node "\u{c0ffee}"]], "Invalid code point \\u{c0ffee} (1:6)", 2)
    assert.is_not.valid_kdl([[node "oops]], "Unterminated string literal (1:6)", 2)
  end)

  it("parses unindented multiline strings", function()
    assert.valid_kdl('node """\n  foo\n  bar\n    baz\n  qux\n  """', document.new{ node.new("node", { value.new("foo\nbar\n  baz\nqux") }) }, 2)
    assert.valid_kdl('node #"""\n  foo\n  bar\n    baz\n  qux\n  """#', document.new{ node.new("node", { value.new("foo\nbar\n  baz\nqux") }) }, 2)
    assert.is_not.valid_kdl('node """\n    foo\n  bar\n    baz\n    """', "Invalid multi-line string indentation (1:6)", 2)
    assert.is_not.valid_kdl('node #"""\n    foo\n  bar\n    baz\n    """#', "Invalid multi-line string indentation (1:6)", 2)
  end)

  it("parses floats", function()
    assert.valid_kdl("node 1.0", document.new{ node.new("node", { value.new(1.0) }) }, 2)
    assert.valid_kdl("node 0.0", document.new{ node.new("node", { value.new(0.0) }) }, 2)
    assert.valid_kdl("node -1.0", document.new{ node.new("node", { value.new(-1.0) }) }, 2)
    assert.valid_kdl("node +1.0", document.new{ node.new("node", { value.new(1.0) }) }, 2)
    assert.valid_kdl("node 1.0e10", document.new{ node.new("node", { value.new(1.0e10) }) }, 2)
    assert.valid_kdl("node 1.0e-10", document.new{ node.new("node", { value.new(1.0e-10) }) }, 2)
    assert.valid_kdl("node 123_456_789.0", document.new{ node.new("node", { value.new(123456789.0) }) }, 2)
    assert.valid_kdl("node 123_456_789.0_", document.new{ node.new("node", { value.new(123456789.0) }) }, 2)
    assert.is_not.valid_kdl("node 1._0", "Invalid number: 1._0 (1:6)", 2)
    assert.is_not.valid_kdl("node 1.", "Invalid number: 1. (1:6)", 2)
    assert.is_not.valid_kdl("node 1.0v2", "Unexpected 'v' (1:6)", 2)
    assert.is_not.valid_kdl("node -1em", "Unexpected 'm' (1:6)", 2)
    assert.is_not.valid_kdl("node .0", "Identifier cannot look like an illegal float (1:6)", 2)
  end)

  it("parses integers", function()
    assert.valid_kdl("node 0", document.new{ node.new("node", { value.new(0) }) }, 2)
    assert.valid_kdl("node 0123456789", document.new{ node.new("node", { value.new(123456789) }) }, 2)
    assert.valid_kdl("node 0123_456_789", document.new{ node.new("node", { value.new(123456789) }) }, 2)
    assert.valid_kdl("node 0123_456_789_", document.new{ node.new("node", { value.new(123456789) }) }, 2)
    assert.valid_kdl("node +0123456789", document.new{ node.new("node", { value.new(123456789) }) }, 2)
    assert.valid_kdl("node -0123456789", document.new{ node.new("node", { value.new(-123456789) }) }, 2)
  end)

  it("parses hexadecimal", function()
    assert.valid_kdl("node 0x0123456789abcdef", document.new{ node.new("node", { value.new(0x0123456789abcdef) }) }, 2)
    assert.valid_kdl("node 0x01234567_89abcdef", document.new{ node.new("node", { value.new(0x0123456789abcdef) }) }, 2)
    assert.valid_kdl("node 0x01234567_89abcdef_", document.new{ node.new("node", { value.new(0x0123456789abcdef) }) }, 2)
    assert.is_not.valid_kdl("node 0x_123", "Invalid hexadecimal: _123 (1:6)", 2)
    assert.is_not.valid_kdl("node 0xG", "Unexpected 'G' (1:6)", 2)
    assert.is_not.valid_kdl("node 0xx", "Unexpected 'x' (1:6)", 2)
  end)


  it("parses octal", function()
    assert.valid_kdl("node 0o01234567", document.new{ node.new("node", { value.new(342391) }) }, 2)
    assert.valid_kdl("node 0o0123_4567", document.new{ node.new("node", { value.new(342391) }) }, 2)
    assert.valid_kdl("node 0o01234567_", document.new{ node.new("node", { value.new(342391) }) }, 2)
    assert.is_not.valid_kdl("node 0o_123", "Invalid octal: _123 (1:6)", 2)
    assert.is_not.valid_kdl("node 0o8", "Unexpected '8' (1:6)", 2)
    assert.is_not.valid_kdl("node 0oo", "Unexpected 'o' (1:6)", 2)
  end)

  it("parses binary", function()
    assert.valid_kdl("node 0b0101", document.new{ node.new("node", { value.new(5) }) }, 2)
    assert.valid_kdl("node 0b01_10", document.new{ node.new("node", { value.new(6) }) }, 2)
    assert.valid_kdl("node 0b01___10", document.new{ node.new("node", { value.new(6) }) }, 2)
    assert.valid_kdl("node 0b0110_", document.new{ node.new("node", { value.new(6) }) }, 2)
    assert.is_not.valid_kdl("node 0b_0110", "Invalid binary: _0110 (1:6)", 2)
    assert.is_not.valid_kdl("node 0b20", "Unexpected '2' (1:6)", 2)
    assert.is_not.valid_kdl("node 0bb", "Unexpected 'b' (1:6)", 2)
  end)

  it("parses raw strings", function()
    assert.valid_kdl([[node #"foo"#]], document.new{ node.new("node", { value.new("foo") }) }, 2)
    assert.valid_kdl([[node #"foo\nbar"#]], document.new{ node.new("node", { value.new([[foo\nbar]]) }) }, 2)
    assert.valid_kdl([[node #"foo"#]], document.new{ node.new("node", { value.new("foo") }) }, 2)
    assert.valid_kdl([[node ##"foo"##]], document.new{ node.new("node", { value.new("foo") }) }, 2)
    assert.valid_kdl([[node #"\nfoo\r"#]], document.new{ node.new("node", { value.new([[\nfoo\r]]) }) }, 2)
    assert.is_not.valid_kdl('node ##"foo"#', "Unterminated rawstring literal (1:6)", 2)
  end)

  it("parses booleans", function()
    assert.valid_kdl("node #true", document.new{ node.new("node", { value.new(true) }) }, 2)
    assert.valid_kdl("node #false", document.new{ node.new("node", { value.new(false) }) }, 2)
  end)

  it("parses nulls", function()
    assert.valid_kdl("node #null", document.new{ node.new("node", { value.new(nil) }) }, 2)
  end)

  it("parses node spacing", function()
    assert.valid_kdl("node 1", document.new{ node.new("node", { value.new(1) }) }, 2)
    assert.valid_kdl("node\t1", document.new{ node.new("node", { value.new(1) }) }, 2)
    assert.valid_kdl("node\t \\ // hello\n 1", document.new{ node.new("node", { value.new(1) }) }, 2)
  end)

  it("parses single line comment", function()
    assert.valid_kdl("//hello", document.new{}, 2)
    assert.valid_kdl("// \thello", document.new{}, 2)
    assert.valid_kdl("//hello\n", document.new{}, 2)
    assert.valid_kdl("//hello\r\n", document.new{}, 2)
    assert.valid_kdl("//hello\n\r", document.new{}, 2)
    assert.valid_kdl("//hello\rworld", document.new{ node.new("world") }, 2)
    assert.valid_kdl("//hello\nworld\r\n", document.new{ node.new("world") }, 2)
  end)

  it("parses multi line comment", function()
    assert.valid_kdl("/*hello*/", document.new{});
    assert.valid_kdl("/*hello*/\n", document.new{});
    assert.valid_kdl("/*\nhello\r\n*/", document.new{});
    assert.valid_kdl("/*\nhello** /\n*/", document.new{});
    assert.valid_kdl("/**\nhello** /\n*/", document.new{});
    assert.valid_kdl("/*hello*/world", document.new{ node.new("world") });
  end)

  it("parses esclines", function()
    assert.valid_kdl("node\\\n  1", document.new{ node.new("node", { value.new(1) }) }, 2)
    assert.valid_kdl("node\\\n", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node\\ \n", document.new{ node.new("node") }, 2)
    assert.valid_kdl("node\\\n ", document.new{ node.new("node") }, 2)
    assert.is_not.valid_kdl('node \\foo', [[Unexpected '\' (1:5)]], 2)
    assert.is_not.valid_kdl('node\\\\\nnode2', [[Unexpected '\' (1:5)]], 2)
    assert.is_not.valid_kdl('node \\\\\nnode2', [[Unexpected '\' (1:5)]], 2)
  end)

  it("parses whitespace", function()
    assert.valid_kdl(" node", document.new{ node.new("node") }, 2)
    assert.valid_kdl("\tnode", document.new{ node.new("node") }, 2)
    assert.valid_kdl("/* \nfoo\r\n */ etc", document.new{ node.new("etc") }, 2)
  end)

  it('parses newlines', function()
    assert.valid_kdl("node1\nnode2", document.new{ node.new('node1'), node.new('node2') }, 2)
    assert.valid_kdl("node1\rnode2", document.new{ node.new('node1'), node.new('node2') }, 2)
    assert.valid_kdl("node1\r\nnode2", document.new{ node.new('node1'), node.new('node2') }, 2)
    assert.valid_kdl("node1\n\nnode2", document.new{ node.new('node1'), node.new('node2') }, 2)
  end)

  it("parses basic", function()
    assert.valid_kdl(
      'title "Hello, World"',
      document.new{
        node.new("title", { value.new("Hello, World") })
      },
      2
    )
  end)

  it("parses multiple values", function()
    assert.valid_kdl(
      "bookmarks 12 15 188 1234",
      document.new{
        node.new("bookmarks", { value.new(12), value.new(15), value.new(188), value.new(1234) })
      },
      2
    )
  end)

  it("parses properties", function()
    assert.valid_kdl(
      [[
        author "Alex Monad" email="alex@example.com" active= #true
        foo bar =#true "baz" quux =\
          #false 1 2 3
      ]],
      document.new{
        n("author", { value.new("Alex Monad") }, function(nd)
          nd:insert("email", value.new("alex@example.com"))
          nd:insert("active", value.new(true))
        end),
        n("foo", { value.new("baz"), value.new(1), value.new(2), value.new(3) }, function(nd)
          nd:insert("bar", value.new(true))
          nd:insert("quux", value.new(false))
        end)
      },
      2
    )
  end)

  it("parses nested child nodes", function()
    assert.valid_kdl(
      [[
        contents {
          section "First section" {
            paragraph "This is the first paragraph"
            paragraph "This is the second paragraph"
          }
        }
      ]],
      document.new{
        node.new("contents", {}, {
          node.new("section", { value.new("First section") }, {
            node.new("paragraph", { value.new("This is the first paragraph") }),
            node.new("paragraph", { value.new("This is the second paragraph") })
          })
        })
      },
      2
    )
  end)

  it("parses semicolons", function()
    assert.valid_kdl(
      "node1; node2; node3;",
      document.new{
        node.new("node1"),
        node.new("node2"),
        node.new("node3"),
      },
      2
    )
  end)

  it('parses optional child semicolon', function()
    assert.valid_kdl(
      'node {foo;bar;baz}',
      document.new{
        node.new('node', {}, {
          node.new('foo'),
          node.new('bar'),
          node.new('baz')
        })
      },
      2
    )
  end)

  it("parses raw strings", function()
    assert.valid_kdl(
      [[
        node "this\nhas\tescapes"
        other #"C:\Users\zkat\"#
        other-raw #"hello"world"#
      ]],
      document.new{
        node.new("node", { value.new("this\nhas\tescapes") }),
        node.new("other", { value.new("C:\\Users\\zkat\\") }),
        node.new("other-raw", { value.new("hello\"world") })
      },
      2
    )
  end)

  it("parses multiline strings", function()
    assert.valid_kdl(
      [[
string """
my
multiline
value
"""
      ]],
      document.new{
        node.new("string", { value.new("my\nmultiline\nvalue") })
      },
      2
    )

    assert.is_not.valid_kdl('node """foo"""', "Expected NEWLINE, found 'f' (1:6)", 2)
    assert.is_not.valid_kdl('node #"""foo"""#', "Expected NEWLINE, found 'f' (1:6)", 2)
    assert.is_not.valid_kdl('node """\n  oops', "Unterminated multi-line string literal (1:6)", 2)
    assert.is_not.valid_kdl('node #"""\n  oops', "Unterminated multi-line rawstring literal (1:6)", 2)
  end)

  it("parses numbers", function()
    assert.valid_kdl(
      [[
        num 1.234e-42
        my-hex 0xdeadbeef
        my-octal 0o755
        my-binary 0b10101101
        bignum 1_000_000
      ]],
      document.new{
        node.new("num", { value.new(1.234e-42) }),
        node.new("my-hex", { value.new(0xdeadbeef) }),
        node.new("my-octal", { value.new(493) }),
        node.new("my-binary", { value.new(173) }),
        node.new("bignum", { value.new(1000000) })
      },
      2
    )
  end)

  it("parses comments", function()
    assert.valid_kdl(
      [[
        // C style

        /*
        C style multiline
        */

        tag /*foo=#true*/ bar=#false

        /*/*
        hello
        */*/
      ]],
      document.new{
        node.new("tag", { ["bar"]=value.new(false) })
      },
      2
    )
  end)

  it("parses slash dash", function()
    assert.valid_kdl(
      [[
        /-mynode "foo" key=1 {
          a
          b
          c
        }

        mynode /- "commented" "not commented" /-key="value" /-{
          a
          b
        }
      ]],
      document.new{
        node.new("mynode", { value.new("not commented") })
      },
      2
    )
  end)

  it("parses multiline nodes", function()
    assert.valid_kdl(
      [[
        title \
          "Some title"

        my-node 1 2 \  // comments are ok after \
          3 4
      ]],
      document.new{
        node.new("title", { value.new("Some title") }),
        node.new("my-node", { value.new(1), value.new(2), value.new(3), value.new(4) })
      },
      2
    )
  end)

  it("parses utf8", function()
    assert.valid_kdl(
      [[
        smile "😁"
        ノード お名前="☜(ﾟヮﾟ☜)"
      ]],
      document.new{
        node.new("smile", { value.new("😁") }),
        node.new("ノード", { ["お名前"]=value.new("☜(ﾟヮﾟ☜)") })
      },
      2
    )
  end)

  it("parses node names", function()
    assert.valid_kdl(
      [[
"!@$@$%Q$%~@!40" "1.2.3" "!!!!!"=#true
foo123~!@$%^&*.:'|?+ "weeee"
- 1
      ]],
      document.new{
        node.new("!@$@$%Q$%~@!40", { value.new("1.2.3"), ["!!!!!"]=value.new(true) }),
        node.new("foo123~!@$%^&*.:'|?+", { value.new("weeee") }),
        node.new("-", { value.new(1) })
      },
      2
    )
  end)

  it("parses escapes", function()
    assert.valid_kdl(
      [[
node1 "\u{1f600}"
node2 "\n\t\r\\\"\f\b"
      ]],
      document.new{
        node.new("node1", { value.new("😀") }),
        node.new("node2", { value.new("\n\t\r\\\"\f\b") })
      },
      2
    )

    assert.is_not.valid_kdl('node "\\u"', "Invalid unicode escape (1:6)", 2)
    assert.is_not.valid_kdl('node "\\u{}"', "Invalid unicode escape:  (1:6)", 2)
    assert.is_not.valid_kdl('node "\\u{"', "Invalid unicode escape: \\u{} (1:6)", 2)
    assert.is_not.valid_kdl('node "\\u}"', "Invalid unicode escape (1:6)", 2)
    assert.is_not.valid_kdl('node "\\u{0123456}"', "Invalid unicode escape: \\u{0123456} (1:6)", 2)
  end)

  it("parses node types", function()
    assert.valid_kdl(
      "(foo)node",
      document.new{
        node.new("node", {}, {}, "foo")
      },
      2
    )
  end)

  it("parses value types", function()
    assert.valid_kdl(
      'node (foo)"bar"',
      document.new{
        node.new("node", { value.new("bar", "foo") }),
      },
      2
    )
  end)

  it("parses property types", function()
    assert.valid_kdl(
      'node baz=(foo)"bar"',
      document.new{
        node.new("node", { ["baz"]=value.new("bar", "foo") }),
      },
      2
    )
  end)

  it("parses child types", function()
    assert.valid_kdl(
      [[
        node {
          (foo)bar
        }
      ]],
      document.new{
        node.new("node", {}, {
          node.new("bar", {}, {}, "foo"),
        })
      },
      2
    )
  end)

  it("reads version directive", function()
    assert.valid_kdl('/- kdl-version 2\nnode foo', 2)
    assert.is_not.valid_kdl('/- kdl-version 1\nnode "foo"', "Version mismatch, expected 2, got 1", 2)
  end)
end)
