extends RefCounted
## Modern client's 0x78 layout: full 16-bit graphic + layer + hue per entry.
## Matches pinned ModernUO OutgoingMobilePackets.SendMobileIncoming.
const Wire = preload("res://Network/LoginProtocol.gd")
static func snapshot(p: PackedByteArray) -> Dictionary:
	if p.size()<23 or p[0]!=0x78: return {}
	var serial := Wire.read_be(p,3,4)
	var z := int(p[13])
	if z>127: z-=256
	var entity := {"serial":serial,"body":Wire.read_be(p,7,2),"x":Wire.read_be(p,9,2),"y":Wire.read_be(p,11,2),"z":z,"direction":int(p[14])&7,"running":(p[14]&0x80)!=0,"hue":Wire.read_be(p,15,2),"flags":int(p[17])}
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
