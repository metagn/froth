import ./[common, destructorimpl]

type LowerShortTagged*[T: PointerLike] = distinct pointer
  ## uses last 2 bytes as tag, shifts pointer left by 2 bytes,
  ## sign extends when converting to pointer
  ## 
  ## tag bytes are addressable

proc isPointer*[T](x: LowerShortTagged[T]): bool {.nodestroy, inline.} =
  ## overload to make sure destructors dont treat this value as a pointer depending on the tag
  ## if false, treated as raw bits (i.e. not nested or pointing to other data)
  true

template doTagImplLowerShort[T](x: T, tag: uint): LowerShortTagged[T] =
  # no range check
  cast[LowerShortTagged[T]]((cast[uint](cast[pointer](x)) shl 16) or tag)

template untagRawImplLowerShort[T](x: LowerShortTagged[T]): int =
  ashr(cast[int](x), 16)

template getTagImplLowerShort[T](x: LowerShortTagged[T]): uint =
  cast[uint](x) and 0xFFFF

implDestructors(LowerShortTagged, doTagImplLowerShort, untagRawImplLowerShort, getTagImplLowerShort)

proc tagLowerShort*[T: PointerLike](p: T, tag: uint16): LowerShortTagged[T] {.inline.} =
  doTagImplLowerShort(p, uint(tag))

proc tag*[T](p: LowerShortTagged[T]): uint16 {.inline.} =
  cast[uint16](getTagImplLowerShort(p))

proc tag*[T](p: var LowerShortTagged[T]): var uint16 {.inline.} =
  when cpuEndian == littleEndian:
    cast[ptr uint16](addr p)[]
  else:
    cast[ptr array[4, uint16]](addr p)[3]

proc untag*[T](p: LowerShortTagged[T]): T {.inline.} =
  cast[T](untagRawImplLowerShort(p))

proc untagRaw*[T](p: LowerShortTagged[T]): int {.inline.} =
  untagRawImplLowerShort(p)

template isNil*[T](p: LowerShortTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: LowerShortTagged[T]): untyped =
  p.untag[]
