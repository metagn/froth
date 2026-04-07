when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import froth

# needs to be in the order: anybytes[lowerbits[T]]
# probably could just be their own type

test "basic combination":
  var x = new(int)
  x[] = 123
  var y = x.tagLowerBits(7).tagUpperByte(150)
  check y.getTag == 150
  check y.untag.getTag == 7
  y.getTagMut += 3
  check y.getTag == 153
  check y.untag.getTag == 7
  check y.untag.untag[] == 123
  y.untag.untag[] += 2
  check y.untag.untag[] == 125

type
  Owner = ref object
    name: string
    subject: LowerShortTagged[LowerBitsTagged[Subject]]
  Subject = ref object
    name: string
    owner: UpperShortTagged[LowerBitsTagged[Owner]]

proc `$`(x: Owner): string =
  if x == nil:
    result = "no owner"
  else:
    result = "owner " & x.name & " with "
    if x.subject.untag.isNil:
      result.add("no subject")
    else:
      result.add("subject ")
      result.add(x.subject.untag.untag.name)
    result.add(" and first tag ")
    result.add($x.subject.getTag)
    result.add(" and second tag ")
    result.add($x.subject.untag.getTag)
proc `$`(x: Subject): string =
  result = "subject " & x.name & " with "
  if x.owner.isNil:
    result.add("no owner")
  else:
    result.add("owner " & $x.owner.untag.untag.name)
  result.add(" and first tag ")
  result.add($x.owner.getTag)
  result.add(" and second tag ")
  result.add($x.owner.untag.getTag)

test "simple cycle with combination":
  var owner = Owner(name: "O")
  var subjectA = Subject(name: "A", owner: owner.tagLowerBits(4).tagUpperShort(3065))
  owner.subject = subjectA.tagLowerBits(2).tagLowerShort(15097)
  check $owner == "owner O with subject A and first tag 15097 and second tag 2"
  check $subjectA == "subject A with owner O and first tag 3065 and second tag 4"
