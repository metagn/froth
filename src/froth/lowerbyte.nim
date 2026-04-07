import ./common

type
  LowerByteImpl* = byte
  LowerByte* = distinct LowerByteImpl
    ## uses last byte as tag, shifts pointer left by a byte,
    ## sign extends when converting to pointer
    ## 
    ## tag byte is addressable

template withTagInline*(val: uint, tag: LowerByte): Tagged[uint, LowerByte] =
  rawTagged[uint, LowerByte]((val shl 8) or tag.uint)

template untagInline*(tagged: Tagged[uint, LowerByte]): uint =
  cast[uint](ashr(cast[int](tagged.raw), 8))

template splitTagInline*(tagged: Tagged[uint, LowerByte]): LowerByte =
  LowerByte(tagged.raw and 0xFF)

template splitTagMutInline*(tagged: var Tagged[uint, LowerByte]): var LowerByte =
  when cpuEndian == littleEndian:
    cast[ptr LowerByte](addr tagged)[]
  else:
    cast[ptr array[8, LowerByte]](addr tagged)[7]

proc withTag*(val: uint, tag: LowerByte): Tagged[uint, LowerByte] {.inline.} = withTagInline(val, tag)
proc untag*(tagged: Tagged[uint, LowerByte]): uint {.inline.} = untagInline(tagged)
proc splitTag*(tagged: Tagged[uint, LowerByte]): LowerByte {.inline.} = splitTagInline(tagged)
proc splitTagMut*(tagged: var Tagged[uint, LowerByte]): var LowerByte {.inline.} = splitTagMutInline(tagged)

implUintPointerTags(LowerByte, splitTagVar = true)

type LowerByteTagged*[T] = Tagged[T, LowerByte]

proc tagLowerByte*[T](val: T, tag: LowerByteImpl): LowerByteTagged[T] {.inline.} =
  withTag(val, LowerByte(tag))

template getTag*[T](tagged: LowerByteTagged[T]): LowerByteImpl =
  LowerByteImpl(splitTag(tagged))

template getTagMut*[T](tagged: LowerByteTagged[T]): LowerByteImpl =
  LowerByteImpl(splitTagMut(tagged))
