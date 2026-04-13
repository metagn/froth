import common, std/[macros, typetraits]

type CondensateFieldKind* = enum
  CondensateTag, CondensateValue

proc findCase(obj: NimNode): NimNode =
  case obj.kind
  of nnkRecList:
    for o in obj:
      let recCase = findCase(o)
      if not recCase.isNil:
        if result.isNil:
          result = recCase
        else:
          error "multiple object variants not supported for condensate", recCase
  of nnkRecCase:
    result = obj
  of nnkIdentDefs, nnkSym:
    error "standalone field not supported for condensate", obj
  of nnkRecWhen:
    error "when not supported for condensate", obj
  of nnkDiscardStmt, nnkEmpty, nnkNilLit: result = nil
  else:
    error "invalid object ast " & $obj.kind, obj

proc findBranchField(obj: NimNode): NimNode =
  case obj.kind
  of nnkRecList:
    for o in obj:
      let field = findCase(o)
      if not field.isNil:
        if result.isNil:
          result = field
        else:
          error "multiple fields not supported for condensate branch", field
  of nnkSym:
    result = obj
  of nnkIdentDefs:
    if obj.len > 3:
      error "multiple fields not supported for condensate branch", obj
    result = obj
  of nnkRecCase:
    error "nested case not supported for condensate branch", obj
  of nnkRecWhen:
    error "when not supported for condensate branch", obj
  of nnkDiscardStmt, nnkEmpty, nnkNilLit: result = nil
  else:
    error "invalid object ast " & $obj.kind, obj

type
  FieldSourceKind = enum
    FromTagged, FromSource

proc condensateFieldIter(t: NimNode, kind: FieldSourceKind, source: NimNode, onTag, onValue: NimNode): NimNode =
  var t = t
  var recCase: NimNode = nil
  while t != nil:
    var impl = getTypeImpl(t)
    while true:
      if impl.kind in {nnkRefTy, nnkPtrTy, nnkVarTy, nnkOutTy}:
        if impl[^1].kind == nnkObjectTy:
          impl = impl[^1]
        else:
          impl = getTypeImpl(impl[^1])
      elif impl.kind == nnkBracketExpr and impl[0].eqIdent"typeDesc":
        impl = getTypeImpl(impl[1])
      elif impl.kind == nnkBracketExpr and impl[0].kind == nnkSym:
        impl = getImpl(impl[0])[^1]
      elif impl.kind == nnkSym:
        impl = getImpl(impl)[^1]
      else:
        break
    case impl.kind
    of nnkObjectTy:
      let found = findCase(impl[^1])
      if recCase.isNil:
        recCase = found
      else:
        error "multiple object variants not supported for condensate", found
      t = nil
      if impl[1].kind != nnkEmpty:
        expectKind impl[1], nnkOfInherit
        t = impl[1][0]
    else:
      error "got unknown object type kind " & $impl.kind, impl
  if recCase.isNil:
    error "no object variant found for condensate", t
  let tagField = recCase[0]
  var
    tagFieldName: NimNode = nil
    tagConvType: NimNode = nil
  if tagField.kind == nnkIdentDefs:
    tagFieldName = tagField[0]
    if tagFieldName.kind == nnkPragmaExpr: tagFieldName = tagFieldName[0]
    if tagFieldName.kind == nnkPostfix: tagFieldName = tagFieldName[1]
    tagConvType = tagField[1]
  else:
    expectKind tagField, nnkSym
    tagFieldName = tagField
    tagConvType = getTypeInst(tagField)
  #tagConvType = newCall(ident"type", tagConvType)
  let fieldsTag = genSym(nskLet, "condensateFieldsTag")
  result = newStmtList()
  result.add newTree(nnkLetSection,
    newTree(nnkIdentDefs,
      fieldsTag, #newTree(nnkPragmaExpr, fieldsTag, newTree(nnkPragma, ident"cursor")),
      newEmptyNode(),
      case kind
      of FromTagged:
        newCall(tagConvType, newCall(ident"splitTagInline", source))
      of FromSource:
        newDotExpr(source, tagFieldName)))
  result.add newCall(onTag,
    fieldsTag,
    newCall(ident"typeof", fieldsTag),
    tagFieldName)
  var fieldsCase = newNimNode(nnkCaseStmt, recCase)
  fieldsCase.add(fieldsTag)
  for b in 1 ..< recCase.len:
    let origBranch = recCase[b]
    var newBranch = newNimNode(origBranch.kind, origBranch)
    for i in 0 ..< origBranch.len - 1:
      newBranch.add origBranch[i]
    let branchField = findBranchField(origBranch[^1])
    if branchField.isNil:
      newBranch.add newTree(nnkDiscardStmt, newEmptyNode())
    else:
      var
        fieldName: NimNode = nil
        fieldType: NimNode = nil
      if branchField.kind == nnkSym:
        fieldName = branchField
        fieldType = getTypeInst(branchField)
      else:
        assert branchField.kind == nnkIdentDefs
        fieldName = branchField[0]
        if fieldName.kind == nnkPragmaExpr: fieldName = fieldName[0]
        if fieldName.kind == nnkPostfix: fieldName = fieldName[1]
        fieldType = branchField[1]
      #fieldType = newCall(ident"type", fieldType)
      let field = genSym(nskLet, "condensateFields_" & $fieldName)
      var branchStmts = newStmtList()
      branchStmts.add newTree(nnkLetSection,
        newTree(nnkIdentDefs,
          field, #newTree(nnkPragmaExpr, field, newTree(nnkPragma, ident"cursor")),
          newEmptyNode(),
          case kind
          of FromTagged:
            newTree(nnkCast, fieldType, newCall(ident"untagInline", source))
          of FromSource:
            newDotExpr(source, fieldName)))
      branchStmts.add newCall(onValue,
        field,
        newCall(ident"typeof", field),
        fieldName)
      newBranch.add branchStmts
    fieldsCase.add newBranch
  result.add fieldsCase
  #echo result.repr

