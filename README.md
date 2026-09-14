# kdlua

[KDL](https://kdl.dev) for lua

## Install

```sh
luarocks install kdlua
```

## Usage

```lua
kdl = require("kdlua")

doc = kdl.parse_document("node foo bar=7 { qux 17 }")
doc.nodes[1].name #=> "node"
doc.nodes[1].entries[1] #=> "foo"
doc.nodes[1].entries["bar"] #=> 7
doc.nodes[1].children[1].name #=> "qux"
doc.nodes[1].children[1].entries[1] #=> 17
```
