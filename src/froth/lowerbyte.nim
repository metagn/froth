import ./[common, destructorimpl]

type LowerByteTagged*[T: PointerLike] = distinct pointer
  ## uses last byte as tag, shifts pointer left by a byte,
  ## sign extends when converting to pointer
  ## 
  ## tag byte is addressable

template doTagImplLowerByte[T](x: T, tag: uint): LowerByteTagged[T] =
  # no range check
  cast[LowerByteTagged[T]]((cast[uint](cast[pointer](x)) shl 8) or tag)

template untagImplLowerByte[T](x: LowerByteTagged[T]): T =
  cast[T](ashr(cast[int](x), 8))

template getTagImplLowerByte[T](x: LowerByteTagged[T]): uint =
  cast[uint](x) and 0xFF

implDestructors(LowerByteTagged, doTagImplLowerByte, untagImplLowerByte, getTagImplLowerByte)

proc tagLowerByte*[T: PointerLike](p: T, tag: byte): LowerByteTagged[T] {.inline.} =
  doTagImplLowerByte(p, uint(tag))

proc tag*[T](p: LowerByteTagged[T]): byte {.inline.} =
  cast[byte](getTagImplLowerByte(p))

proc tag*[T](p: var LowerByteTagged[T]): var byte {.inline.} =
  when cpuEndian == littleEndian:
    cast[ptr byte](addr p)[]
  else:
    cast[ptr array[8, byte]](addr p)[7]

proc untag*[T](p: LowerByteTagged[T]): T {.inline.} =
  untagImplLowerByte(p)
