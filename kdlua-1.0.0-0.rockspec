package = "kdlua"
version = "1.0.0-0"
rockspec_format = "3.0"
source = {
   url = "git://github.com/danini-the-panini/kdlua"
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
      ["kdl.tokenizer"] = "src/tokenizer.lua",
      ["kdl.stringdumper"] = "src/stringdumper.lua",
      ["kdl.util"] = "src/util.lua",
      ["kdl.v1.parser"] = "src/v1/parser.lua",
      ["kdl.v1.tokenizer"] = "src/v1/tokenizer.lua",
      ["kdl.v1.util"] = "src/v1/util.lua"
   }
}
test = {
   type = "busted"
}
dependencies = {
   "luautf8 >= 0.1.5 < 1.0"
}
test_dependencies = {
   "luafilesystem >= 1.8.0 < 2.0.0"
}
