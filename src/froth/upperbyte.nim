import ./common

type
  UpperByteImpl* = byte
  UpperByte* = distinct UpperByteImpl
    ## uses first byte as tag, sign extends when converting to pointer
    ## 
    ## tag byte is addressable

const remainingBits = sizeof(int) * 8 - 8
const topByte = 0xFF.uint shl remainingBits

template tagInline*(val: uint, tag: UpperByte): Tagged[uint, UpperByte] =
  rawTagged[uint, UpperByte]((val and not topByte) or (tag.uint shl remainingBits))

template untagInline*(tagged: Tagged[uint, UpperByte]): uint =
  cast[uint](ashr(cast[int](tagged.rawValue) shl 8, 8))

template splitTagInline*(tagged: Tagged[uint, UpperByte]): UpperByte =
  UpperByte((tagged.rawValue and topByte) shr remainingBits)

template splitTagMutInline*(tagged: var Tagged[uint, UpperByte]): var UpperByte =
  when cpuEndian == littleEndian:
    cast[ptr array[8, UpperByte]](addr tagged)[7]
  else:
    cast[ptr UpperByte](addr tagged)[]

proc tag*(val: uint, tag: UpperByte): Tagged[uint, UpperByte] {.inline.} = tagInline(val, tag)
proc untag*(tagged: Tagged[uint, UpperByte]): uint {.inline.} = untagInline(tagged)
proc splitTag*(tagged: Tagged[uint, UpperByte]): UpperByte {.inline.} = splitTagInline(tagged)
proc splitTagMut*(tagged: var Tagged[uint, UpperByte]): var UpperByte {.inline.} = splitTagMutInline(tagged)

implUintPointerTags(UpperByte, splitTagVar = true)

type UpperByteTagged*[T] = Tagged[T, UpperByte]

proc tagUpperByte*[T](val: T, tag: UpperByteImpl): UpperByteTagged[T] {.inline.} =
  tag(val, UpperByte(tag))

template getTag*[T](tagged: UpperByteTagged[T]): UpperByteImpl =
  UpperByteImpl(splitTag(tagged))

template getTagMut*[T](tagged: UpperByteTagged[T]): UpperByteImpl =
  UpperByteImpl(splitTagMut(tagged))
