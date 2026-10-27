extends RefCounted
## First licensed human wardrobe. IDs are pinned ModernUO item graphics.
const SLOTS := ["tunic","pants","boots","robe","hood"]
const GRAPHICS := {
	0x1517:1,0x1518:1,0x1efd:1,0x1efe:1,0x1fa1:1,0x1fa2:1,0x13bf:1,0x13c0:1,0x1f7b:1,0x1f7c:1,
	0x152e:2,0x152f:2,0x1539:2,0x153a:2,
	# Temporary lower-clothing substitute for native female starter skirt/kilt.
	0x1516:2,0x1531:2,0x1537:2,0x1538:2,
	0x170b:4,0x170c:4,0x170d:4,0x170e:4,0x170f:4,0x1710:4,0x1711:4,0x1712:4,
	0x1f03:8,0x1f04:8,0x2687:24,0x2683:24,0x2684:24,0x204e:24,0x278f:16,0x27da:16
}
static func human(body: int) -> bool: return body in [0x190,0x191]
static func female(body: int) -> bool: return body == 0x191
static func resolve(worn: Array) -> Dictionary:
	var bits := 0
	var unsupported: Array[int] = []
	var hues := {}
	var hair := false
	for item: Dictionary in worn:
		var id := int(item.get("id",0))
		var layer := int(item.get("layer",0))
		if layer == 11: hair = true
		var mask := int(GRAPHICS.get(id,0))
		bits |= mask
		for i in SLOTS.size():
			if mask & (1<<i): hues[SLOTS[i]] = int(item.get("hue",0))
		if mask == 0 and layer not in [0,11,16,18,21,25,26,27] and layer != 1 and layer != 2:
			unsupported.append(id)
	# Outer robe obscures the shirt, while trousers/boots can show at its opening.
	if bits & 8: bits &= ~1
	return {"bits":bits,"hues":hues,"hair":hair,"unsupported":unsupported}
