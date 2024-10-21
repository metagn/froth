import std/typetraits

template implDestructors*(Name: untyped, doTagImpl, untagImpl, getTagImpl: untyped) =
  proc `=wasMoved`*[T](x: var Name[T]) {.nodestroy, inline.} =
    x = cast[Name[T]](pointer(nil))

  when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
    proc `=destroy`*[T](x: Name[T]) {.nodestroy.} =
      {.cast(raises: []).}:
        `=destroy`(untagImpl(x))
  else:
    {.push warning[Deprecated]: off.}
    proc `=destroy`*[T](x: var Name[T]) {.nodestroy.} =
      x = cast[Name[T]](untagImpl(x))
      `=destroy`(cast[ptr T](addr x)[])
    {.pop.}

  proc `=copy`*[T](dest: var Name[T], src: Name[T]) {.nodestroy.} =
    when supportsCopyMem(T):
      dest = src
    else:
      let t = getTagImpl(src)
      `=copy`(cast[ptr T](addr dest)[], untagImpl(src))
      dest = doTagImpl(cast[T](dest), t)

  proc `=sink`*[T](dest: var Name[T], src: Name[T]) {.nodestroy.} =
    when supportsCopyMem(T) or T is ref: # supportsMoveMem
      dest = src
    else:
      let t = getTagImpl(src)
      `=sink`(cast[ptr T](addr dest)[], untagImpl(src))
      dest = doTagImpl(cast[T](dest), t)

  proc `=dup`*[T](x: Name[T]): Name[T] {.nodestroy.} =
    let t = getTagImpl(x)
    let p = `=dup`(untagImpl(x))
    result = doTagImpl(p, t)

  proc `=trace`*[T](x: var Name[T]; env: pointer) {.nodestroy.} =
    let orig = cast[pointer](x)
    x = cast[Name[T]](untagImpl(x))
    `=trace`(cast[ptr T](addr x)[], env)
    x = cast[Name[T]](orig)
