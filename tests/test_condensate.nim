when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import froth/[common, condensate, lowerbyte]

type
  ValueKind = enum Nil, False, True, Int, Seq
  FullValue = object
    case kind: ValueKind
    of Nil, False, True: discard
    of Int: intValue: int # acts like 56 bit integer i guess since it sign extends like pointers
    of Seq: seqValue: SeqImpl
  TaggedValue = Tagged[pointer, LowerByte]
  Value = Condensate[FullValue, TaggedValue]
  SeqImpl = ref object
    children: seq[Value]

#implementCondensateDestructors Value

proc nilValue*(): Value = condensate(FullValue(kind: Nil), TaggedValue)
proc toValue*(b: bool): Value = condensate(FullValue(kind: if b: True else: False), TaggedValue)
proc toValue*(i: int): Value =
  result = condensate(FullValue(kind: Int, intValue: i), TaggedValue)
when defined(gcRefc):
  # object constructor calls genericSeqAssign otherwise
  proc toValue*(s: sink seq[Value]): Value =
    result = condensate(FullValue(kind: Seq, seqValue: SeqImpl(children: s)), TaggedValue)
else:
  # also works with sink but not tested to not rely on it
  proc toValue*(s: seq[Value]): Value =
    result = condensate(FullValue(kind: Seq, seqValue: SeqImpl(children: s)), TaggedValue)

proc getInt*(val: Value): int =
  let full = decondense(val)
  assert full.kind == Int
  full.intValue
proc getSeq*(val: Value): seq[Value] =
  let full = decondense(val)
  assert full.kind == Seq
  full.seqValue.children

proc `$`*(val: Value): string =
  let full = decondense(val)
  case full.kind
  of Nil, False, True: result = $full.kind
  of Int: result = "Int " & $full.intValue
  of Seq: result = "Seq " & $full.seqValue.children

proc kind*(val: Value): ValueKind {.inline.} =
  decondense(val).kind

test "conditional tagging":
  proc test() =
    let val = toValue @[toValue 123, toValue @[toValue true, toValue 456, nilValue()], toValue false, toValue 789]
    check val.kind == Seq
    check val.getSeq.len == 4
    check $val.getSeq == "@[Int 123, Seq @[True, Int 456, Nil], False, Int 789]"
    check val.getSeq[0].kind == Int
    check val.getSeq[0].getInt == 123
    check val.getSeq[1].kind == Seq
    check val.getSeq[1].getSeq.len == 3
    check $val.getSeq[1].getSeq == "@[True, Int 456, Nil]"
    check val.getSeq[1].getSeq[0].kind == True
    check val.getSeq[1].getSeq[1].kind == Int
    check val.getSeq[1].getSeq[1].getInt == 456
    check val.getSeq[1].getSeq[2].kind == Nil
    check val.getSeq[2].kind == False
    check val.getSeq[3].kind == Int
    check val.getSeq[3].getInt == 789
  when true: test()
