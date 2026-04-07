import ./common

type
  LowerShortImpl* = uint16
  LowerShort* = distinct LowerShortImpl
    ## uses last 2 bytes as tag, shifts pointer left by 2 bytes,
    ## sign extends when converting to pointer
    ## 
    ## tag bytes are addressable

template tagInline*(val: uint, tag: LowerShort): Tagged[uint, LowerShort] =
  rawTagged[uint, LowerShort]((val shl 16) or tag.uint)

template untagInline*(tagged: Tagged[uint, LowerShort]): uint =
  cast[uint](ashr(cast[int](tagged.raw), 16))

template splitTagInline*(tagged: Tagged[uint, LowerShort]): LowerShort =
  LowerShort(tagged.raw and 0xFFFF)

template splitTagMutInline*(tagged: var Tagged[uint, LowerShort]): var LowerShort =
  when cpuEndian == littleEndian:
    cast[ptr LowerShort](addr tagged)[]
  else:
    cast[ptr array[4, LowerShort]](addr tagged)[3]

proc tag*(val: uint, tag: LowerShort): Tagged[uint, LowerShort] {.inline.} = tagInline(val, tag)
proc untag*(tagged: Tagged[uint, LowerShort]): uint {.inline.} = untagInline(tagged)
proc splitTag*(tagged: Tagged[uint, LowerShort]): LowerShort {.inline.} = splitTagInline(tagged)
proc splitTagMut*(tagged: var Tagged[uint, LowerShort]): var LowerShort {.inline.} = splitTagMutInline(tagged)

implUintPointerTags(LowerShort, splitTagVar = true)

type LowerShortTagged*[T] = Tagged[T, LowerShort]

proc tagLowerShort*[T](val: T, tag: LowerShortImpl): LowerShortTagged[T] {.inline.} =
  tag(val, LowerShort(tag))

template getTag*[T](tagged: LowerShortTagged[T]): LowerShortImpl =
  LowerShortImpl(splitTag(tagged))

template getTagMut*[T](tagged: LowerShortTagged[T]): LowerShortImpl =
  LowerShortImpl(splitTagMut(tagged))
