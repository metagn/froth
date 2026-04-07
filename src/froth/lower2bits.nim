import ./common

type
  Lower2BitsImpl* = range[0..3]
  Lower2Bits* = distinct Lower2BitsImpl
    ## tags the last 2 bits of the pointer in place

proc tag*(val: uint, tag: Lower2Bits): Tagged[uint, Lower2Bits] {.inline, nodestroy.} =
  typeof(result)(val or tag.uint)

proc untag*(tagged: Tagged[uint, Lower2Bits]): uint {.inline, nodestroy.} =
  uint(tagged) and not 0b11'u

proc splitTag*(tagged: Tagged[uint, Lower2Bits]): Lower2Bits {.inline, nodestroy.} =
  typeof(result)(uint(tagged) and 0b11)

implUintPointerTags(Lower2Bits)

type Lower2BitsTagged*[T] = Tagged[T, Lower2Bits]

proc tagLower2Bits*[T](val: T, tag: Lower2BitsImpl): Lower2BitsTagged[T] {.inline.} =
  tag(val, Lower2Bits(tag))

template getTag*[T](tagged: Lower2BitsTagged[T]): Lower2BitsImpl =
  Lower2BitsImpl(splitTag(tagged))
