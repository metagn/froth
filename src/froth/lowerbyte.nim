import ./common

type
  LowerByteImpl* = byte
  LowerByte* = distinct LowerByteImpl
    ## uses last byte as tag, shifts pointer left by a byte,
    ## sign extends when converting to pointer
    ## 
    ## tag byte is addressable

proc tag*(val: uint, tag: LowerByte): Tagged[uint, LowerByte] {.inline, nodestroy.} =
  typeof(result)((val shl 8) or tag.uint)

proc untag*(tagged: Tagged[uint, LowerByte]): uint {.inline, nodestroy.} =
  cast[uint](ashr(cast[int](tagged), 8))

proc splitTag*(tagged: Tagged[uint, LowerByte]): LowerByte {.inline, nodestroy.} =
  typeof(result)(uint(tagged) and 0xFF)

proc splitTag*(tagged: var Tagged[uint, LowerByte]): var LowerByte {.inline, nodestroy.} =
  when cpuEndian == littleEndian:
    cast[ptr LowerByte](addr tagged)[]
  else:
    cast[ptr array[8, LowerByte]](addr tagged)[7]

implUintPointerTags(LowerByte, splitTagVar = true)

type LowerByteTagged*[T] = Tagged[T, LowerByte]

proc tagLowerByte*[T](val: T, tag: LowerByteImpl): LowerByteTagged[T] {.inline.} =
  tag(val, LowerByte(tag))

template getTag*[T](tagged: LowerByteTagged[T]): LowerByteImpl =
  LowerByteImpl(splitTag(tagged))
