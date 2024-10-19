when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import froth/lowershort

test "basic":
  var x = new(int)
  x[] = 123
  var tagged = tagLowerShort(x, 5)
  check tagged.tag == 5
  check tagged.untag[] == 123
  check tagged.tag == 5
  tagged.untag[] += 2
  check tagged.untag[] == 125
  check sizeof(tagged) == sizeof(x)

test "addressable tag":
  var x = new(int)
  x[] = 123
  var tagged = tagLowerShort(x, 5)
  check tagged.tag == 5
  tagged.tag += 2
  check tagged.tag == 7

type
  Owner = ref object
    name: string
    subject: LowerShortTagged[Subject]
  Subject = ref object
    name: string
    owner: LowerShortTagged[Owner]

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
  var subjectA = Subject(name: "A", owner: tagLowerShort(owner, 3065))
  owner.subject = tagLowerShort(subjectA, 15097)
  check $owner == "owner O with subject A and tag 15097"
  check $subjectA == "subject A with owner O and tag 3065"
