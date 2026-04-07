import ./common

type
  UpperShortImpl* = uint16
  UpperShort* = distinct UpperShortImpl
    ## uses first 2 bytes as tag, sign extends when converting to pointer
    ## 
    ## tag bytes are addressable

const remainingBits = sizeof(int) * 8 - 16
const topShort = 0xFFFF.uint shl remainingBits

template tagInline*(val: uint, tag: UpperShort): Tagged[uint, UpperShort] =
  Tagged[uint, UpperShort](raw: (val and not topShort) or (tag.uint shl remainingBits))

template untagInline*(tagged: Tagged[uint, UpperShort]): uint =
  cast[uint](ashr(cast[int](tagged.raw) shl 16, 16))

template splitTagInline*(tagged: Tagged[uint, UpperShort]): UpperShort =
  UpperShort((tagged.raw and topShort) shr remainingBits)

template splitTagMutInline*(tagged: var Tagged[uint, UpperShort]): var UpperShort =
  when cpuEndian == littleEndian:
    cast[ptr array[4, UpperShort]](addr tagged)[3]
  else:
    cast[ptr UpperShort](addr tagged)[]

proc tag*(val: uint, tag: UpperShort): Tagged[uint, UpperShort] {.inline.} = tagInline(val, tag)
proc untag*(tagged: Tagged[uint, UpperShort]): uint {.inline.} = untagInline(tagged)
proc splitTag*(tagged: Tagged[uint, UpperShort]): UpperShort {.inline.} = splitTagInline(tagged)
proc splitTagMut*(tagged: var Tagged[uint, UpperShort]): var UpperShort {.inline.} = splitTagMutInline(tagged)

implUintPointerTags(UpperShort, splitTagVar = true)

type UpperShortTagged*[T] = Tagged[T, UpperShort]

proc tagUpperShort*[T](val: T, tag: UpperShortImpl): UpperShortTagged[T] {.inline.} =
  tag(val, UpperShort(tag))

template getTag*[T](tagged: UpperShortTagged[T]): UpperShortImpl =
  UpperShortImpl(splitTag(tagged))

template getTagMut*[T](tagged: UpperShortTagged[T]): UpperShortImpl =
  UpperShortImpl(splitTagMut(tagged))
