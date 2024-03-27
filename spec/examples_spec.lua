describe("examples", function()
  local kdl = require "kdl"
  local document = require "kdl.document"
  local node = require "kdl.node"
  local value = require "kdl.value"

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

  local function doc(nodes)
    return document.new(nodes)
  end

  local function n(name, entries, children)
    if children == nil and entries ~= nil then
      for _, v in pairs(entries) do
        if type(v) == "table" then
          children = entries
          entries = {}
          break
        end
      end
    end

    local nd = node.new(name, {}, children)
    for k, v in pairs(entries or {}) do
      if type(k) == "number" then nd:insert(value.new(v))
      else nd:insert(k, value.new(v))
      end
    end

    return nd
  end

  it("parses Cargo example", function()
    local actual = parse(readfile("spec/kdl-org/examples/Cargo.kdl"))
    local expected = doc{
      n("package", {
        n("name", { "kdl" }),
        n("version", { "0.0.0" }),
        n("description", { "The kdl document language" }),
        n("authors", { "Kat Marchán <kzm@zkat.tech>" }),
        n("license-file", { "LICENSE.md" }),
        n("edition", { "2018" })
      }),
      n("dependencies", {
        n("nom", { "6.0.1" }),
        n("thiserror", { "1.0.22" })
      })
    }
    assert.same(expected, actual)
  end)

  it("parses ci", function()
    local actual = parse(readfile("spec/kdl-org/examples/ci.kdl"))
    local expected = doc{
      n("name", { "CI" }),
      n("on", { "push", "pull_request" }),
      n("env", {
        n("RUSTFLAGS", { "-Dwarnings" })
      }),
      n("jobs", {
        n("fmt_and_docs", { "Check fmt & build docs" }, {
          n("runs-on", { "ubuntu-latest" }),
          n("steps", {
            n("step", { ["uses"]="actions/checkout@v1" }),
            n("step", { "Install Rust", ["uses"]="actions-rs/toolchain@v1" }, {
              n("profile", { "minimal" }),
              n("toolchain", { "stable" }),
              n("components", { "rustfmt" }),
              n("override", { true })
            }),
            n("step", { "rustfmt" }, {
              n("run", { "cargo", "fmt", "--all", "--", "--check" })
            }),
            n("step", { "docs" }, {
              n("run", { "cargo", "doc", "--no-deps" })
            })
          })
        }),
        n("build_and_test", { "Build & Test" }, {
          n("runs-on", { "${{ matrix.os }}" }),
          n("strategy", {
            n("matrix", {
              n("rust", { "1.46.0", "stable" }),
              n("os", { "ubuntu-latest", "macOS-latest", "windows-latest" })
            })
          }),
          n("steps", {
            n("step", { ["uses"]="actions/checkout@v1" }),
            n("step", { "Install Rust", ["uses"]="actions-rs/toolchain@v1" }, {
              n("profile", { "minimal" }),
              n("toolchain", { "${{ matrix.rust }}" }),
              n("components", { "clippy" }),
              n("override", { true })
            }),
            n("step", { "Clippy" }, {
              n("run", { "cargo", "clippy", "--all", "--", "-D", "warnings" })
            }),
            n("step", { "Run tests" }, {
              n("run", { "cargo", "test", "--all", "--verbose" })
            }),
            n("step", { "Other Stuff", ["run"]="echo foo\necho bar\necho baz" })
          })
        })
      })
    }
    assert.same(expected, actual)
  end)

  it("parses kdl-schema", function()
    -- file is too large to check equality, just checking if it parses at all
    assert.has_no.errors(function()
      kdl.parse_document(readfile("spec/kdl-org/examples/kdl-schema.kdl"))
    end)
  end)

  it("parses nuget", function()
    -- file is too large to check equality, just checking if it parses at all
    assert.has_no.errors(function()
      kdl.parse_document(readfile("spec/kdl-org/examples/nuget.kdl"))
    end)
  end)
end)