import ./[common, destructorimpl]

type UpperBitsTagged*[T: PointerLike] = distinct pointer

template doTagImpl[T](x: T, tag: uint): UpperBitsTagged[T] =
  # no range check
  cast[UpperBitsTagged[T]]((cast[uint](cast[pointer](x)) shr 3) or (tag shl 61))

template untagImpl[T](x: UpperBitsTagged[T]): T =
  cast[T](cast[uint](x) shl 3)

template getTagImpl[T](x: UpperBitsTagged[T]): uint =
  cast[uint](x) shr 61

implDestructors(UpperBitsTagged, doTagImpl, untagImpl, getTagImpl)

proc tagUpperBits*[T: PointerLike](p: T, tag: range[0..7]): UpperBitsTagged[T] {.inline.} =
  doTagImpl(p, uint(tag))

proc tag*[T](p: UpperBitsTagged[T]): range[0..7] {.inline.} =
  cast[range[0..7]](getTagImpl(p))

proc untag*[T](p: UpperBitsTagged[T]): T {.inline.} =
  untagImpl(p)
