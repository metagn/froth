when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import froth/lowerbyte

type
  ValueKind = enum Nil, False, True, Int, Seq
  Value = LowerByteTagged[SeqImpl]
  SeqImpl = ref object
    children: seq[Value]

proc isPointer*(val: Value): bool {.nodestroy, inline.} =
  ValueKind(val.tag) == Seq

proc nilValue*(): Value = tagLowerByte(SeqImpl(nil), byte(Nil))
proc toValue*(b: bool): Value =
  tagLowerByte(SeqImpl(nil), byte(if b: True else: False))
proc toValue*(i: int): Value =
  tagLowerByte(cast[SeqImpl](i), byte(Int))
proc toValue*(s: seq[Value]): Value =
  tagLowerByte(SeqImpl(children: s), byte(Seq))

proc kind*(val: Value): ValueKind =
  ValueKind(val.tag)
proc getInt*(val: Value): int =
  assert val.kind == Int
  val.untagRaw
proc getSeq*(val: Value): seq[Value] =
  assert val.kind == Seq
  val.untag.children

test "conditional tagging":
  let val = toValue @[toValue 123, toValue @[toValue true, toValue 456, nilValue()], toValue false, toValue 789]
  check val.kind == Seq
  check val.getSeq.len == 4
  check val.getSeq[0].kind == Int
  check val.getSeq[0].getInt == 123
  check val.getSeq[1].kind == Seq
  check val.getSeq[1].getSeq.len == 3
  check val.getSeq[1].getSeq[0].kind == True
  check val.getSeq[1].getSeq[1].kind == Int
  check val.getSeq[1].getSeq[1].getInt == 456
  check val.getSeq[1].getSeq[2].kind == Nil
  check val.getSeq[2].kind == False
  check val.getSeq[3].kind == Int
  check val.getSeq[3].getInt == 789
