extends RefCounted
## Modern client's 0x78 layout: full 16-bit graphic + layer + hue per entry.
## Matches pinned ModernUO OutgoingMobilePackets.SendMobileIncoming.
const Wire = preload("res://Network/LoginProtocol.gd")
static func snapshot(p: PackedByteArray) -> Dictionary:
	if p.size()<23 or p[0]!=0x78: return {}
	var serial := Wire.read_be(p,3,4)
	var z := int(p[13])
	if z>127: z-=256
	var entity := {"serial":serial,"body":Wire.read_be(p,7,2),"x":Wire.read_be(p,9,2),"y":Wire.read_be(p,11,2),"z":z,"direction":int(p[14])&7,"running":(p[14]&0x80)!=0,"hue":Wire.read_be(p,15,2),"flags":int(p[17]),"notoriety":int(p[18])}
	var worn := {}
	var offset := 19
	while offset+4<=p.size():
		var item_serial := Wire.read_be(p,offset,4)
		if item_serial==0: return {"entity":entity,"worn":worn}
		if offset+9>p.size(): return {}
		var layer := int(p[offset+6])
		worn[layer] = {"serial":item_serial,"id":Wire.read_be(p,offset+4,2),"amount":1,"layer":layer,"container":serial,"hue":Wire.read_be(p,offset+7,2)}
		offset+=9
	return {}

static func profile(entity: Dictionary, worn: Array, stats: Dictionary = {}, display_name: String = "") -> Dictionary:
	# Store exact native identities independently of art substitutions. Missing
	# NPC statistics stay absent; the client must never manufacture server data.
	var result := {"serial":int(entity.get("serial",0)),"body":int(entity.get("body",0)),"skin_hue":int(entity.get("hue",0)),"hair_id":0,"hair_hue":0,"beard_id":0,"beard_hue":0,"flags":int(entity.get("flags",0)),"notoriety":int(entity.get("notoriety",0)),"name":display_name,"statistics":stats.duplicate(true),"equipment":worn.duplicate(true)}
	result.native_mobile = entity.duplicate(true)
	for item: Dictionary in worn:
		var layer := int(item.get("layer",0))
		if layer == 11:
			result.hair_id = int(item.get("id",0))
			result.hair_hue = int(item.get("hue",0))
		elif layer == 16:
			result.beard_id = int(item.get("id",0))
			result.beard_hue = int(item.get("hue",0))
	return result

static func action(p: PackedByteArray) -> Dictionary:
	if p.size()==14 and p[0]==0x6e:
		return {"serial":Wire.read_be(p,1,4),"protocol":"classic","action":Wire.read_be(p,5,2),"frames":Wire.read_be(p,7,2),"repeat_count":Wire.read_be(p,9,2),"reverse":p[11]!=0,"repeat":p[12]!=0,"delay":int(p[13])}
	if p.size()==10 and p[0]==0xe2:
		return {"serial":Wire.read_be(p,1,4),"protocol":"new","action":Wire.read_be(p,5,2),"frames":Wire.read_be(p,7,2),"delay":int(p[9])}
	return {}
