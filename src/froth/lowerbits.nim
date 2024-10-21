import ./[common, destructorimpl]

type LowerBitsTagged*[T: PointerLike] = distinct pointer
  ## tags the last 3 bits of the pointer in place

template doTagImplLowerBits[T](x: T, tag: uint): LowerBitsTagged[T] =
  # no range check
  cast[LowerBitsTagged[T]](cast[uint](cast[pointer](x)) or tag)

template untagImplLowerBits[T](x: LowerBitsTagged[T]): T =
  cast[T](cast[uint](x) and not 0b111.uint)

template getTagImplLowerBits[T](x: LowerBitsTagged[T]): uint =
  cast[uint](x) and 0b111

implDestructors(LowerBitsTagged, doTagImplLowerBits, untagImplLowerBits, getTagImplLowerBits)

proc tagLowerBits*[T: PointerLike](p: T, tag: range[0..7]): LowerBitsTagged[T] {.inline.} =
  doTagImplLowerBits(p, uint(tag))

proc tag*[T](p: LowerBitsTagged[T]): range[0..7] {.inline.} =
  cast[range[0..7]](getTagImplLowerBits(p))

proc untag*[T](p: LowerBitsTagged[T]): T {.inline.} =
  untagImplLowerBits(p)

template isNil*[T](p: LowerBitsTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: LowerBitsTagged[T]): T =
  p.untag[]
