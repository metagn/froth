import ./common

type
  LowerBitsImpl* = range[0..7]
  LowerBits* = distinct LowerBitsImpl
    ## tags the last 3 bits of the pointer in place

proc tag*(val: uint, tag: LowerBits): Tagged[uint, LowerBits] {.inline, nodestroy.} =
  Tagged[uint, LowerBits](raw: val or tag.uint)

proc untag*(tagged: Tagged[uint, LowerBits]): uint {.inline, nodestroy.} =
  tagged.raw and not 0b111'u

proc splitTag*(tagged: Tagged[uint, LowerBits]): LowerBits {.inline, nodestroy.} =
  LowerBits(tagged.raw and 0b111)

implUintPointerTags(LowerBits)

type LowerBitsTagged*[T] = Tagged[T, LowerBits]

proc tagLowerBits*[T](val: T, tag: LowerBitsImpl): LowerBitsTagged[T] {.inline.} =
  tag(val, LowerBits(tag))

template getTag*[T](tagged: LowerBitsTagged[T]): LowerBitsImpl =
  LowerBitsImpl(splitTag(tagged))
