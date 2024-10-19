import ./[common, destructorimpl]

type LowerBitsTagged*[T: PointerLike] = distinct pointer

template doTagImpl[T](x: T, tag: uint): LowerBitsTagged[T] =
  # no range check
  cast[LowerBitsTagged[T]](cast[uint](cast[pointer](x)) or tag)

template untagImpl[T](x: LowerBitsTagged[T]): T =
  cast[T](cast[uint](x) and not 0b111.uint)

template getTagImpl[T](x: LowerBitsTagged[T]): uint =
  cast[uint](x) and 0b111

implDestructors(LowerBitsTagged, doTagImpl, untagImpl, getTagImpl)

proc tagLowerBits*[T: PointerLike](p: T, tag: range[0..7]): LowerBitsTagged[T] {.inline.} =
  doTagImpl(p, uint(tag))

proc tag*[T](p: LowerBitsTagged[T]): range[0..7] {.inline.} =
  cast[range[0..7]](getTagImpl(p))

proc untag*[T](p: LowerBitsTagged[T]): T {.inline.} =
  untagImpl(p)
