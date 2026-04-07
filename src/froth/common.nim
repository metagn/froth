import std/typetraits

type
  Tagged*[T, Tag] = distinct T
    # XXX maybe object if destructors dont work

# XXX destructors do not call destructors for the tag, maybe document

proc `=wasMoved`*[T, Tag](x: var Tagged[T, Tag]) {.nodestroy, inline.} =
  `=wasMoved`(T(x))

when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
  proc `=destroy`*[T, Tag](x: Tagged[T, Tag]) {.nodestroy.} =
    mixin untag
    when not supportsCopyMem(T):
      # no generic non-var destructor
      {.cast(raises: []).}:
        `=destroy`(untag(x))
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*[T, Tag](x: var Tagged[T, Tag]) {.nodestroy.} =
    mixin untag
    #cast[ptr T](addr x)[] = untag(x)
    x = Tagged[T, Tag](untag(x))
    #`=destroy`(cast[ptr T](x)[])
    `=destroy`(T(x))
  {.pop.}

proc `=copy`*[T, Tag](dest: var Tagged[T, Tag], src: Tagged[T, Tag]) {.nodestroy.} =
  when supportsCopyMem(T):
    dest = src
  else:
    let t = splitTag(src)
    `=copy`(T(dest), untag(src))
    dest = tag(T(dest), t)

proc `=sink`*[T, Tag](dest: var Tagged[T, Tag], src: Tagged[T, Tag]) {.nodestroy.} =
  when supportsCopyMem(T) or T is ref: # supportsMoveMem
    dest = src
  else:
    let t = splitTag(src)
    `=sink`(T(dest), untag(src))
    dest = tag(T(dest), t)

proc `=dup`*[T, Tag](x: Tagged[T, Tag]): Tagged[T, Tag] {.nodestroy.} =
  mixin splitTag, untag, tag
  let t = splitTag(x)
  let p = `=dup`(untag(x))
  result = tag(p, t)

proc `=trace`*[T, Tag](x: var Tagged[T, Tag]; env: pointer) {.nodestroy.} =
  mixin untag
  when false:
    let orig = cast[pointer](x)
    x = cast[Tagged[T, Tag]](untagImpl(x))
    `=trace`(cast[ptr T](addr x)[], env)
    x = cast[Tagged[T, Tag]](orig)
  let orig = x
  x = Tagged[T, Tag](untag(x))
  `=trace`(T(x), env)
  x = orig

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
  # XXX "tag`gensym0" crashes compiler due to being an ident in a symchoice
  mixin tag, untag, splitTag
  proc tag*[T: PointerLike](val: T, tag: UintTag): Tagged[T, UintTag] {.inline.} =
    cast[Tagged[T, UintTag]](tag(cast[uint](val), tag))
  proc untag*[T: PointerLike](tagged: Tagged[T, UintTag]): T {.inline.} =
    cast[T](untag(cast[Tagged[uint, UintTag]](tagged)))
  proc splitTag*[T: PointerLike](tagged: Tagged[T, UintTag]): UintTag {.inline.} =
    splitTag(cast[Tagged[uint, UintTag]](tagged))
  when splitTagVar:
    proc splitTag*[T: PointerLike](tagged: var Tagged[T, UintTag]): var UintTag {.inline.} =
      splitTag(cast[ptr Tagged[uint, UintTag]](addr tagged)[])
  template isNil*[T: PointerLike](tagged: Tagged[T, UintTag]): bool =
    tagged.untag.isNil
  template `[]`*[T: PointerLike](tagged: Tagged[T, UintTag]): untyped =
    tagged.untag[]

