when (NimMajor, NimMinor) >= (1, 4):
  when (compiles do: import nimbleutils):
    import nimbleutils
    # https://github.com/metagn/nimbleutils

when not declared(runTests):
  {.error: "tests task not implemented, need nimbleutils".}

runTests(
  optionCombos = @["--mm:refc", "--mm:orc"],
  backends = {c, cpp},
)
