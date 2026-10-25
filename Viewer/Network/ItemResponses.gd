extends RefCounted
const Wire = preload("res://Network/LoginProtocol.gd")
# Decode to a temporary result before publishing any state. Malformed payloads
# must not partly overwrite a readable book or board.
static func decode(p: PackedByteArray) -> Dictionary:
 if p.size() < 3: return {}
 var id := int(p[0])
 if id in [0xd4,0x66,0x71] and Wire.read_be(p,1,2) != p.size(): return {}
 if id == 0xd4:
  if p.size() < 15: return {}
  var cursor := 13
  var length := Wire.read_be(p,11,2)
  if length < 1 or cursor+length+2 > p.size(): return {}
  var title := p.slice(cursor,cursor+length-1).get_string_from_utf8()
  cursor += length
  length = Wire.read_be(p,cursor,2)
  cursor += 2
  if length < 1 or cursor+length != p.size(): return {}
  return {"kind":"cover","serial":Wire.read_be(p,3,4),"title":title,"author":p.slice(cursor,cursor+length-1).get_string_from_utf8(),"page_count":Wire.read_be(p,9,2),"writable":p[8]!=0}
 if id == 0x66:
  if p.size() < 9: return {}
  var pages := {}
  var cursor := 9
  var count := Wire.read_be(p,7,2)
  if count > 1024: return {}
  for page in count:
   if cursor+4 > p.size(): return {}
   var number := Wire.read_be(p,cursor,2)
   var lines := Wire.read_be(p,cursor+2,2)
   cursor += 4
   if number < 1 or lines > 8: return {}
   var text: Array[String] = []
   for line in lines:
    var end := p.find(0,cursor)
    if end < cursor: return {}
    text.append(p.slice(cursor,end).get_string_from_utf8())
    cursor = end+1
   pages[number] = "\n".join(text)
  if cursor != p.size(): return {}
  return {"kind":"pages","serial":Wire.read_be(p,3,4),"pages":pages}
 if id == 0x71:
  if p.size() < 8: return {}
  var command := int(p[3])
  var board := Wire.read_be(p,4,4)
  if command == 0:
   if p.size() != 38: return {}
   return {"kind":"board","serial":board,"title":p.slice(8,p.find(0,8) if p.find(0,8) >= 8 else 38).get_string_from_utf8()}
  if command not in [1,2] or p.size() < 16: return {}
  var cursor := 16 if command == 1 else 12
  var strings: Array[String] = []
  for field in 3:
   if cursor >= p.size(): return {}
   var length := int(p[cursor])
   cursor += 1
   if length < 1 or cursor+length > p.size(): return {}
   strings.append(p.slice(cursor,cursor+length-1).get_string_from_utf8())
   cursor += length
  var result := {"kind":"post","serial":board,"post":Wire.read_be(p,8,4),"author":strings[0],"title":strings[1],"date":strings[2],"lines":[]}
  if command == 2:
   if cursor+5 > p.size(): return {}
   cursor += 4
   var equipment := int(p[cursor])
   cursor += 1+equipment*4
   if cursor >= p.size(): return {}
   var lines := int(p[cursor])
   cursor += 1
   for line in lines:
    if cursor >= p.size(): return {}
    var length := int(p[cursor])
    cursor += 1
    if length < 2 or cursor+length > p.size(): return {}
    result.lines.append(p.slice(cursor,cursor+length-2).get_string_from_utf8())
    cursor += length
  if cursor != p.size(): return {}
  return result
 return {}
