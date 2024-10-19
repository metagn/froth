import ./[common, destructorimpl]

type UpperByteTagged*[T: PointerLike] = distinct pointer

const topByte = 0xFF.uint shl 56

template doTagImpl[T](x: T, tag: uint): UpperByteTagged[T] =
  # no range check
  cast[UpperByteTagged[T]]((cast[uint](cast[pointer](x)) and not topByte) or (tag shl 56))

template untagImpl[T](x: UpperByteTagged[T]): T =
  cast[T](ashr(cast[int](x) shl 8, 8))

template getTagImpl[T](x: UpperByteTagged[T]): uint =
  (cast[uint](x) and topByte) shr 56 

implDestructors(UpperByteTagged, doTagImpl, untagImpl, getTagImpl)

proc tagUpperByte*[T: PointerLike](p: T, tag: byte): UpperByteTagged[T] {.inline.} =
  doTagImpl(p, uint(tag))

proc tag*[T](p: UpperByteTagged[T]): byte {.inline.} =
  cast[byte](getTagImpl(p))

proc tag*[T](p: var UpperByteTagged[T]): var byte {.inline.} =
  cast[ptr byte](addr p)[]

proc untag*[T](p: UpperByteTagged[T]): T {.inline.} =
  untagImpl(p)
