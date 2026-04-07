import std/typetraits

type
  Tagged*[T, Tag] = object
    # object rather than distinct for destructors to work (`=dup` disagrees on cyclic parameter)
    raw*: T

# XXX destructors do not call destructors for the tag, maybe document

proc `=wasMoved`*[T, Tag](x: var Tagged[T, Tag]) {.nodestroy, inline.} =
  `=wasMoved`(x.raw)

when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
  proc `=destroy`*[T, Tag](x: Tagged[T, Tag]) {.nodestroy.} =
    mixin untag
    when not supportsCopyMem(T):
      let p = untag(x)
      # no generic non-var destructor
      {.cast(raises: []).}:
        `=destroy`(p)
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*[T, Tag](x: var Tagged[T, Tag]) {.nodestroy.} =
    mixin untag
    #cast[ptr T](addr x)[] = untag(x)
    x.raw = untag(x)
    #`=destroy`(cast[ptr T](x)[])
    `=destroy`(x.raw)
  {.pop.}

proc `=copy`*[T, Tag](dest: var Tagged[T, Tag], src: Tagged[T, Tag]) {.nodestroy.} =
  when supportsCopyMem(T):
    dest = src
  else:
    let t = splitTag(src)
    `=copy`(dest.raw, untag(src))
    dest = tag(dest.raw, t)

proc `=sink`*[T, Tag](dest: var Tagged[T, Tag], src: Tagged[T, Tag]) {.nodestroy.} =
  when supportsCopyMem(T) or T is ref: # supportsMoveMem
    dest = src
  else:
    let t = splitTag(src)
    `=sink`(dest.raw, untag(src))
    dest = tag(dest.raw, t)

proc `=dup`*[T, Tag](x: Tagged[T, Tag]): Tagged[T, Tag] {.nodestroy.} =
  mixin splitTag, untag, tag
  let t = splitTag(x)
  let p = `=dup`(untag(x))
  result = tag(p, t)

proc `=trace`*[T, Tag](x: var Tagged[T, Tag]; env: pointer) {.nodestroy.} =
  mixin splitTag, untag, tag
  when false:
    let orig = cast[pointer](x)
    x = cast[Tagged[T, Tag]](untagImpl(x))
    `=trace`(cast[ptr T](addr x)[], env)
    x = cast[Tagged[T, Tag]](orig)
  elif true:
    let orig = x.raw
    x.raw = untag(x)
    `=trace`(x.raw, env)
    x.raw = orig
  elif false:
    let t = splitTag(x)
    x.raw = untag(x)
    `=trace`(x.raw, env)
    x = tag(x.raw, t)

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
  mixin tag, untag, splitTag
  proc tag*[T: PointerLike](val: T, tag: UintTag): Tagged[T, UintTag] {.inline, nodestroy.} =
    cast[Tagged[T, UintTag]](tag(cast[uint](val), tag))
  proc untag*[T: PointerLike](tagged: Tagged[T, UintTag]): T {.inline, nodestroy.} =
    cast[T](untag(cast[Tagged[uint, UintTag]](tagged)))
  proc splitTag*[T: PointerLike](tagged: Tagged[T, UintTag]): UintTag {.inline, nodestroy.} =
    splitTag(cast[Tagged[uint, UintTag]](tagged))
  when splitTagVar:
    proc splitTagMut*[T: PointerLike](tagged: var Tagged[T, UintTag]): var UintTag {.inline, nodestroy.} =
      splitTagMut(cast[ptr Tagged[uint, UintTag]](addr tagged)[])
  template isNil*[T: PointerLike](tagged: Tagged[T, UintTag]): bool =
    tagged.untag.isNil
  template `[]`*[T: PointerLike](tagged: Tagged[T, UintTag]): untyped =
    tagged.untag[]

