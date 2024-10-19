import ./[common, destructorimpl]

type LowerByteTagged*[T: PointerLike] = distinct pointer

template doTagImpl[T](x: T, tag: uint): LowerByteTagged[T] =
  # no range check
  cast[LowerByteTagged[T]]((cast[uint](cast[pointer](x)) shl 8) or tag)

template untagImpl[T](x: LowerByteTagged[T]): T =
  cast[T](ashr(cast[int](x), 8))

template getTagImpl[T](x: LowerByteTagged[T]): uint =
  cast[uint](x) and 0xFF

implDestructors(LowerByteTagged, doTagImpl, untagImpl, getTagImpl)

proc tagLowerByte*[T: PointerLike](p: T, tag: byte): LowerByteTagged[T] {.inline.} =
  doTagImpl(p, uint(tag))

proc tag*[T](p: LowerByteTagged[T]): byte {.inline.} =
  cast[byte](getTagImpl(p))

proc tag*[T](p: var LowerByteTagged[T]): var byte {.inline.} =
  cast[ptr array[8, byte]](addr p)[7]

proc untag*[T](p: LowerByteTagged[T]): T {.inline.} =
  untagImpl(p)
