import ./common

type
  LowerBitsImpl* = range[0..7]
  LowerBits* = distinct LowerBitsImpl
    ## tags the last 3 bits of the pointer in place

template tagInline*(val: uint, tag: LowerBits): Tagged[uint, LowerBits] =
  Tagged[uint, LowerBits](raw: val or tag.uint)

template untagInline*(tagged: Tagged[uint, LowerBits]): uint =
  tagged.raw and not 0b111'u

template splitTagInline*(tagged: Tagged[uint, LowerBits]): LowerBits =
  LowerBits(tagged.raw and 0b111)

proc tag*(val: uint, tag: LowerBits): Tagged[uint, LowerBits] {.inline.} = tagInline(val, tag)
proc untag*(tagged: Tagged[uint, LowerBits]): uint {.inline.} = untagInline(tagged)
proc splitTag*(tagged: Tagged[uint, LowerBits]): LowerBits {.inline.} = splitTagInline(tagged)

implUintPointerTags(LowerBits)

type LowerBitsTagged*[T] = Tagged[T, LowerBits]

proc tagLowerBits*[T](val: T, tag: LowerBitsImpl): LowerBitsTagged[T] {.inline.} =
  tag(val, LowerBits(tag))

template getTag*[T](tagged: LowerBitsTagged[T]): LowerBitsImpl =
  LowerBitsImpl(splitTag(tagged))
