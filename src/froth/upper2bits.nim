import ./[common, destructorimpl]

type Upper2BitsTagged*[T: PointerLike] = distinct pointer
  ## shifts pointer 2 bits to the right, shifts 2 bit tag 62 bits to the left

proc isPointer*[T](x: Upper2BitsTagged[T]): bool {.nodestroy, inline.} =
  ## overload to make sure destructors dont treat this value as a pointer depending on the tag
  ## if false, treated as raw bits (i.e. not nested or pointing to other data)
  true

const remainingBits = sizeof(int) * 8 - 2

template doTagImplUpper2Bits[T](x: T, tag: uint): Upper2BitsTagged[T] =
  # no range check
  cast[Upper2BitsTagged[T]]((cast[uint](cast[pointer](x)) shr 2) or (tag shl remainingBits))

template untagRawImplUpper2Bits[T](x: Upper2BitsTagged[T]): uint =
  cast[uint](x) shl 2

template getTagImplUpper2Bits[T](x: Upper2BitsTagged[T]): uint =
  cast[uint](x) shr remainingBits

implDestructors(Upper2BitsTagged, doTagImplUpper2Bits, untagRawImplUpper2Bits, getTagImplUpper2Bits)

proc tagUpper2Bits*[T: PointerLike](p: T, tag: range[0..3]): Upper2BitsTagged[T] {.inline.} =
  doTagImplUpper2Bits(p, uint(tag))

proc tag*[T](p: Upper2BitsTagged[T]): range[0..3] {.inline.} =
  cast[range[0..3]](getTagImplUpper2Bits(p))

proc untag*[T](p: Upper2BitsTagged[T]): T {.inline.} =
  cast[T](untagRawImplUpper2Bits(p))

proc untagRaw*[T](p: Upper2BitsTagged[T]): uint {.inline.} =
  untagRawImplUpper2Bits(p)

template isNil*[T](p: Upper2BitsTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: Upper2BitsTagged[T]): untyped =
  p.untag[]
