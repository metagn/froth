import std/typetraits

template implDestructors*(Name: untyped, doTagImpl, untagRawImpl, getTagImpl: untyped) =
  proc `=wasMoved`*[T](x: var Name[T]) {.nodestroy, inline.} =
    x = default(Name[T]) # cast[Name[T]](pointer(nil))

  when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
    proc `=destroy`*[T](x: Name[T]) {.nodestroy.} =
      mixin isPointer
      if isPointer(x):
        {.cast(raises: []).}:
          `=destroy`(cast[T](untagRawImpl(x)))
  else:
    {.push warning[Deprecated]: off.}
    proc `=destroy`*[T](x: var Name[T]) {.nodestroy.} =
      mixin isPointer
      if isPointer(x):
        x = cast[Name[T]](untagRawImpl(x))
        `=destroy`(cast[ptr T](addr x)[])
    {.pop.}

  proc `=copy`*[T](dest: var Name[T], src: Name[T]) {.nodestroy.} =
    when supportsCopyMem(T):
      dest = src
    else:
      mixin isPointer
      if isPointer(src):
        let t = getTagImpl(src)
        `=copy`(cast[ptr T](addr dest)[], cast[T](untagRawImpl(src)))
        dest = doTagImpl(cast[T](dest), t)
      else:
        dest = src

  proc `=sink`*[T](dest: var Name[T], src: Name[T]) {.nodestroy.} =
    when supportsCopyMem(T) or T is ref: # supportsMoveMem
      dest = src
    else:
      mixin isPointer
      if isPointer(x):
        let t = getTagImpl(src)
        `=sink`(cast[ptr T](addr dest)[], cast[T](untagRawImpl(src)))
        dest = doTagImpl(cast[T](dest), t)
      else:
        dest = src

  proc `=dup`*[T](x: Name[T]): Name[T] {.nodestroy.} =
    mixin isPointer
    if isPointer(x):
      let t = getTagImpl(x)
      let p = `=dup`(cast[T](untagRawImpl(x)))
      result = doTagImpl(p, t)
    else:
      result = x

  proc `=trace`*[T](x: var Name[T]; env: pointer) {.nodestroy.} =
    mixin isPointer
    if isPointer(x):
      let orig = cast[pointer](x)
      x = cast[Name[T]](untagRawImpl(x))
      `=trace`(cast[ptr T](addr x)[], env)
      x = cast[Name[T]](orig)
