extends RefCounted
const Wire = preload("res://Network/LoginProtocol.gd")
const MAX_EXPANDED = 2097152
static func unicode_be(data: PackedByteArray) -> String:
 if data.size()%2: return ""
 var little := data.duplicate()
 for i in range(0,data.size(),2):
  little[i] = data[i+1]
  little[i+1] = data[i]
 return little.get_string_from_utf16()
static func unicode_bytes(value: String) -> PackedByteArray:
 var little := value.to_utf16_buffer()
 var result := little.duplicate()
 for i in range(0,little.size(),2):
  result[i] = little[i+1]
  result[i+1] = little[i]
 return result
static func packed(data: PackedByteArray, cursor: int) -> Dictionary:
 if cursor+4 > data.size(): return {}
 var length := Wire.read_be(data,cursor,4)
 if length == 0: return {"data":PackedByteArray(),"cursor":cursor+4}
 if length < 5 or cursor+4+length > data.size(): return {}
 var expanded := Wire.read_be(data,cursor+4,4)
 if expanded < 1 or expanded > MAX_EXPANDED: return {}
 var raw := data.slice(cursor+8,cursor+4+length).decompress(expanded,FileAccess.COMPRESSION_DEFLATE)
 if raw.size() != expanded: return {}
 return {"data":raw,"cursor":cursor+4+length}
static func decode(data: PackedByteArray) -> Dictionary:
 if data.size() < 23 or data[0] not in [0xb0,0xdd] or Wire.read_be(data,1,2) != data.size(): return {}
 var layout := PackedByteArray()
 var strings := PackedByteArray()
 var count := 0
 if data[0] == 0xdd:
  var block := packed(data,19)
  if block.is_empty() or block.cursor+4 > data.size(): return {}
  layout = block.data
  count = Wire.read_be(data,block.cursor,4)
  block = packed(data,block.cursor+4)
  if block.is_empty() or block.cursor != data.size(): return {}
  strings = block.data
 else:
  var length := Wire.read_be(data,19,2)
  if 21+length+2 > data.size(): return {}
  layout = data.slice(21,21+length)
  count = Wire.read_be(data,21+length,2)
  strings = data.slice(23+length)
 if count > 4096 or layout.size() > MAX_EXPANDED: return {}
 var texts: Array[String] = []
 var cursor := 0
 for i in count:
  if cursor+2 > strings.size(): return {}
  var length := Wire.read_be(strings,cursor,2)*2
  cursor += 2
  if cursor+length > strings.size(): return {}
  texts.append(unicode_be(strings.slice(cursor,cursor+length)))
  cursor += length
 if cursor != strings.size(): return {}
 var end := layout.find(0)
 if end >= 0: layout = layout.slice(0,end)
 var commands := parse_layout(layout.get_string_from_utf8())
 if commands.size() > 4096: return {}
 return {"serial":Wire.read_be(data,3,4),"type":Wire.read_be(data,7,4),"x":Wire.read_be(data,11,4),"y":Wire.read_be(data,15,4),"commands":commands,"texts":texts}
static func parse_layout(layout: String) -> Array:
 var groups := RegEx.new()
 groups.compile("\\{([^{}]*)\\}")
 var tokens := RegEx.new()
 tokens.compile("@[^@]*@|[^\\s]+")
 var result := []
 for group in groups.search_all(layout):
  var values: Array[String] = []
  for token in tokens.search_all(group.get_string(1)): values.append(token.get_string())
  if not values.is_empty(): result.append(values)
 return result
static func response(gump: Dictionary, button: int, switches: Array, entries: Dictionary) -> PackedByteArray:
 if switches.size() > 4096 or entries.size() > 4096: return PackedByteArray()
 var body := Wire.uint_be(int(gump.serial),4)
 body.append_array(Wire.uint_be(int(gump.type),4))
 body.append_array(Wire.uint_be(button,4))
 body.append_array(Wire.uint_be(switches.size(),4))
 for value in switches: body.append_array(Wire.uint_be(int(value),4))
 body.append_array(Wire.uint_be(entries.size(),4))
 for key in entries:
  var text := unicode_bytes(str(entries[key]))
  if text.size()/2 > 239: return PackedByteArray()
  body.append_array(Wire.uint_be(int(key),2))
  body.append_array(Wire.uint_be(text.size()/2,2))
  body.append_array(text)
 if body.size()+3 > 65535: return PackedByteArray()
 var result := PackedByteArray([0xb1])
 result.append_array(Wire.uint_be(body.size()+3,2))
 result.append_array(body)
 return result

static func art_ids(gump: Dictionary) -> Array:
 var result := {}
 for command in gump.commands:
  if command[0] == "resizepic" and command.size() >= 6:
   for i in 9: result[int(command[3])+i] = true
  elif command[0] == "gumppic" and command.size() >= 4: result[int(command[3])] = true
  elif command[0] == "gumppictiled" and command.size() >= 6: result[int(command[5])] = true
  elif command[0] in ["button","buttontileart","checkbox","radio"] and command.size() >= 5:
   result[int(command[3])] = true
   result[int(command[4])] = true
 return result.keys()
