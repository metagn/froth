import ./common

type
  LowerShortImpl* = uint16
  LowerShort* = distinct LowerShortImpl
    ## uses last 2 bytes as tag, shifts pointer left by 2 bytes,
    ## sign extends when converting to pointer
    ## 
    ## tag bytes are addressable

proc tag*(val: uint, tag: LowerShort): Tagged[uint, LowerShort] {.inline, nodestroy.} =
  typeof(result)((val shl 16) or tag.uint)

proc untag*(tagged: Tagged[uint, LowerShort]): uint {.inline, nodestroy.} =
  cast[uint](ashr(cast[int](tagged), 16))

proc splitTag*(tagged: Tagged[uint, LowerShort]): LowerShort {.inline, nodestroy.} =
  typeof(result)(uint(tagged) and 0xFFFF)

proc splitTag*(tagged: var Tagged[uint, LowerShort]): var LowerShort {.inline, nodestroy.} =
  when cpuEndian == littleEndian:
    cast[ptr LowerShort](addr tagged)[]
  else:
    cast[ptr array[4, LowerShort]](addr tagged)[3]

implUintPointerTags(LowerShort, splitTagVar = true)

type LowerShortTagged*[T] = Tagged[T, LowerShort]

proc tagLowerShort*[T](val: T, tag: LowerShortImpl): LowerShortTagged[T] {.inline.} =
  tag(val, LowerShort(tag))

template getTag*[T](tagged: LowerShortTagged[T]): LowerShortImpl =
  LowerShortImpl(splitTag(tagged))
