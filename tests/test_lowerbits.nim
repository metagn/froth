import froth/lowerbits

block: # basic
  var x = new(int)
  x[] = 123
  var tagged = tagLowerBits(x, 5)
  doAssert tagged.tag == 5
  doAssert tagged.untag[] == 123
  doAssert tagged.tag == 5
  tagged.untag[] += 2
  doAssert tagged.untag[] == 125
  doAssert sizeof(tagged) == sizeof(x)

type
  Owner = ref object
    name: string
    subject: LowerBitsTagged[Subject]
  Subject = ref object
    name: string
    owner: LowerBitsTagged[Owner]

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

block: # simple cycle
  var owner = Owner(name: "O")
  var subjectA = Subject(name: "A", owner: tagLowerBits(owner, 5))
  owner.subject = tagLowerBits(subjectA, 7)
  doAssert $owner == "owner O with subject A and tag 7"
  doAssert $subjectA == "subject A with owner O and tag 5"
