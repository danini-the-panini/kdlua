describe("tokenizer", function()
  local tokenizer = require "kdl.tokenizer"

  it("can peek at upcoming tokens", function()
    local t = tokenizer.new{str="node 1 2 3"}
    assert.same(t:peek(), {type="ident", value="node"})
    assert.same(t:peek_next(), {type="ws", value=" "})
    assert.same(t:next(), {type="ident", value="node"})
    assert.same(t:peek(), {type="ws", value=" "})
    assert.same(t:peek_next(), {type="integer", value=1})
  end)

  it("tokenizes identifiers", function()
    assert.same(Tokenizer:create{str="foo"}:next(), {type="ident", value="foo"})
  end)
end)