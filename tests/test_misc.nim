when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import froth/lowerbyte

type
  A = ref object
    val: int
    b: LowerByteTagged[B]
  B = ref object
    val: int
    c: LowerByteTagged[C]
  C = ref object
    val: int
    d: LowerByteTagged[D]
  D = ref object
    val: int
    a: LowerByteTagged[A]
  
test "complex cycle":
  let a = A(val: 123, b: B(val: 456).tagLowerByte(12))
  block:
    let c = C(val: 789, d: D(val: 1011, a: a.tagLowerByte(6)).tagLowerByte(24))
    check c.val == 789
    check c.d.untag.val == 1011
    check c.d.tag == 24
    check c.d.untag.a.untag.val == 123
    check c.d.untag.a.tag == 6
    check c.d.untag.a.untag.b.untag.val == 456
    check c.d.untag.a.untag.b.tag == 12
  check a.val == 123
  check a.b.untag.val == 456
  check a.b.tag == 12
  block:
    let c = C(val: 789, d: D(val: 1011, a: a.tagLowerByte(6)).tagLowerByte(24))
    check c.val == 789
    check c.d.untag.val == 1011
    check c.d.tag == 24
    check c.d.untag.a.untag.val == 123
    check c.d.untag.a.tag == 6
    check c.d.untag.a.untag.b.untag.val == 456
    check c.d.untag.a.untag.b.tag == 12
    a.b.untag.c = c.tagLowerByte(18)
  check a.val == 123
  check a.b.untag.val == 456
  check a.b.tag == 12
  check a.b.untag.c.untag.val == 789
  check a.b.untag.c.tag == 18
  check a.b.untag.c.untag.d.untag.val == 1011
  check a.b.untag.c.untag.d.tag == 24
