import std/typetraits

const frothUseBytes* {.booldefine.} = defined(gcRefc) and (NimMajor, NimMinor) >= (2, 3)
  # breaks with forward types except in devel
const frothUsePointer* {.booldefine.} = defined(gcRefc)

type RawBytes[T] {.used.} = array[sizeof(T), byte]

when frothUseBytes:
  type Tagged*[T, Tag] = object
    rawBytes*: RawBytes[T]

  template raw*[T, Tag](x: Tagged[T, Tag]): T =
    cast[T](x.rawBytes)
  template rawMut*[T, Tag](x: var Tagged[T, Tag]): T =
    cast[ptr T](addr x.rawBytes)[]
  template setRaw*[T, Tag](x: var Tagged[T, Tag], val: T) =
    x.rawBytes = cast[RawBytes[T]](val)
  template rawTagged*[T, Tag](x: T): Tagged[T, Tag] =
    Tagged[T, Tag](rawBytes: cast[RawBytes[T]](x))
elif frothUsePointer:
  type Tagged*[T, Tag] = object
    rawPointer*: pointer

  template raw*[T, Tag](x: Tagged[T, Tag]): T =
    cast[T](x.rawPointer)
  template rawMut*[T, Tag](x: var Tagged[T, Tag]): T =
    cast[ptr T](addr x.rawPointer)[]
  template setRaw*[T, Tag](x: var Tagged[T, Tag], val: T) =
    x.rawPointer = cast[pointer](val)
  template rawTagged*[T, Tag](x: T): Tagged[T, Tag] =
    Tagged[T, Tag](rawPointer: cast[pointer](x))
else:
  type Tagged*[T, Tag] = object
    # object rather than distinct for destructors to work (`=dup` disagrees on cyclic parameter)
    rawValue*: T
      # cant use this on refc, nim compiler always tries to run `unsureAsgnRef` on it

  template raw*[T, Tag](x: Tagged[T, Tag]): T =
    x.rawValue
  template rawMut*[T, Tag](x: var Tagged[T, Tag]): T =
    x.rawValue
  template setRaw*[T, Tag](x: var Tagged[T, Tag], val: T) =
    when false:
      cast[ptr RawBytes[T]](addr x.rawValue)[] = cast[RawBytes[T]](val)
    else:
      x.rawValue = val
  template rawTagged*[T, Tag](x: T): Tagged[T, Tag] =
    Tagged[T, Tag](rawValue: x)

# tag types need to implement withTagInline/splitTagInline/untagInline as templates,
# procs with inline + nodestroy infinitely recurse on orc for some reason
# XXX destructors do not call destructors for the tag, maybe document

proc `=wasMoved`*[T, Tag](x: var Tagged[T, Tag]) {.nodestroy, inline.} =
  when frothUseBytes:
    x.rawBytes = default(RawBytes[T])
  elif frothUsePointer:
    x.rawPointer = pointer(nil)
  else:
    `=wasMoved`(x.rawValue)

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
    `=destroy`(x.rawMut)
  {.pop.}

proc `=dup`*[T, Tag](x: Tagged[T, Tag]): Tagged[T, Tag] {.nodestroy.} =
  mixin splitTagInline, untagInline, withTagInline
  when supportsCopyMem(T):
    result = x
  else:
    let t = splitTagInline(x)
    let p = `=dup`(untagInline(x))
    result = withTagInline(p, t)

proc `=copy`*[T, Tag](dest: var Tagged[T, Tag], src: Tagged[T, Tag]) {.nodestroy.} =
  when supportsCopyMem(T):
    dest = src
  else:
    when false: # https://github.com/nim-lang/Nim/issues/25730
      let t = splitTagInline(src)
      `=copy`(dest.rawMut, untagInline(src))
      dest = withTagInline(dest.raw, t)
    else:
      dest = `=dup`(src)

proc `=sink`*[T, Tag](dest: var Tagged[T, Tag], src: Tagged[T, Tag]) {.nodestroy.} =
  when supportsCopyMem(T) or T is ref: # supportsMoveMem
    dest = src
  else:
    let t = splitTagInline(src)
    `=sink`(dest.rawMut, untagInline(src))
    dest = withTagInline(dest.raw, t)

proc `=trace`*[T, Tag](x: var Tagged[T, Tag]; env: pointer) {.nodestroy.} =
  mixin splitTagInline, untagInline, withTagInline
  when frothUseBytes:
    let orig = x.rawBytes
    x.rawBytes = cast[RawBytes[T]](untagInline(x))
    `=trace`(cast[ptr T](addr x.rawBytes)[], env)
    x.rawBytes = orig
  elif frothUsePointer:
    let orig = x.rawPointer
    x.rawPointer = cast[pointer](untagInline(x))
    `=trace`(cast[ptr T](addr x.rawPointer)[], env)
    x.rawPointer = orig
  else:
    let orig = x.rawValue
    x.rawValue = untagInline(x)
    `=trace`(x.rawValue, env)
    x.rawValue = orig

# XXX in place procs, setTag and removeTag

when false:
  type SomeTag*[T] = concept
    # does not seem to work due to nim bug, saying cannot instantiate Tagged
    # or my version is old
    proc withTag(val: T, tag: Self): Tagged[uint, Self]
    proc untag(tagged: Tagged[T, Self]): T
    proc splitTag(tagged: Tagged[T, Self]): Self

type PointerLike* = auto
  ## anything that can be cast to `pointer`
  ## not restricted for now since it can break with forwarded `ref` types

template implUintPointerTags*(UintTag: untyped; splitTagVar = false) {.dirty.} =
  # both proc and proc param named `tag` crashed the compiler due to being an ident in a symchoice
  # dirty prevents crash just in case
  mixin withTagInline, untagInline, splitTagInline
  template withTagInline*[T: PointerLike](val: T, t: UintTag): Tagged[T, UintTag] =
    cast[Tagged[T, UintTag]](withTagInline(cast[uint](val), t))
  template untagInline*[T: PointerLike](tagged: Tagged[T, UintTag]): T =
    cast[T](untagInline(cast[Tagged[uint, UintTag]](tagged)))
  template splitTagInline*[T: PointerLike](tagged: Tagged[T, UintTag]): UintTag =
    splitTagInline(cast[Tagged[uint, UintTag]](tagged))
  when splitTagVar:
    template splitTagMutInline*[T: PointerLike](tagged: var Tagged[T, UintTag]): var UintTag =
      splitTagMutInline(cast[ptr Tagged[uint, UintTag]](addr tagged)[])
  proc withTag*[T: PointerLike](val: T, t: UintTag): Tagged[T, UintTag] {.inline.} =
    withTagInline(val, t)
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

