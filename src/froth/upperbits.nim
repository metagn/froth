import ./common

type
  UpperBitsImpl* = range[0..7]
  UpperBits* = distinct UpperBitsImpl
    ## shifts pointer 3 bits to the right, shifts 3 bit tag 61 bits to the left

const remainingBits = sizeof(int) * 8 - 3

proc tag*(val: uint, tag: UpperBits): Tagged[uint, UpperBits] {.inline, nodestroy.} =
  typeof(result)((val shr 3) or (tag.uint shl remainingBits))

proc untag*(tagged: Tagged[uint, UpperBits]): uint {.inline, nodestroy.} =
  uint(tagged) shl 3

proc splitTag*(tagged: Tagged[uint, UpperBits]): UpperBits {.inline, nodestroy.} =
  typeof(result)(uint(tagged) shr remainingBits)

implUintPointerTags(UpperBits)

type UpperBitsTagged*[T] = Tagged[T, UpperBits]

proc tagUpperBits*[T](val: T, tag: UpperBitsImpl): UpperBitsTagged[T] {.inline.} =
  tag(val, UpperBits(tag))

template getTag*[T](tagged: UpperBitsTagged[T]): UpperBitsImpl =
  UpperBitsImpl(splitTag(tagged))
