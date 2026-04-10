when (NimMajor, NimMinor) >= (1, 4):
  when (compiles do: import nimbleutils):
    import nimbleutils
    # https://github.com/metagn/nimbleutils

when not declared(runTests):
  {.error: "tests task not implemented, need nimbleutils".}

import std/[os, strutils]

var tests: seq[FilePath]
for dir in ["tests"]:
  for kind, f in walkDir(dir):
    if kind == pcFile and f.endsWith(".nim"):
      if (NimMajor, NimMinor, NimPatch) < (2, 2, 10) and f.endsWith("test_simple_combined.nim"):
        # disable test until https://github.com/nim-lang/Nim/pull/25717
        discard
      else:
        tests.add f

runTests(
  tests,
  # refc completely broken
  optionCombos = @["--mm:refc", "--mm:orc"],
  backends = {c, cpp},
)
