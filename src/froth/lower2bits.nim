import ./[common, destructorimpl]

type Lower2BitsTagged*[T: PointerLike] = distinct pointer
  ## tags the last 2 bits of the pointer in place

template doTagImplLower2Bits[T](x: T, tag: uint): Lower2BitsTagged[T] =
  # no range check
  cast[LowerBitsTagged[T]](cast[uint](cast[pointer](x)) or tag)

template untagImplLower2Bits[T](x: Lower2BitsTagged[T]): T =
  cast[T](cast[uint](x) and not 0b11.uint)

template getTagImplLower2Bits[T](x: Lower2BitsTagged[T]): uint =
  cast[uint](x) and 0b11

implDestructors(Lower2BitsTagged, doTagImplLower2Bits, untagImplLower2Bits, getTagImplLower2Bits)

proc tagLowerBits*[T: PointerLike](p: T, tag: range[0..3]): Lower2BitsTagged[T] {.inline.} =
  doTagImplLower2Bits(p, uint(tag))

proc tag*[T](p: Lower2BitsTagged[T]): range[0..3] {.inline.} =
  cast[range[0..3]](getTagImplLower2Bits(p))

proc untag*[T](p: Lower2BitsTagged[T]): T {.inline.} =
  untagImplLower2Bits(p)

template isNil*[T](p: Lower2BitsTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: Lower2BitsTagged[T]): T =
  p.untag[]
