when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import froth/lowerbyte

test "basic":
  var x = new(int)
  x[] = 123
  var tagged = tagLowerByte(x, 5)
  check tagged.tag == 5
  check tagged.untag[] == 123
  check tagged.tag == 5
  tagged.untag[] += 2
  check tagged.untag[] == 125
  check sizeof(tagged) == sizeof(x)

test "addressable tag":
  var x = new(int)
  x[] = 123
  var tagged = tagLowerByte(x, 5)
  check tagged.tag == 5
  tagged.tag += 2
  check tagged.tag == 7

type
  Owner = ref object
    name: string
    subject: LowerByteTagged[Subject]
  Subject = ref object
    name: string
    owner: LowerByteTagged[Owner]

proc `$`(x: Owner): string =
  if x == nil:
    result = "no owner"
  else:
    result = "owner " & x.name & " with "
    if x.subject.untag.isNil:
      result.add("no subject")
    else:
      result.add("subject ")
      result.add(x.subject.untag.name)
    result.add(" and tag ")
    result.add($x.subject.tag)
proc `$`(x: Subject): string =
  result = "subject " & x.name & " with "
  if x.owner.untag == nil:
    result.add("no owner")
  else:
    result.add("owner " & $x.owner.untag.name)
  result.add(" and tag ")
  result.add($x.owner.tag)

test "simple cycle":
  var owner = Owner(name: "O")
  var subjectA = Subject(name: "A", owner: tagLowerByte(owner, 65))
  owner.subject = tagLowerByte(subjectA, 97)
  check $owner == "owner O with subject A and tag 97"
  check $subjectA == "subject A with owner O and tag 65"
