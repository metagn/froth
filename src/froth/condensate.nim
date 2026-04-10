import common, std/[macros, strutils, typetraits]

type CondensateFieldKind* = enum
  CondensateTag, CondensateValue

template implementCondensateDestructorsImpl(T: untyped) {.dirty.} =
  bind distinctBase, supportsCopyMem
  proc `=wasMoved`*(x: var T) {.nodestroy, inline.}
  when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
    proc `=destroy`*(x: T) {.nodestroy.}
  else:
    {.push warning[Deprecated]: off.}
    proc `=destroy`*(x: var T) {.nodestroy.}
    {.pop.}
  proc `=copy`*(dest: var T, src: T) {.nodestroy.}
  proc `=sink`*(dest: var T, src: T) {.nodestroy.}
  proc `=dup`*(x: T): T {.nodestroy.}
  proc `=trace`*(x: var T; env: pointer) {.nodestroy.}

  proc `=wasMoved`*(x: var T) {.nodestroy, inline.} =
    `=wasMoved`(x.inner)

  when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
    proc `=destroy`*(x: T) {.nodestroy.} =
      template destroyIter(field, typ, _, _) =
        when not supportsCopyMem(typ):
          # no generic non-var destructor
          {.cast(raises: []).}:
            `=destroy`(field)
      condensateFields(x, destroyIter)
  else:
    {.push warning[Deprecated]: off.}
    proc `=destroy`*(x: var T) {.nodestroy.} =
      template destroyIter(field, typ, fieldKind, _) =
        when fieldKind == CondensateTag:
          when not supportsCopyMem(typ):
            # probably wont be effective anyway
            var tagVal = field
            `=destroy`(tagVal)
        elif fieldKind == CondensateValue:
          when not supportsCopyMem(typ):
            x = cast[T](field)
            `=destroy`(cast[ptr typ](addr x)[])
      condensateFields(x, destroyIter)
    {.pop.}

  proc `=copy`*(dest: var T, src: T) {.nodestroy.} =
    template copyIter(field, typ, fieldKind, _) {.dirty.} =
      when fieldKind == CondensateTag:
        let t {.inject.} = field
        dest = initCondensate(t)
      elif fieldKind == CondensateValue:
        var val {.inject.}: typ
        when false: # https://github.com/nim-lang/Nim/issues/25730
          `=copy`(val, field)
        else:
          val = `=dup`(field)
        dest = initCondensate(t, cast[condensateBase(T)](val))
    condensateFields(src, copyIter)

  proc `=sink`*(dest: var T, src: T) #[{.nodestroy.}]# =
    template sinkIter(field, typ, fieldKind, _) {.dirty.} =
      when fieldKind == CondensateTag:
        let t {.inject.} = field
        dest = initCondensate(t)
      elif fieldKind == CondensateValue:
        var val {.inject.}: typ
        `=sink`(val, field)
        dest = initCondensate(t, cast[condensateBase(T)](val))
    condensateFields(src, sinkIter)

  proc `=dup`*(x: T): T {.nodestroy.} =
    template dupIter(field, typ, fieldKind, _) {.dirty.} =
      when fieldKind == CondensateTag:
        let t {.inject.} = field
        result = initCondensate(t)
      elif fieldKind == CondensateValue:
        let val {.inject.} = `=dup`(field)
        result = initCondensate(t, cast[condensateBase(T)](val))
    condensateFields(x, dupIter)

  proc `=trace`*(x: var T; env: pointer) {.nodestroy.} =
    let orig = x
    template traceIter(field, typ, fieldKind, _) {.dirty.} =
      when fieldKind == CondensateTag:
        var t = field
        `=trace`(t, env)
      elif fieldKind == CondensateValue:
        x = cast[T](field)
        #cast[ptr typ](addr x)[] = field
        `=trace`(cast[ptr typ](addr x)[], env)
    condensateFields(orig, traceIter)
    x = orig

