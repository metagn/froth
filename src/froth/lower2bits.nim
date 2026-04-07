import ./common

type
  Lower2BitsImpl* = range[0..3]
  Lower2Bits* = distinct Lower2BitsImpl
    ## tags the last 2 bits of the pointer in place

template tagInline*(val: uint, tag: Lower2Bits): Tagged[uint, Lower2Bits] =
  Tagged[uint, Lower2Bits](raw: val or tag.uint)

template untagInline*(tagged: Tagged[uint, Lower2Bits]): uint =
  tagged.raw and not 0b11'u

template splitTagInline*(tagged: Tagged[uint, Lower2Bits]): Lower2Bits =
  Lower2Bits(tagged.raw and 0b11)

proc tag*(val: uint, tag: Lower2Bits): Tagged[uint, Lower2Bits] {.inline.} = tagInline(val, tag)
proc untag*(tagged: Tagged[uint, Lower2Bits]): uint {.inline.} = untagInline(tagged)
proc splitTag*(tagged: Tagged[uint, Lower2Bits]): Lower2Bits {.inline.} = splitTagInline(tagged)

implUintPointerTags(Lower2Bits)

type Lower2BitsTagged*[T] = Tagged[T, Lower2Bits]

proc tagLower2Bits*[T](val: T, tag: Lower2BitsImpl): Lower2BitsTagged[T] {.inline.} =
  tag(val, Lower2Bits(tag))

template getTag*[T](tagged: Lower2BitsTagged[T]): Lower2BitsImpl =
  Lower2BitsImpl(splitTag(tagged))
