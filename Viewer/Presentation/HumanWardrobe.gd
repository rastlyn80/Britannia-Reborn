extends RefCounted
## First licensed human wardrobe. IDs are pinned ModernUO item graphics.
const Coverage = preload("res://Presentation/HumanCoverageWardrobe.gd")
const SLOTS := ["tunic","pants","boots","robe","hood"]
const GRAPHICS := {
	0x1fa1:1,0x1fa2:1,0x13bf:1,
	0x152e:2,0x152f:2,0x1539:2,0x153a:2,
	0x170b:4,0x170c:4,0x1711:4,0x1712:4,
	0x1f03:8,0x1f04:8,0x2687:24,0x2683:24,0x2684:24,0x204e:24,0x278f:16,0x27da:16
}
const EXTRA := {
	0x1f7b:["doublet","doublet"],0x1f7c:["doublet","doublet"],
	0x1515:["cloak","cloak"],0x1530:["cloak","cloak"],
	0x170f:["feet","shoes"],0x1710:["feet","shoes"],
	0x170d:["feet","sandals"],0x170e:["feet","sandals"],
	0x1517:["shirt","shirt"],0x1518:["shirt","shirt"],
	0x1efd:["shirt","shirt"],0x1efe:["shirt","shirt"],
	0x1715:["head","cap"],0x1713:["head","felt_hat"],
	0x1516:["outer_legs","skirt"],0x1531:["outer_legs","skirt"],
	0x1537:["outer_legs","kilt"],0x1538:["outer_legs","kilt"],
	0x13c6:["hands","gloves"],0x13ce:["hands","gloves"],
	0x13d5:["hands","gloves"],0x13dd:["hands","gloves"],
	0x1414:["hands","gloves"],0x1418:["hands","gloves"],
	0x1412:["head","closed_helmet"],0x1419:["head","closed_helmet"],
	0x1408:["head","closed_helmet"],0x1409:["head","closed_helmet"],
	0x140a:["head","helmet"],0x140b:["head","helmet"],
	0x140c:["head","helmet"],0x140d:["head","helmet"],
	0x140e:["head","helmet"],0x140f:["head","helmet"],
	0x0f5e:["weapon","sword"],0x0f5f:["weapon","sword"],
	0x0f60:["weapon","sword"],0x0f61:["weapon","sword"],
	0x13b9:["weapon","sword"],0x13ba:["weapon","sword"],
	0x13ff:["weapon","sword"],0x13fe:["weapon","sword"],
	0x1438:["weapon","hammer"],0x1439:["weapon","hammer"],
	0x0e81:["weapon","staff"],0x0e82:["weapon","staff"],
	0x0e89:["weapon","staff"],0x0e8a:["weapon","staff"],
	0x0df0:["weapon","staff"],0x0df1:["weapon","staff"],
	0x13f8:["weapon","staff"],0x13f9:["weapon","staff"],
	0x26bc:["weapon","staff"],0x26c6:["weapon","staff"]
}
const HAIR := {0x203b:"short",0x203c:"long",0x203d:"ponytail",0x2045:"bob",0x2047:"afro"}
const BEARDS := {0x203e:["long"],0x203f:["short"],0x2040:["goatee"],0x2041:["moustache"],0x204b:["short","moustache"],0x204c:["long","moustache"],0x204d:["goatee","moustache"]}
static func mapped(id: int) -> bool: return GRAPHICS.has(id) or EXTRA.has(id) or HAIR.has(id) or BEARDS.has(id) or Coverage.ITEMS.has(id)
static func extra(id: int) -> Array: return EXTRA.get(id,Coverage.ITEMS.get(id,[]))
static func human(body: int) -> bool: return body in [0x190,0x191]
static func female(body: int) -> bool: return body == 0x191
static func resolve(worn: Array) -> Dictionary:
	var bits := 0
	var unsupported: Array[int] = []
	var hues := {}
	var hair := false
	var hair_id := 0
	var hair_hue := 0
	var beard_id := 0
	var beard_hue := 0
	var pieces := {}
	var ordered := worn.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.get("layer",0))<int(b.get("layer",0)))
	for item: Dictionary in ordered:
		var id := int(item.get("id",0))
		var layer := int(item.get("layer",0))
		if layer == 11:
			hair = id!=0
			hair_id = id
			hair_hue = int(item.get("hue",0))
		if layer == 16:
			beard_id = id
			beard_hue = int(item.get("hue",0))
		var mask := int(GRAPHICS.get(id,0))
		bits |= mask
		for i in SLOTS.size():
			if mask & (1<<i): hues[SLOTS[i]] = int(item.get("hue",0))
		if not extra(id).is_empty():
			var extra: Array = extra(id)
			pieces[str(extra[0])] = {"asset":str(extra[1]),"hue":int(item.get("hue",0)),"id":id}
		if mask == 0 and extra(id).is_empty() and layer not in [0,11,16,18,21,25,26,27]:
			unsupported.append(id)
	# MiddleTorso replaces tunic/doublet on that native layer, retaining shirt/armour.
	if pieces.has("middle"):
		bits &= ~1;pieces.erase("doublet")
	# Outer robe obscures the shirt, while trousers/boots can show at its opening.
	if bits & 8: bits &= ~1
	if bits & 8:
		pieces.erase("outer_legs");pieces.erase("shirt");pieces.erase("doublet");pieces.erase("middle")
	if bits & 8:
		for slot in ["torso","arms"]:pieces.erase(slot)
	if pieces.has("torso"):
		bits &= ~1
		pieces.erase("shirt");pieces.erase("doublet")
	if pieces.has("legs"):bits &= ~2
	if bits & 1:pieces.erase("shirt");pieces.erase("doublet")
	if pieces.has("feet"):bits &= ~4
	if pieces.has("head"): bits &= ~16
	return {"bits":bits,"hues":hues,"hair":hair,"hair_id":hair_id,"hair_hue":hair_hue,"hair_style":HAIR.get(hair_id,"short" if hair else ""),"hair_exact_family":not hair or HAIR.has(hair_id),"beard_id":beard_id,"beard_hue":beard_hue,"beard_styles":BEARDS.get(beard_id,[]),"beard_exact_family":beard_id==0 or BEARDS.has(beard_id),"pieces":pieces,"gloves":pieces.has("hands"),"unsupported":unsupported}