proc condensateImpl(node: NimNode): tuple[typeSection, stmts: NimNode] =
  result.typeSection = newNimNode(nnkTypeSection, node)
  result.stmts = newNimNode(nnkStmtList, node)
  if node.kind in {nnkStmtList, nnkTypeSection}:
    for n in node:
      let res = condensateImpl(n)
      for td in res.typeSection:
        result.typeSection.add td
      result.stmts.add res.stmts
    return
  expectKind node, nnkTypeDef
  expectKind node[^1], nnkObjectTy
  expectKind node[^1][1], nnkOfInherit
  let tagBaseType = node[^1][1][0]
  expectKind node[^1][^1], nnkRecList
  if node[^1][^1].len != 1 or node[^1][^1][0].kind != nnkRecCase:
    error "only single case supported for now, no when", node[^1][^1]
  var typeName = node[0]
  if typeName.kind == nnkPragmaExpr: typeName = typeName[0]
  let typeIsExported = typeName.kind == nnkPostfix
  if typeIsExported: typeName = typeName[1]
  let recCase = node[^1][^1][0]
  # tag field:
  let tagField = recCase[0]
  var tagName = tagField[0]
  var tagPragmas: NimNode = nil
  if tagName.kind == nnkPragmaExpr:
    tagPragmas = tagName[1]
    tagName = tagName[0]
  else:
    tagPragmas = newEmptyNode()
  let tagNamePostfix = tagName
  let isTagExported = tagName.kind == nnkPostfix
  if isTagExported: tagName = tagName[1]
  let tagNameStr = $tagName
  let tagTypeNode = tagField[^2]
  let (tagType, tagConvType) =
    if tagTypeNode.kind == nnkInfix and tagTypeNode[0].eqIdent"of":
      (tagTypeNode[2], tagTypeNode[1])
    else:
      (tagTypeNode, nil)
  let tagDefault = tagField[^1]
  let fieldsObjName = ident repr genSym(nskParam, "condensateObj")
  let realType = newTree(nnkBracketExpr, bindSym"Tagged", tagBaseType, tagType)
  let realField = ident"inner"
  result.typeSection.add newTree(nnkTypeDef, node[0], node[1],
    #newTree(nnkDistinctTy, realType)
    newTree(nnkObjectTy, newEmptyNode(), newEmptyNode(), newTree(nnkRecList,
      newIdentDefs(realField, realType))))

  var tagNode = newCall(ident"splitTagInline", newDotExpr(fieldsObjName, realField))
  if not tagConvType.isNil: tagNode = newTree(nnkCast, tagConvType, tagNode)
  result.stmts.add newProc(
    procType = nnkTemplateDef,
    name = tagNamePostfix,
    params = [if tagConvType.isNil: tagType else: tagConvType,
      newIdentDefs(fieldsObjName, typeName)],
    pragmas = tagPragmas,
    body = tagNode
  )
  result.stmts.add newProc(
    procType = nnkTemplateDef,
    name = if isTagExported: newTree(nnkPostfix, ident"*", ident"condensateTag") else: ident"condensateTag",
    params = [if tagConvType.isNil: tagType else: tagConvType,
      newIdentDefs(fieldsObjName, typeName)],
    pragmas = newTree(nnkPragma, ident"used"),
    body = newCall(tagName, fieldsObjName)
  )
  result.stmts.add newProc(
    procType = nnkTemplateDef,
    name = if isTagExported: newTree(nnkPostfix, ident"*", ident"condensateBase") else: ident"condensateBase",
    params = [ident"untyped",
      newIdentDefs(ident"_", newTree(nnkBracketExpr, ident"typedesc", typeName))],
    pragmas = newTree(nnkPragma, ident"used"),
    body = tagBaseType
  )

  var convenienceProcs: seq[NimNode] = @[]

  # other fields:
  var branches: seq[tuple[originalBranch: NimNode, name: string, typ: NimNode]]
  for i in 1 ..< recCase.len:
    let branch = recCase[i]
    let branchFields = branch[^1]
    if branchFields.kind in {nnkDiscardStmt, nnkNilLit, nnkEmpty} or
        (branchFields.kind == nnkRecList and branchFields.len == 1 and
          branchFields[0].kind in {nnkDiscardStmt, nnkNilLit, nnkEmpty}):
      branches.add (branch, "", nil)
      continue
    var branchField = branchFields
    if branchField.kind == nnkRecList and branchField.len == 1:
      branchField = branchField[0]
    if branchField.kind != nnkIdentDefs or branchField.len != 3:
      error "only single field per branch allowed for now, no when", branchField
    var branchName = branchField[0]
    var branchPragmas: NimNode = nil
    if branchName.kind == nnkPragmaExpr:
      branchPragmas = branchName[1]
      branchName = branchName[0]
    else:
      branchPragmas = newEmptyNode()
    let branchNamePostfix = branchName
    let isBranchExported = branchName.kind == nnkPostfix
    if isBranchExported: branchName = branchName[1]
    let branchNameStr = $branchName
    let branchType = branchField[^2]
    let branchDefault = branchField[^1]
    result.stmts.add newProc(
      procType = nnkTemplateDef,
      name = branchNamePostfix,
      params = [branchType,
        newIdentDefs(fieldsObjName, typeName)],
      pragmas = branchPragmas,
      body = newTree(nnkCast, branchType, newCall(ident"untagInline", newDotExpr(fieldsObjName, realField)))
    )
    when false:
      # really needs untagMutInline which wouldn't always be available and would need a when with a concept or something
      var mutName = ident(branchNameStr & "Mut")
      result.stmts.add newProc(
        procType = nnkTemplateDef,
        name = if isBranchExported: newTree(nnkPostfix, ident"*", mutName) else: mutName,
        params = [newTree(nnkVarTy, branchType),
          newIdentDefs(fieldsObjName, newTree(nnkVarTy, typeName))],
        pragmas = branchPragmas,
        body = newTree(nnkDerefExpr,
          newTree(nnkCast, newTree(nnkPtrTy, branchType),
            newCall(ident"addr", newCall(ident"untagInline", newDotExpr(fieldsObjName, realField)))))
      )
    var initName = ident("init" & capitalizeAscii(branchNameStr))
    if isBranchExported: initName = newTree(nnkPostfix, ident"*", initName)
    let tagArgName = ident repr genSym(nskParam, tagNameStr)
    let branchArgName = ident repr genSym(nskParam, branchNameStr)
    let copiedName = ident repr genSym(nskLet, branchNameStr & "_copied")
    convenienceProcs.add newProc(
      procType = nnkProcDef,
      name = initName,
      params = [typeName,
        newTree(nnkIdentDefs, tagArgName, if tagConvType.isNil: tagType else: tagConvType, tagDefault),
        newTree(nnkIdentDefs, branchArgName, newCall(ident"sink", branchType), branchDefault)],
      pragmas = newTree(nnkPragma, ident"inline", ident"nodestroy", ident"used"),
      body = newStmtList(
        newTree(nnkLetSection,
          newTree(nnkIdentDefs, copiedName, newEmptyNode(), newCall(ident"=dup", branchArgName))),
        newTree(nnkObjConstr, typeName,
          newTree(nnkExprColonExpr, realField,
            newCall(ident"withTagInline",
              newTree(nnkCast, tagBaseType, copiedName),
              if tagConvType.isNil: tagArgName else: newCall(tagType, tagArgName)))))
    )
    branches.add (branch, branchNameStr, branchType)
  # general constructor for empty branches:
  block:
    let tagArgName = ident repr genSym(nskParam, tagNameStr)
    let baseArgName = ident repr genSym(nskParam, "base")
    let constructorName = ident("init" & $typeName)
    let constructor = newProc(
      procType = nnkProcDef,
      name = if typeIsExported: newTree(nnkPostfix, ident"*", constructorName) else: constructorName,
      params = [typeName,
        newTree(nnkIdentDefs, tagArgName, if tagConvType.isNil: tagType else: tagConvType, tagDefault),
        newTree(nnkIdentDefs, baseArgName, tagBaseType, newCall(ident"default", tagBaseType))],
      pragmas = newTree(nnkPragma, ident"inline", ident"used"),
      body = newTree(nnkObjConstr, typeName,
        newTree(nnkExprColonExpr, realField,
          newCall(ident"withTagInline",
            baseArgName,
            if tagConvType.isNil: tagArgName else: newCall(tagType, tagArgName))))
    )
    convenienceProcs.add constructor
    let condensateConstructor = newProc(
      procType = nnkTemplateDef,
      name = if typeIsExported: newTree(nnkPostfix, ident"*", ident"initCondensate") else: ident"initCondensate",
      params = [typeName,
        newTree(nnkIdentDefs, tagArgName, if tagConvType.isNil: tagType else: tagConvType, tagDefault),
        newTree(nnkIdentDefs, baseArgName, tagBaseType, newCall(ident"default", tagBaseType))],
      pragmas = newTree(nnkPragma, ident"used"),
      body = newTree(nnkObjConstr, typeName,
        newTree(nnkExprColonExpr, realField,
          newCall(ident"withTagInline",
            baseArgName,
            if tagConvType.isNil: tagArgName else: newCall(tagType, tagArgName))))
    )
    result.stmts.add condensateConstructor

  # fields iter:
  let fieldsIterName = ident repr genSym(nskParam, "condensateIter")
  var iterBody = newStmtList()
  let fieldsTag = ident repr genSym(nskLet, "condensateFieldsTag")
  iterBody.add newTree(nnkLetSection,
    newTree(nnkIdentDefs, fieldsTag, newEmptyNode(),
      newCall(tagName, fieldsObjName)))
  iterBody.add newCall(fieldsIterName,
    newCall(tagName, fieldsObjName),
    if tagConvType.isNil: tagType else: tagConvType,
    bindSym"CondensateTag",
    newLit tagNameStr)
  var fieldsCase = newNimNode(nnkCaseStmt, recCase)
  fieldsCase.add(fieldsTag)
  for b in branches:
    var newBranch = newNimNode(b.originalBranch.kind, b.originalBranch)
    for i in 0 ..< b.originalBranch.len - 1:
      newBranch.add b.originalBranch[i]
    if b.typ.isNil:
      newBranch.add newTree(nnkDiscardStmt, newEmptyNode())
    else:
      let field = ident repr genSym(nskLet, "condensateFields_" & b.name)
      newBranch.add newStmtList(
        newTree(nnkLetSection,
          newTree(nnkIdentDefs,
            newTree(nnkPragmaExpr, field, newTree(nnkPragma, ident"used")),
            newEmptyNode(),
            newCall(ident b.name, fieldsObjName))),
        newCall(fieldsIterName,
          field,
          b.typ,
          bindSym"CondensateValue",
          newLit b.name))
    fieldsCase.add newBranch
  iterBody.add fieldsCase
  result.stmts.add newProc(
    procType = nnkTemplateDef,
    name = ident"condensateFields",
    params = [ident"untyped",
      newIdentDefs(fieldsObjName, typeName, newEmptyNode()),
      newIdentDefs(fieldsIterName, ident"untyped", newEmptyNode())],
    pragmas = newTree(nnkPragma, ident"used"),
    body = iterBody
  )
  result.stmts.add getAst(implementCondensateDestructorsImpl(typeName))
  for p in convenienceProcs: result.stmts.add p

macro condensate*(node: untyped): untyped =
  let res = condensateImpl(node)
  if node.kind == nnkTypeDef:
    when (NimMajor, NimMinor) >= (2, 0):
      result = res.typeSection
      if res.stmts.len != 0:
        var typeStmts = newTree(nnkStmtListType)
        for st in res.stmts: typeStmts.add st
        typeStmts.add bindSym"void"
        result.add newTree(nnkTypeDef, ident"_", newEmptyNode(), typeStmts)
    else:
      if res.typeSection.len == 1 and res.stmts.len == 0:
        # wont happen but still
        result = res.typeSection[0]
      else:
        var typeStmts = newTree(nnkStmtListType)
        typeStmts.add res.typeSection
        for st in res.stmts: typeStmts.add st
        typeStmts.add bindSym"void"
        result = newTree(nnkTypeDef, ident"_", newEmptyNode(), typeStmts)
  else:
    result = newStmtList(res.typeSection)
    for st in res.stmts: result.add st
  #echo result.repr

macro implementCondensateDestructors*(T: untyped) =
  result = getAst(implementCondensateDestructorsImpl(T))
  #echo result.repr
