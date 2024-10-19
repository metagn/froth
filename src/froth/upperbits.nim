import ./[common, destructorimpl]

type UpperBitsTagged*[T: PointerLike] = distinct pointer

template doTagImplUpperBits[T](x: T, tag: uint): UpperBitsTagged[T] =
  # no range check
  cast[UpperBitsTagged[T]]((cast[uint](cast[pointer](x)) shr 3) or (tag shl 61))

template untagImplUpperBits[T](x: UpperBitsTagged[T]): T =
  cast[T](cast[uint](x) shl 3)

template getTagImplUpperBits[T](x: UpperBitsTagged[T]): uint =
  cast[uint](x) shr 61

implDestructors(UpperBitsTagged, doTagImplUpperBits, untagImplUpperBits, getTagImplUpperBits)

proc tagUpperBits*[T: PointerLike](p: T, tag: range[0..7]): UpperBitsTagged[T] {.inline.} =
  doTagImplUpperBits(p, uint(tag))

proc tag*[T](p: UpperBitsTagged[T]): range[0..7] {.inline.} =
  cast[range[0..7]](getTagImplUpperBits(p))

proc untag*[T](p: UpperBitsTagged[T]): T {.inline.} =
  untagImplUpperBits(p)
