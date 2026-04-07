import std/typetraits

const isBytes = defined(gcRefc) and true
  # breaks with forward types except in devel
const isPointer = defined(gcRefc) and true

type RawBytes[T] {.used.} = array[sizeof(T), byte]

when isBytes:
  type Tagged*[T, Tag] = object
    rawBytes*: RawBytes[T]

  template rawValue*[T, Tag](x: Tagged[T, Tag]): T =
    cast[T](x.rawBytes)
  template rawValueMut*[T, Tag](x: var Tagged[T, Tag]): T =
    cast[ptr T](addr x.rawBytes)[]
  template setRaw*[T, Tag](x: var Tagged[T, Tag], val: T) =
    x.rawBytes = cast[RawBytes[T]](val)
  template rawTagged*[T, Tag](x: T): Tagged[T, Tag] =
    Tagged[T, Tag](rawBytes: cast[RawBytes[T]](x))
elif isPointer:
  type Tagged*[T, Tag] = object
    rawPointer*: pointer

  template rawValue*[T, Tag](x: Tagged[T, Tag]): T =
    cast[T](x.rawPointer)
  template rawValueMut*[T, Tag](x: var Tagged[T, Tag]): T =
    cast[ptr T](addr x.rawPointer)[]
  template setRaw*[T, Tag](x: var Tagged[T, Tag], val: T) =
    x.rawPointer = cast[pointer](val)
  template rawTagged*[T, Tag](x: T): Tagged[T, Tag] =
    Tagged[T, Tag](rawPointer: cast[pointer](x))
else:
  type Tagged*[T, Tag] = object
    # object rather than distinct for destructors to work (`=dup` disagrees on cyclic parameter)
    raw*: T

  template rawValue*[T, Tag](x: Tagged[T, Tag]): T =
    x.raw
  template rawValueMut*[T, Tag](x: var Tagged[T, Tag]): T =
    x.raw
  template setRaw*[T, Tag](x: var Tagged[T, Tag], val: T) =
    when false:
      cast[ptr RawBytes[T]](addr x.raw)[] = cast[RawBytes[T]](val)
    else:
      x.raw = val
  template rawTagged*[T, Tag](x: T): Tagged[T, Tag] =
    Tagged[T, Tag](raw: x)

# tag types need to implement tagInline/splitTagInline/untagInline as templates,
# procs with inline + nodestroy infinitely recurse on orc for some reason
# XXX destructors do not call destructors for the tag, maybe document

proc `=wasMoved`*[T, Tag](x: var Tagged[T, Tag]) {.nodestroy, inline.} =
  when isBytes:
    x.rawBytes = default(RawBytes[T])#pointer(nil)
  elif isPointer:
    x.rawPointer = pointer(nil)
  else:
    `=wasMoved`(x.raw)

when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
  proc `=destroy`*[T, Tag](x: Tagged[T, Tag]) {.nodestroy.} =
    mixin untagInline
    when not supportsCopyMem(T):
      let p = untagInline(x)
      # no generic non-var destructor
      {.cast(raises: []).}:
        `=destroy`(p)
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*[T, Tag](x: var Tagged[T, Tag]) {.nodestroy.} =
    mixin untagInline
    x.setRaw untagInline(x)
    `=destroy`(x.rawValueMut)
    #cast[ptr T](addr x)[] = untag(x)
    #`=destroy`(cast[ptr T](x)[])
  {.pop.}

proc `=copy`*[T, Tag](dest: var Tagged[T, Tag], src: Tagged[T, Tag]) {.nodestroy.} =
  when supportsCopyMem(T):
    dest = src
  else:
    let t = splitTagInline(src)
    `=copy`(dest.rawValueMut, untagInline(src))
    dest = tagInline(dest.rawValue, t)

