import ./[common, destructorimpl]

type UpperByteTagged*[T: PointerLike] = distinct pointer
  ## uses first byte as tag, sign extends when converting to pointer
  ## 
  ## tag byte is addressable

const remainingBits = sizeof(int) * 8 - 8
const topByte = 0xFF.uint shl remainingBits

template doTagImplUpperByte[T](x: T, tag: uint): UpperByteTagged[T] =
  # no range check
  cast[UpperByteTagged[T]]((cast[uint](cast[pointer](x)) and not topByte) or (tag shl remainingBits))

template untagImplUpperByte[T](x: UpperByteTagged[T]): T =
  cast[T](ashr(cast[int](x) shl 8, 8))

template getTagImplUpperByte[T](x: UpperByteTagged[T]): uint =
  (cast[uint](x) and topByte) shr remainingBits 

implDestructors(UpperByteTagged, doTagImplUpperByte, untagImplUpperByte, getTagImplUpperByte)

proc tagUpperByte*[T: PointerLike](p: T, tag: byte): UpperByteTagged[T] {.inline.} =
  doTagImplUpperByte(p, uint(tag))

proc tag*[T](p: UpperByteTagged[T]): byte {.inline.} =
  cast[byte](getTagImplUpperByte(p))

proc tag*[T](p: var UpperByteTagged[T]): var byte {.inline.} =
  when cpuEndian == littleEndian:
    cast[ptr array[8, byte]](addr p)[7]
  else:
    cast[ptr byte](addr p)[]

proc untag*[T](p: UpperByteTagged[T]): T {.inline.} =
  untagImplUpperByte(p)

template isNil*[T](p: UpperByteTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: UpperByteTagged[T]): T =
  p.untag[]
