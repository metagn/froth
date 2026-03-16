import ./[common, destructorimpl]

type UpperShortTagged*[T: PointerLike] = distinct pointer
  ## uses first 2 bytes as tag, sign extends when converting to pointer
  ## 
  ## tag bytes are addressable

proc isPointer*[T](x: UpperShortTagged[T]): bool {.nodestroy, inline.} =
  ## overload to make sure destructors dont treat this value as a pointer depending on the tag
  ## if false, treated as raw bits (i.e. not nested or pointing to other data)
  true

const remainingBits = sizeof(int) * 8 - 16
const topShort = 0xFFFF.uint shl remainingBits

template doTagImplUpperShort[T](x: T, tag: uint): UpperShortTagged[T] =
  # no range check
  cast[UpperShortTagged[T]]((cast[uint](cast[pointer](x)) and not topShort) or (tag shl remainingBits))

template untagRawImplUpperShort[T](x: UpperShortTagged[T]): int =
  ashr(cast[int](x) shl 16, 16)

template getTagImplUpperShort[T](x: UpperShortTagged[T]): uint =
  (cast[uint](x) and topShort) shr remainingBits

implDestructors(UpperShortTagged, doTagImplUpperShort, untagRawImplUpperShort, getTagImplUpperShort)

proc tagUpperShort*[T: PointerLike](p: T, tag: uint16): UpperShortTagged[T] {.inline.} =
  doTagImplUpperShort(p, uint(tag))

proc tag*[T](p: UpperShortTagged[T]): uint16 {.inline.} =
  cast[uint16](getTagImplUpperShort(p))

proc tag*[T](p: var UpperShortTagged[T]): var uint16 {.inline.} =
  when cpuEndian == littleEndian:
    cast[ptr array[4, uint16]](addr p)[3]
  else:
    cast[ptr uint16](addr p)[]

proc untag*[T](p: UpperShortTagged[T]): T {.inline.} =
  cast[T](untagRawImplUpperShort(p))

proc untagRaw*[T](p: UpperShortTagged[T]): int {.inline.} =
  untagRawImplUpperShort(p)

template isNil*[T](p: UpperShortTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: UpperShortTagged[T]): untyped =
  p.untag[]
