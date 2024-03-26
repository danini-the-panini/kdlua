package = "kdlua"
version = "dev-1"
rockspec_format = "3.0"
source = {
   url = "git://github.com/danini-the-pamini/kdlua"
}
description = {
   summary = "KDL Document Language",
   detailed = "Lua implementation of the KDL Document Language Spec",
   homepage = "https://github.com/danini-the-pamini/kdlua",
   license = "MIT"
}
build = {
   type = "builtin",
   modules = {
      ["kdl"] = "src/kdl.lua",
      ["kdl.document"] = "src/document.lua",
      ["kdl.node"] = "src/node.lua",
      ["kdl.value"] = "src/value.lua",
      ["kdl.parser"] = "src/parser.lua",
      ["kdl.tokenizer"] = "src/tokenizer.lua"
   }
}
test = {
   type = "busted"
}