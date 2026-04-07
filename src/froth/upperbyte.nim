import ./common

type
  UpperByteImpl* = byte
  UpperByte* = distinct UpperByteImpl
    ## uses first byte as tag, sign extends when converting to pointer
    ## 
    ## tag byte is addressable

const remainingBits = sizeof(int) * 8 - 8
const topByte = 0xFF.uint shl remainingBits

proc tag*(val: uint, tag: UpperByte): Tagged[uint, UpperByte] {.inline, nodestroy.} =
  Tagged[uint, UpperByte](raw: (val and not topByte) or (tag.uint shl remainingBits))

proc untag*(tagged: Tagged[uint, UpperByte]): uint {.inline, nodestroy.} =
  cast[uint](ashr(cast[int](tagged.raw) shl 8, 8))

proc splitTag*(tagged: Tagged[uint, UpperByte]): UpperByte {.inline, nodestroy.} =
  UpperByte((tagged.raw and topByte) shr remainingBits)

proc splitTagMut*(tagged: var Tagged[uint, UpperByte]): var UpperByte {.inline, nodestroy.} =
  when cpuEndian == littleEndian:
    cast[ptr array[8, UpperByte]](addr tagged)[7]
  else:
    cast[ptr UpperByte](addr tagged)[]

implUintPointerTags(UpperByte, splitTagVar = true)

type UpperByteTagged*[T] = Tagged[T, UpperByte]

proc tagUpperByte*[T](val: T, tag: UpperByteImpl): UpperByteTagged[T] {.inline.} =
  tag(val, UpperByte(tag))

template getTag*[T](tagged: UpperByteTagged[T]): UpperByteImpl =
  UpperByteImpl(splitTag(tagged))

template getTagMut*[T](tagged: UpperByteTagged[T]): UpperByteImpl =
  UpperByteImpl(splitTagMut(tagged))
