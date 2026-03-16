import ./[common, destructorimpl]

type LowerBitsTagged*[T: PointerLike] = distinct pointer
  ## tags the last 3 bits of the pointer in place

proc isPointer*[T](x: LowerBitsTagged[T]): bool {.nodestroy, inline.} =
  ## overload to make sure destructors dont treat this value as a pointer depending on the tag
  ## if false, treated as raw bits (i.e. not nested or pointing to other data)
  true

template doTagImplLowerBits[T](x: T, tag: uint): LowerBitsTagged[T] =
  # no range check
  cast[LowerBitsTagged[T]](cast[uint](cast[pointer](x)) or tag)

template untagRawImplLowerBits[T](x: LowerBitsTagged[T]): uint =
  cast[uint](x) and not 0b111.uint

template getTagImplLowerBits[T](x: LowerBitsTagged[T]): uint =
  cast[uint](x) and 0b111

implDestructors(LowerBitsTagged, doTagImplLowerBits, untagRawImplLowerBits, getTagImplLowerBits)

proc tagLowerBits*[T: PointerLike](p: T, tag: range[0..7]): LowerBitsTagged[T] {.inline.} =
  doTagImplLowerBits(p, uint(tag))

proc tag*[T](p: LowerBitsTagged[T]): range[0..7] {.inline.} =
  cast[range[0..7]](getTagImplLowerBits(p))

proc untag*[T](p: LowerBitsTagged[T]): T {.inline.} =
  cast[T](untagRawImplLowerBits(p))

proc untagRaw*[T](p: LowerBitsTagged[T]): uint {.inline.} =
  untagRawImplLowerBits(p)

template isNil*[T](p: LowerBitsTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: LowerBitsTagged[T]): untyped =
  p.untag[]
