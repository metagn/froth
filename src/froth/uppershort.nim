import ./[common, destructorimpl]

type UpperShortTagged*[T: PointerLike] = distinct pointer
  ## uses first 2 bytes as tag, sign extends when converting to pointer
  ## 
  ## tag bytes are addressable

const topShort = 0xFFFF.uint shl 48

template doTagImplUpperShort[T](x: T, tag: uint): UpperShortTagged[T] =
  # no range check
  cast[UpperShortTagged[T]]((cast[uint](cast[pointer](x)) and not topShort) or (tag shl 48))

template untagImplUpperShort[T](x: UpperShortTagged[T]): T =
  cast[T](ashr(cast[int](x) shl 16, 16))

template getTagImplUpperShort[T](x: UpperShortTagged[T]): uint =
  (cast[uint](x) and topShort) shr 48 

implDestructors(UpperShortTagged, doTagImplUpperShort, untagImplUpperShort, getTagImplUpperShort)

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
  untagImplUpperShort(p)

template isNil*[T](p: UpperShortTagged[T]): bool =
  p.untag.isNil

template `[]`*[T](p: UpperShortTagged[T]): T =
  p.untag[]