proc `=sink`*[T, Tag](dest: var Tagged[T, Tag], src: Tagged[T, Tag]) {.nodestroy.} =
  when supportsCopyMem(T) or T is ref: # supportsMoveMem
    dest = src
  else:
    let t = splitTagInline(src)
    `=sink`(dest.rawValueMut, untagInline(src))
    dest = tagInline(dest.rawValue, t)

proc `=dup`*[T, Tag](x: Tagged[T, Tag]): Tagged[T, Tag] {.nodestroy.} =
  mixin splitTagInline, untagInline, tagInline
  when supportsCopyMem(T):
    result = x
  elif defined(gcRefc):
    let t = splitTagInline(x)
    `=copy`(result.rawValueMut, untagInline(x))
    result = tagInline(result.rawValue, t)
  else:
    let t = splitTagInline(x)
    let p = `=dup`(untagInline(x))
    result = tagInline(p, t)

proc `=trace`*[T, Tag](x: var Tagged[T, Tag]; env: pointer) {.nodestroy.} =
  mixin splitTagInline, untagInline, tagInline
  when isBytes:
    let orig = x.rawBytes
    x.rawBytes = cast[RawBytes[T]](untagInline(x))
    `=trace`(cast[ptr T](addr x.rawBytes)[], env)
    x.rawBytes = orig
  elif isPointer:
    let orig = x.rawPointer
    x.rawPointer = cast[pointer](untagInline(x))
    `=trace`(cast[ptr T](addr x.rawPointer)[], env)
    x.rawPointer = orig
  else:
    let orig = x.raw
    x.raw = untagInline(x)
    `=trace`(x.raw, env)
    x.raw = orig

when false:
  type SomeTag*[T] = concept
    # does not seem to work due to nim bug, saying cannot instantiate Tagged
    # or my version is old
    proc tag(val: T, tag: Self): Tagged[uint, Self]
      # XXX maybe rename to withTag or something, and in place setTag
    proc untag(tagged: Tagged[T, Self]): T
    proc splitTag(tagged: Tagged[T, Self]): Self

type PointerLike* = auto
  ## anything that can be cast to `pointer`
  ## not restricted for now so forward types can work
  # ^ ???

template implUintPointerTags*(UintTag: untyped; splitTagVar = false) {.dirty.} =
  # XXX "tag`gensym0" crashes compiler due to being an ident in a symchoice, so dirty
  mixin tagInline, untagInline, splitTagInline
  template tagInline*[T: PointerLike](val: T, t: UintTag): Tagged[T, UintTag] =
    cast[Tagged[T, UintTag]](tagInline(cast[uint](val), t))
  template untagInline*[T: PointerLike](tagged: Tagged[T, UintTag]): T =
    cast[T](untagInline(cast[Tagged[uint, UintTag]](tagged)))
  template splitTagInline*[T: PointerLike](tagged: Tagged[T, UintTag]): UintTag =
    splitTagInline(cast[Tagged[uint, UintTag]](tagged))
  when splitTagVar:
    template splitTagMutInline*[T: PointerLike](tagged: var Tagged[T, UintTag]): var UintTag =
      splitTagMutInline(cast[ptr Tagged[uint, UintTag]](addr tagged)[])
  proc tag*[T: PointerLike](val: T, t: UintTag): Tagged[T, UintTag] {.inline.} =
    tagInline(val, t)
  proc untag*[T: PointerLike](tagged: Tagged[T, UintTag]): T {.inline.} =
    untagInline(tagged)
  proc splitTag*[T: PointerLike](tagged: Tagged[T, UintTag]): UintTag {.inline.} =
    splitTagInline(tagged)
  when splitTagVar:
    proc splitTagMut*[T: PointerLike](tagged: var Tagged[T, UintTag]): var UintTag =
      splitTagMutInline(tagged)
  template isNil*[T: PointerLike](tagged: Tagged[T, UintTag]): bool =
    tagged.untag.isNil
  template `[]`*[T: PointerLike](tagged: Tagged[T, UintTag]): untyped =
    tagged.untag[]

