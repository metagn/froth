when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import froth/[common, condensate, lowerbyte]

type
  ValueKind = enum Nil, False, True, Int, Seq
  SeqImpl = ref object
    children: seq[Value]
  TaggedValue = Tagged[pointer, LowerByte]
  Value = Condensate[FullValue, TaggedValue]
  FullValue = object
    case kind: ValueKind
    of Nil, False, True: discard
    of Int: intValue: int # acts like 56 bit integer i guess since it sign extends like pointers
    of Seq: seqValue: SeqImpl

#implementCondensateDestructors Value

proc initValue*(kind: ValueKind): Value {.inline.} =
  rawCondensate(Value, LowerByte(kind), pointer(nil))

proc initIntValue*(i: int): Value {.inline.} =
  rawCondensate(Value, LowerByte(Int), cast[pointer](i))

proc initSeqValue*(s: sink SeqImpl): Value {.inline, nodestroy.} =
  rawCondensate(Value, LowerByte(Seq), cast[pointer](s))

template kind*(val: Value): ValueKind =
  ValueKind(rawTag(val))

template intValue*(val: Value): int =
  rawDecondense(val, int)

template seqValue*(val: Value): SeqImpl =
  rawDecondense(val, SeqImpl)

proc nilValue*(): Value = initValue(Nil)
proc toValue*(b: bool): Value = initValue(if b: True else: False)
proc toValue*(i: int): Value =
  result = initIntValue(i)
when defined(gcRefc):
  # object constructor calls genericSeqAssign otherwise
  proc toValue*(s: sink seq[Value]): Value =
    result = initSeqValue(SeqImpl(children: s))
else:
  # also works with sink but not tested to not rely on it
  proc toValue*(s: seq[Value]): Value =
    result = initSeqValue(SeqImpl(children: s))

proc getInt*(val: Value): int =
  assert val.kind == Int
  val.intValue
proc getSeq*(val: Value): seq[Value] =
  assert val.kind == Seq
  val.seqValue.children

proc `$`*(val: Value): string =
  case val.kind
  of Nil, False, True: result = $val.kind
  of Int: result = "Int " & $val.intValue
  of Seq: result = "Seq " & $val.seqValue.children

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