macro condensateFields[T: object, Base: Tagged](t: typedesc[T], tagged: Base, onTag, onValue: untyped) =
  result = condensateFieldIter(t, FromTagged, tagged, onTag, onValue)

macro condensateFields[T: object](t: typedesc[T], source: T, onTag, onValue: untyped) =
  result = condensateFieldIter(t, FromSource, source, onTag, onValue)

type Condensate*[T; Base: Tagged] = object
  inner: Base

proc `=wasMoved`*[T, Base](x: var Condensate[T, Base]) =
  `=wasMoved`(x.inner)

when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
  proc `=destroy`*[T, Base](x: Condensate[T, Base]) {.nodestroy.}
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*[T, Base](x: var Condensate[T, Base]) {.nodestroy.}
  {.pop.}
proc `=copy`*[T, Base](dest: var Condensate[T, Base], src: Condensate[T, Base]) {.nodestroy.}
proc `=sink`*[T, Base](dest: var Condensate[T, Base], src: Condensate[T, Base]) {.nodestroy.}
proc `=dup`*[T, Base](x: Condensate[T, Base]): Condensate[T, Base] {.nodestroy.}
proc `=trace`*[T, Base](x: var Condensate[T, Base]; env: pointer) {.nodestroy.}

when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
  proc `=destroy`*[T, Base](x: Condensate[T, Base]) {.nodestroy.} =
    bind supportsCopyMem
    template destroyIter(field, typ, _) =
      when not supportsCopyMem(typ):
        # no generic non-var destructor
        {.cast(raises: []).}:
          `=destroy`(field)
    condensateFields(T, x.inner, destroyIter, destroyIter)
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*[T, Base](x: var Condensate[T, Base]) {.nodestroy.} =
    bind supportsCopyMem
    template destroyTagIter(field, typ, _) =
      when not supportsCopyMem(typ):
        # probably wont be effective anyway
        var tagVal = field
        `=destroy`(tagVal)
    template destroyValueIter(field, typ, _) =
      when not supportsCopyMem(typ):
        x = cast[typeof(x)](field)
        `=destroy`(cast[ptr typ](addr x)[])
    condensateFields(T, x.inner, destroyTagIter, destroyValueIter)
  {.pop.}

