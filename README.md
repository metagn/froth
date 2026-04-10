# froth

tagged pointer types with destructors, focusing on 64-bit

Warning: Not vetted for leaks/UB/memory access issues, ideally would be done with CI.

```nim
import froth

type
  ValueKind = enum Nil, False, True, Int, Seq
  SeqValue = ref object
    children: seq[Value]
  Value {.condensate.} = object of pointer
    case kind: ValueKind of LowerByte
    of Nil, False, True: discard
    of Int: intValue: int
    of Seq: seqValue: SeqValue
  # Value becomes distinct Tagged[pointer, LowerByte]

proc nilValue(): Value = initValue(Nil)
proc toValue(b: bool): Value = initValue(if b: True else: False)
proc toValue(i: int): Value =
  result = initIntValue(Int, i)
proc toValue(s: sink seq[Value]): Value =
  result = initSeqValue(Seq, SeqValue(children: s))

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

let val = toValue @[toValue 123, toValue @[toValue true, toValue 456, nilValue()], toValue false, toValue 789]
assert $val.getSeq == "@[Int 123, Seq @[True, Int 456, Nil], False, Int 789]"
```
