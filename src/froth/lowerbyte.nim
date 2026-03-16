import ./[common, destructorimpl]

type LowerByteTagged*[T: PointerLike] = distinct pointer
  ## uses last byte as tag, shifts pointer left by a byte,
  ## sign extends when converting to pointer
  ## 
  ## tag byte is addressable

proc isPointer*[T](x: LowerByteTagged[T]): bool {.nodestroy, inline.} =
  ## overload to make sure destructors dont treat this value as a pointer depending on the tag
  ## if false, treated as raw bits (i.e. not nested or pointing to other data)
  true

template doTagImplLowerByte[T](x: T, tag: uint): LowerByteTagged[T] =
  # no range check
  cast[LowerByteTagged[T]]((cast[uint](cast[pointer](x)) shl 8) or tag)

template untagRawImplLowerByte[T](x: LowerByteTagged[T]): int =
  ashr(cast[int](x), 8)

template getTagImplLowerByte[T](x: LowerByteTagged[T]): uint =
  cast[uint](x) and 0xFF

implDestructors(LowerByteTagged, doTagImplLowerByte, untagRawImplLowerByte, getTagImplLowerByte)

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
  cast[T](untagRawImplLowerByte(p))

proc untagRaw*[T](p: LowerByteTagged[T]): int {.inline.} =
  untagRawImplLowerByte(p)

template isNil*[T](p: LowerByteTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: LowerByteTagged[T]): untyped =
  p.untag[]
