import ./common

type
  LowerBitsImpl* = range[0..7]
  LowerBits* = distinct LowerBitsImpl
    ## tags the last 3 bits of the pointer in place

template withTagInline*(val: uint, tag: LowerBits): Tagged[uint, LowerBits] =
  rawTagged[uint, LowerBits](val or tag.uint)

template untagInline*(tagged: Tagged[uint, LowerBits]): uint =
  tagged.raw and not 0b111'u

template splitTagInline*(tagged: Tagged[uint, LowerBits]): LowerBits =
  LowerBits(tagged.raw and 0b111)

proc withTag*(val: uint, tag: LowerBits): Tagged[uint, LowerBits] {.inline.} = withTagInline(val, tag)
proc untag*(tagged: Tagged[uint, LowerBits]): uint {.inline.} = untagInline(tagged)
proc splitTag*(tagged: Tagged[uint, LowerBits]): LowerBits {.inline.} = splitTagInline(tagged)

implUintPointerTags(LowerBits)

type LowerBitsTagged*[T] = Tagged[T, LowerBits]

proc tagLowerBits*[T](val: T, tag: LowerBitsImpl): LowerBitsTagged[T] {.inline.} =
  withTag(val, LowerBits(tag))

template getTag*[T](tagged: LowerBitsTagged[T]): LowerBitsImpl =
  LowerBitsImpl(splitTag(tagged))
