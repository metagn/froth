import ./common

type
  UpperBitsImpl* = range[0..7]
  UpperBits* = distinct UpperBitsImpl
    ## shifts pointer 3 bits to the right, shifts 3 bit tag 61 bits to the left

const remainingBits = sizeof(int) * 8 - 3

template tagInline*(val: uint, tag: UpperBits): Tagged[uint, UpperBits] =
  rawTagged[uint, UpperBits]((val shr 3) or (tag.uint shl remainingBits))

template untagInline*(tagged: Tagged[uint, UpperBits]): uint =
  tagged.rawValue shl 3

template splitTagInline*(tagged: Tagged[uint, UpperBits]): UpperBits =
  UpperBits(tagged.rawValue shr remainingBits)

proc tag*(val: uint, tag: UpperBits): Tagged[uint, UpperBits] {.inline.} = tagInline(val, tag)
proc untag*(tagged: Tagged[uint, UpperBits]): uint {.inline.} = untagInline(tagged)
proc splitTag*(tagged: Tagged[uint, UpperBits]): UpperBits {.inline.} = splitTagInline(tagged)

implUintPointerTags(UpperBits)

type UpperBitsTagged*[T] = Tagged[T, UpperBits]

proc tagUpperBits*[T](val: T, tag: UpperBitsImpl): UpperBitsTagged[T] {.inline.} =
  tag(val, UpperBits(tag))

template getTag*[T](tagged: UpperBitsTagged[T]): UpperBitsImpl =
  UpperBitsImpl(splitTag(tagged))