template condensateInline*[T; Base, Tag](_: typedesc[T], tag: Tag, base: Base): Condensate[T, Tagged[Base, Tag]] =
  mixin withTagInline
  Condensate[T, Tagged[Base, Tag]](
    inner: withTagInline(base, tag))

proc `=copy`*[T, Base](dest: var Condensate[T, Base], src: Condensate[T, Base]) {.nodestroy.} =
  template copyTagIter(field, typ, _) {.dirty.} =
    let t {.inject.} = cast[Base.Tag](field)
    dest = condensateInline(T, t, default(Base.T))
  template copyValueIter(field, typ, _) {.dirty.} =
    var val {.inject.}: typ
    when false: # https://github.com/nim-lang/Nim/issues/25730
      `=copy`(val, field)
    else:
      val = `=dup`(field)
    dest = condensateInline(T, t, cast[Base.T](val))
  condensateFields(T, src.inner, copyTagIter, copyValueIter)

proc `=sink`*[T, Base](dest: var Condensate[T, Base], src: Condensate[T, Base]) #[{.nodestroy.}]# =
  template sinkTagIter(field, typ, _) {.dirty.} =
    let t {.inject.} = cast[Base.Tag](field)
    dest = condensateInline(T, t, default(Base.T))
  template sinkValueIter(field, typ, _) {.dirty.} =
    var val {.inject.}: typ
    `=sink`(val, field)
    dest = condensateInline(T, t, cast[Base.T](val))
  condensateFields(T, src.inner, sinkTagIter, sinkValueIter)

proc `=dup`*[T, Base](x: Condensate[T, Base]): Condensate[T, Base] {.nodestroy.} =
  template dupTagIter(field, typ, _) {.dirty.} =
    let t {.inject.} = cast[Base.Tag](field)
    result = condensateInline(T, t, default(Base.T))
  template dupValueIter(field, typ, _) {.dirty.} =
    let val {.inject.} = `=dup`(field)
    result = condensateInline(T, t, cast[Base.T](val))
  condensateFields(T, x.inner, dupTagIter, dupValueIter)

proc `=trace`*[T, Base](x: var Condensate[T, Base]; env: pointer) {.nodestroy.} =
  let orig = x
  template traceTagIter(field, typ, _) {.dirty.} =
    var t = field
    `=trace`(t, env)
  template traceValueIter(field, typ, _) {.dirty.} =
    x = cast[typeof(x)](field)
    #cast[ptr typ](addr x)[] = field
    `=trace`(cast[ptr typ](addr x)[], env)
  condensateFields(T, orig.inner, traceTagIter, traceValueIter)
  x = orig

proc condensate*[T; Base, Tag](x: T, _: typedesc[Tagged[Base, Tag]]): Condensate[T, Tagged[Base, Tag]] {.inline, nodestroy.} =
  template constrTagIter(field, typ, _) {.dirty.} =
    let t = Tag(field)
    result = condensateInline(T, t, default(Base))
  template constrValueIter(field, typ, _) {.dirty.} =
    result = condensateInline(T, t, cast[Base](`=dup`(field)))
  condensateFields(T, x, constrTagIter, constrValueIter)

proc decondense*[T; Base, Tag](x: Condensate[T, Tagged[Base, Tag]]): T {.inline, nodestroy.} =
  template decondTagIter(field, typ, fieldName) {.dirty.} =
    result = T(`fieldName`: field)
  template decondValueIter(field, typ, fieldName) {.dirty.} =
    result.`fieldName` = `=dup`(field)
  condensateFields(T, x.inner, decondTagIter, decondValueIter)

template rawCondensate*[T; Base, Tag](t: typedesc[Condensate[T, Tagged[Base, Tag]]], tag: Tag, base: Base): t =
  condensateInline(T, tag, base)

template rawTag*[T; Base, Tag](val: Condensate[T, Tagged[Base, Tag]]): Tag =
  splitTagInline(val.inner)

template rawDecondense*[T; Base, Tag; V](val: Condensate[T, Tagged[Base, Tag]], _: typedesc[V]): V =
  cast[V](untagInline(val.inner))
