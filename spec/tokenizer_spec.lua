describe("tokenizer", function()
  local tokenizer = require "kdl.tokenizer"

  it("can peek at upcoming tokens", function()
    local t = tokenizer.new("node 1 2 3")
    assert.same({ type="IDENT", value="node" }, t:peek())
    assert.same({ type="WS", value=" " }, t:peek_next())
    assert.same({ type="IDENT", value="node" }, t:next())
    assert.same({ type="WS", value=" " }, t:peek())
    assert.same({ type="INTEGER", value=1 }, t:peek_next())
  end)

  it("tokenizes identifiers", function()
    assert.same({ type="IDENT", value="foo" }, tokenizer.new("foo"):next())
  end)

  it("tokenizes strings", function()
    assert.same({ type="STRING", value="foo" }, tokenizer.new('"foo"'):next())
    assert.same({ type="STRING", value="foo\nbar" }, tokenizer.new('"foo\\nbar"'):next())
    assert.same({ type="STRING", value="\u{10FFF}" }, tokenizer.new('"\\u{10FFF}"'):next())
  end)

  it("tokenizes multi line strings", function()
    assert.same({ type="STRING", value="foo\nbar\n  baz\nqux" }, tokenizer.new("\"\n  foo\n  bar\n    baz\n  qux\n  \""):next())
    assert.same({ type="RAWSTRING", value="foo\nbar\n  baz\nqux" }, tokenizer.new("#\"\n  foo\n  bar\n    baz\n  qux\n  \"#"):next())
  end)

  it("tokenizes rawstrings", function()
    assert.same({ type="RAWSTRING", value="foo\\nbar" }, tokenizer.new('#"foo\\nbar"#'):next())
    assert.same({ type="RAWSTRING", value="foo\"bar" }, tokenizer.new('#"foo"bar"#'):next())
    assert.same({ type="RAWSTRING", value="foo\"#bar" }, tokenizer.new('##"foo"#bar"##'):next())
    assert.same({ type="RAWSTRING", value="\"foo\"" }, tokenizer.new('#""foo""#'):next())

    local t = tokenizer.new('node #"C:\\Users\\zkat\\"#')
    assert.same({ type="IDENT", value="node" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="RAWSTRING", value="C:\\Users\\zkat\\" }, t:next())

    t = tokenizer.new('other-node #"hello"world"#')
    assert.same({ type="IDENT", value="other-node" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="RAWSTRING", value="hello\"world" }, t:next())
  end)

  it("tokenizes integers", function()
    assert.same({ type="INTEGER", value=0x0123456789abcdef }, tokenizer.new("0x0123456789abcdef"):next())
    assert.same({ type="INTEGER", value=342391 }, tokenizer.new("0o01234567"):next())
    assert.same({ type="INTEGER", value=41 }, tokenizer.new("0b101001"):next())
    assert.same({ type="INTEGER", value=-0x0123456789abcdef }, tokenizer.new("-0x0123456789abcdef"):next())
    assert.same({ type="INTEGER", value=-342391 }, tokenizer.new("-0o01234567"):next())
    assert.same({ type="INTEGER", value=-41 }, tokenizer.new("-0b101001"):next())
    assert.same({ type="INTEGER", value=0x0123456789abcdef }, tokenizer.new("+0x0123456789abcdef"):next())
    assert.same({ type="INTEGER", value=342391 }, tokenizer.new("+0o01234567"):next())
    assert.same({ type="INTEGER", value=41 }, tokenizer.new("+0b101001"):next())
  end)

  it("tokenizes floats", function()
    assert.same({ type="FLOAT", value=1.23 }, tokenizer.new("1.23"):next())
    assert.same({ type="FLOAT", value=math.huge }, tokenizer.new("#inf"):next())
    assert.same({ type="FLOAT", value=-math.huge }, tokenizer.new("#-inf"):next())
    local nan = tokenizer.new("#nan"):next()
    assert.same(nan.type, "FLOAT")
    assert.is_not.equal(nan.value, nan.value);
  end)

  it("tokenizers booleans", function()
    assert.same({ type="TRUE", value=true }, tokenizer.new("#true"):next())
    assert.same({ type="FALSE", value=false }, tokenizer.new("#false"):next())
  end)

  it("tokenizers nulls", function()
    assert.same({ type="NULL", value=nil }, tokenizer.new("#null"):next())
  end)

  it("tokenizers symbols", function()
    assert.same({ type="LBRACE", value="{" }, tokenizer.new("{"):next())
    assert.same({ type="RBRACE", value="}" }, tokenizer.new("}"):next())
  end)

  it("tokenizes equals", function()
    assert.same({ type="EQUALS", value="=" }, tokenizer.new("="):next())
    assert.same({ type="EQUALS", value=" =" }, tokenizer.new(" ="):next())
    assert.same({ type="EQUALS", value="= " }, tokenizer.new("= "):next())
    assert.same({ type="EQUALS", value=" = " }, tokenizer.new(" = "):next())
    assert.same({ type="EQUALS", value=" =" }, tokenizer.new(" =foo"):next())
    assert.same({ type="EQUALS", value="\u{FE66}" }, tokenizer.new("\u{FE66}"):next())
    assert.same({ type="EQUALS", value="\u{FF1D}" }, tokenizer.new("\u{FF1D}"):next())
    assert.same({ type="EQUALS", value="🟰" }, tokenizer.new("🟰"):next())
  end)

  it("tokenizes whitespace", function()
    assert.same({ type="WS", value=" " }, tokenizer.new(" "):next())
    assert.same({ type="WS", value="\t" }, tokenizer.new("\t"):next())
    assert.same({ type="WS", value="    \t" }, tokenizer.new("    \t"):next())
    assert.same({ type="WS", value="\\\n" }, tokenizer.new("\\\n"):next())
    assert.same({ type="WS", value="\\" }, tokenizer.new("\\"):next())
    assert.same({ type="WS", value="\\\n" }, tokenizer.new("\\//some comment\n"):next())
    assert.same({ type="WS", value="\\ \n" }, tokenizer.new("\\ //some comment\n"):next())
    assert.same({ type="WS", value="\\" }, tokenizer.new("\\//some comment"):next())
    assert.same({ type="WS", value=" \\\n" }, tokenizer.new(" \\\n"):next())
    assert.same({ type="WS", value=" \\\n" }, tokenizer.new(" \\//some comment\n"):next())
    assert.same({ type="WS", value=" \\ \n" }, tokenizer.new(" \\ //some comment\n"):next())
    assert.same({ type="WS", value=" \\" }, tokenizer.new(" \\//some comment"):next())
    assert.same({ type="WS", value=" \\\n  \\\n  " }, tokenizer.new(" \\\n  \\\n  "):next())
  end)

  it("tokenizes multiple tokens", function()
    local t = tokenizer.new("node 1 \"two\" a=3")

    assert.same({ type="IDENT", value="node" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="INTEGER", value=1 }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="STRING", value="two" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="IDENT", value="a" }, t:next())
    assert.same({ type="EQUALS", value="=" }, t:next())
    assert.same({ type="INTEGER", value=3 }, t:next())
    assert.same({ type="EOF", value="" }, t:next())
    assert.same({ type=false, value=false }, t:next())
  end)

  it("tokenizes single line comments", function()
    assert.same({ type="EOF", value="" }, tokenizer.new("// comment"):next())

    local t = tokenizer.new([[node1
// comment
node2]])

    assert.same({ type="IDENT", value="node1" }, t:next())
    assert.same({ type="NEWLINE", value="\n" }, t:next())
    assert.same({ type="NEWLINE", value="\n" }, t:next())
    assert.same({ type="IDENT", value="node2" }, t:next())
    assert.same({ type="EOF", value="" }, t:next())
    assert.same({ type=false, value=false }, t:next())
  end)

  it("tokenizes multiline comments", function()
    local t = tokenizer.new("foo /*bar=1*/ baz=2")

    assert.same({ type="IDENT", value="foo" }, t:next())
    assert.same({ type="WS", value="  " }, t:next())
    assert.same({ type="IDENT", value="baz" }, t:next())
    assert.same({ type="EQUALS", value="=" }, t:next())
    assert.same({ type="INTEGER", value=2 }, t:next())
    assert.same({ type="EOF", value="" }, t:next())
    assert.same({ type=false, value=false }, t:next())
  end)

  it("tokenizes utf8", function()
    assert.same({ type="IDENT", value="😁" }, tokenizer.new("😁"):next())
    assert.same({ type="STRING", value="😁" }, tokenizer.new('"😁"'):next())
    assert.same({ type="IDENT", value="ノード" }, tokenizer.new("ノード"):next())
    assert.same({ type="IDENT", value="お名前" }, tokenizer.new("お名前"):next())
    assert.same({ type="STRING", value="☜(ﾟヮﾟ☜)" }, tokenizer.new('"☜(ﾟヮﾟ☜)"'):next())

    local t = tokenizer.new([[smile "😁"
ノード お名前＝"☜(ﾟヮﾟ☜)"]])

    assert.same({ type="IDENT", value="smile" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="STRING", value="😁" }, t:next())
    assert.same({ type="NEWLINE", value="\n" }, t:next())
    assert.same({ type="IDENT", value="ノード" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="IDENT", value="お名前" }, t:next())
    assert.same({ type="EQUALS", value="＝" }, t:next())
    assert.same({ type="STRING", value="☜(ﾟヮﾟ☜)" }, t:next())
    assert.same({ type="EOF", value="" }, t:next())
    assert.same({ type=false, value=false }, t:next())
  end)

  it("tokenizes semicolons", function()
    local t = tokenizer.new("node1; node2")

    assert.same({ type="IDENT", value="node1" }, t:next())
    assert.same({ type="SEMICOLON", value=";" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="IDENT", value="node2" }, t:next())
    assert.same({ type="EOF", value="" }, t:next())
    assert.same({ type=false, value=false }, t:next())
  end)

  it("tokenizes slash dash", function()
    local t = tokenizer.new([[/-mynode /-"foo" /-key=1 /-{
  a
}]])

    assert.same({ type="SLASHDASH", value="/-" }, t:next())
    assert.same({ type="IDENT", value="mynode" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="SLASHDASH", value="/-" }, t:next())
    assert.same({ type="STRING", value="foo" }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="SLASHDASH", value="/-" }, t:next())
    assert.same({ type="IDENT", value="key" }, t:next())
    assert.same({ type="EQUALS", value="=" }, t:next())
    assert.same({ type="INTEGER", value=1 }, t:next())
    assert.same({ type="WS", value=" " }, t:next())
    assert.same({ type="SLASHDASH", value="/-" }, t:next())
    assert.same({ type="LBRACE", value="{" }, t:next())
    assert.same({ type="NEWLINE", value="\n" }, t:next())
    assert.same({ type="WS", value="  " }, t:next())
    assert.same({ type="IDENT", value="a" }, t:next())
    assert.same({ type="NEWLINE", value="\n" }, t:next())
    assert.same({ type="RBRACE", value="}" }, t:next())
    assert.same({ type="EOF", value="" }, t:next())
    assert.same({ type=false, value=false }, t:next())
  end)

  it("tokenizes multiline nodes", function()
    local t = tokenizer.new([[title \
  "Some title"]])

    assert.same({ type="IDENT", value="title" }, t:next())
    assert.same({ type="WS", value=" \\\n  " }, t:next())
    assert.same({ type="STRING", value="Some title" }, t:next())
    assert.same({ type="EOF", value="" }, t:next())
    assert.same({ type=false, value=false }, t:next())
  end)

  it("tokenizes types", function()
    local t = tokenizer.new("(foo)bar")
    assert.same({ type="LPAREN", value="(" }, t:next())
    assert.same({ type="IDENT", value="foo" }, t:next())
    assert.same({ type="RPAREN", value=")" }, t:next())
    assert.same({ type="IDENT", value="bar" }, t:next())

    t = tokenizer.new("(foo)/*asdf*/bar")
    assert.same({ type="LPAREN", value="(" }, t:next())
    assert.same({ type="IDENT", value="foo" }, t:next())
    assert.same({ type="RPAREN", value=")" }, t:next())
    assert.same({ type="IDENT", value="bar" }, t:next())

    t = tokenizer.new("(foo/*asdf*/)bar")
    assert.same({ type="LPAREN", value="(" }, t:next())
    assert.same({ type="IDENT", value="foo" }, t:next())
    assert.same({ type="RPAREN", value=")" }, t:next())
    assert.same({ type="IDENT", value="bar" }, t:next())
  end)
end)