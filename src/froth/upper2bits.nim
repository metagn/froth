import ./common

type
  Upper2BitsImpl* = range[0..3]
  Upper2Bits* = distinct Upper2BitsImpl
    ## shifts pointer 2 bits to the right, shifts 2 bit tag 62 bits to the left

const remainingBits = sizeof(int) * 8 - 2

proc tag*(val: uint, tag: Upper2Bits): Tagged[uint, Upper2Bits] {.inline, nodestroy.} =
  typeof(result)((val shr 2) or (tag.uint shl remainingBits))

proc untag*(tagged: Tagged[uint, Upper2Bits]): uint {.inline, nodestroy.} =
  uint(tagged) shl 2

proc splitTag*(tagged: Tagged[uint, Upper2Bits]): Upper2Bits {.inline, nodestroy.} =
  typeof(result)(uint(tagged) shr remainingBits)

implUintPointerTags(Upper2Bits)

type Upper2BitsTagged*[T] = Tagged[T, Upper2Bits]

proc tagUpper2Bits*[T](val: T, tag: Upper2BitsImpl): Upper2BitsTagged[T] {.inline.} =
  tag(val, Upper2Bits(tag))

template getTag*[T](tagged: Upper2BitsTagged[T]): Upper2BitsImpl =
  Upper2BitsImpl(splitTag(tagged))
