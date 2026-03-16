import ./[common, destructorimpl]

type UpperBitsTagged*[T: PointerLike] = distinct pointer
  ## shifts pointer 3 bits to the right, shifts 3 bit tag 61 bits to the left

proc isPointer*[T](x: UpperBitsTagged[T]): bool {.nodestroy, inline.} =
  ## overload to make sure destructors dont treat this value as a pointer depending on the tag
  ## if false, treated as raw bits (i.e. not nested or pointing to other data)
  true

const remainingBits = sizeof(int) * 8 - 3

template doTagImplUpperBits[T](x: T, tag: uint): UpperBitsTagged[T] =
  # no range check
  cast[UpperBitsTagged[T]]((cast[uint](cast[pointer](x)) shr 3) or (tag shl remainingBits))

template untagRawImplUpperBits[T](x: UpperBitsTagged[T]): uint =
  cast[uint](x) shl 3

template getTagImplUpperBits[T](x: UpperBitsTagged[T]): uint =
  cast[uint](x) shr remainingBits

implDestructors(UpperBitsTagged, doTagImplUpperBits, untagRawImplUpperBits, getTagImplUpperBits)

proc tagUpperBits*[T: PointerLike](p: T, tag: range[0..7]): UpperBitsTagged[T] {.inline.} =
  doTagImplUpperBits(p, uint(tag))

proc tag*[T](p: UpperBitsTagged[T]): range[0..7] {.inline.} =
  cast[range[0..7]](getTagImplUpperBits(p))

proc untag*[T](p: UpperBitsTagged[T]): T {.inline.} =
  cast[T](untagRawImplUpperBits(p))

proc untagRaw*[T](p: UpperBitsTagged[T]): uint {.inline.} =
  untagRawImplUpperBits(p)

template isNil*[T](p: UpperBitsTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: UpperBitsTagged[T]): untyped =
  p.untag[]
