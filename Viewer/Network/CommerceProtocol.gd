extends RefCounted
const Wire = preload("res://Network/LoginProtocol.gd")
static func lift(serial: int, amount: int) -> PackedByteArray:
 if serial <= 0 or amount < 1 or amount > 65535: return PackedByteArray()
 var p := PackedByteArray([7])
 p.append_array(Wire.uint_be(serial,4))
 p.append_array(Wire.uint_be(amount,2))
 return p
static func drop(serial: int, destination: int, point: Vector3i = Vector3i(-1,-1,0)) -> PackedByteArray:
 var p := PackedByteArray([8])
 p.append_array(Wire.uint_be(serial,4))
 p.append_array(Wire.uint_be(point.x&65535,2))
 p.append_array(Wire.uint_be(point.y&65535,2))
 p.append_array(PackedByteArray([point.z&255,0]))
 p.append_array(Wire.uint_be(destination,4))
 return p
static func equip(serial: int, mobile: int) -> PackedByteArray:
 var p := PackedByteArray([0x13])
 p.append_array(Wire.uint_be(serial,4))
 p.append(0) # ModernUO derives the real layer from the held item's class.
 p.append_array(Wire.uint_be(mobile,4))
 return p
static func context_request(serial: int) -> PackedByteArray:
 var p := PackedByteArray([0xbf,0,9,0,0x13])
 p.append_array(Wire.uint_be(serial,4))
 return p
static func context_reply(serial: int,index: int) -> PackedByteArray:
 var p := PackedByteArray([0xbf,0,11,0,0x15])
 p.append_array(Wire.uint_be(serial,4))
 p.append_array(Wire.uint_be(index,2))
 return p
static func context(p: PackedByteArray) -> Dictionary:
 if p.size()<12 or Wire.read_be(p,3,2)!=0x14: return {}
 var version := Wire.read_be(p,5,2)
 if version not in [1,2]: return {}
 var cursor := 12
 var options := []
 for i in int(p[11]):
  var size := 8 if version == 2 else 6
  if cursor+size > p.size(): return {}
  var option := {"index":Wire.read_be(p,cursor+(4 if version==2 else 0),2),"label":Wire.read_be(p,cursor,4) if version==2 else 3000000+Wire.read_be(p,cursor+2,2),"flags":Wire.read_be(p,cursor+(6 if version==2 else 4),2)}
  cursor += size
  if version == 1 and (int(option.flags)&0x20)!=0: cursor += 2
  if cursor > p.size(): return {}
  options.append(option)
 if cursor != p.size(): return {}
 return {"serial":Wire.read_be(p,7,4),"options":options}
static func prices(p: PackedByteArray) -> Dictionary:
 if p.size()<8: return {}
 var cursor := 8
 var entries := []
 for i in int(p[7]):
  if cursor+5>p.size(): return {}
  var price := Wire.read_be(p,cursor,4)
  var length := int(p[cursor+4])
  cursor += 5
  if length<1 or cursor+length>p.size(): return {}
  entries.append({"price":price,"description":p.slice(cursor,cursor+length-1).get_string_from_ascii()})
  cursor += length
 if cursor != p.size(): return {}
 return {"container":Wire.read_be(p,3,4),"entries":entries}
static func buy(vendor: int,serial: int,amount: int) -> PackedByteArray:
 if amount<1 or amount>32767: return PackedByteArray()
 var p := PackedByteArray([0x3b,0,15])
 p.append_array(Wire.uint_be(vendor,4))
 p.append_array(PackedByteArray([2,0x1a]))
 p.append_array(Wire.uint_be(serial,4))
 p.append_array(Wire.uint_be(amount,2))
 return p
