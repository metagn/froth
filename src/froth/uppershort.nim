import ./common

type
  UpperShortImpl* = uint16
  UpperShort* = distinct UpperShortImpl
    ## uses first 2 bytes as tag, sign extends when converting to pointer
    ## 
    ## tag bytes are addressable

const remainingBits = sizeof(int) * 8 - 16
const topShort = 0xFFFF.uint shl remainingBits

proc tag*(val: uint, tag: UpperShort): Tagged[uint, UpperShort] {.inline, nodestroy.} =
  typeof(result)((val and not topShort) or (tag.uint shl remainingBits))

proc untag*(tagged: Tagged[uint, UpperShort]): uint {.inline, nodestroy.} =
  cast[uint](ashr(cast[int](tagged) shl 16, 16))

proc splitTag*(tagged: Tagged[uint, UpperShort]): UpperShort {.inline, nodestroy.} =
  typeof(result)((uint(tagged) and topShort) shr remainingBits)

proc splitTag*(tagged: var Tagged[uint, UpperShort]): var UpperShort {.inline, nodestroy.} =
  when cpuEndian == littleEndian:
    cast[ptr array[4, UpperShort]](addr tagged)[3]
  else:
    cast[ptr UpperShort](addr tagged)[]

implUintPointerTags(UpperShort, splitTagVar = true)

type UpperShortTagged*[T] = Tagged[T, UpperShort]

proc tagUpperShort*[T](val: T, tag: UpperShortImpl): UpperShortTagged[T] {.inline.} =
  tag(val, UpperShort(tag))

template getTag*[T](tagged: UpperShortTagged[T]): UpperShortImpl =
  UpperShortImpl(splitTag(tagged))
