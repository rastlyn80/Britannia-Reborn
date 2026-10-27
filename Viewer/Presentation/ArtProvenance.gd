extends SceneTree
# Labels every graphic in the local item catalogue with what this client draws
# for it today: a photoscan / realistic PBR model (scan, final quality), code-
# built joinery in photoscanned materials (crafted), the owner's licensed packs,
# a low-poly stand-in kit model (kit, to be replaced), plain geometry built in
# code, nothing (no-draw), or nothing yet (original only). Mirrors the dispatch
# in Reconstruction.build and WorldItems.upsert. Name-rule looks for graphics
# never placed in Britain or reviewed are reported as untested guesses.
#   --catalog=PATH (outputs/item-catalog/catalog.js)  --out=PATH (current.js)
const Rules := preload("res://Presentation/RegionalRules.gd")
const Reviewed := preload("res://Presentation/ReviewedCatalog.gd")
const LocalPlants := preload("res://Presentation/LocalPlants.gd")
const LocalTrees := preload("res://Presentation/LocalTrees.gd")
const LocalProps := preload("res://Presentation/LocalProps.gd")
const Appearance := preload("res://Presentation/ItemAppearance.gd")
# Kinds Reconstruction builds from code (with kit/Poly Haven materials).
const BUILT := ["litter","palisade","waterfall","cactus","lava","lilypad","stalagmite","crystal","wall","window","corner","trim","beam","gable","pillar","floor","landing","stairs","roof","carpet","table","bench","counter","sign","painting","planter","chimney","water","door"]
const FITTED := ["reeds","vine","asset","post","fence","bed","mushroom","rock","log","canopy","arch"]

func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=",true,1)
		if parts.size() == 2: args[parts[0]] = parts[1]
	var text := FileAccess.get_file_as_string(args.get("catalog",""))
	var catalog: Variant = JSON.parse_string(text.trim_prefix("window.CATALOG=").trim_suffix(";"))
	if not catalog is Dictionary:
		push_error("Catalogue not found; run scripts/build-item-catalog.ps1")
		quit(1)
		return
	var audited: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/static-catalog.json")).rules
	var servers: Dictionary = {}
	if FileAccess.file_exists("res://item-definitions.local.json"):
		servers = JSON.parse_string(FileAccess.get_file_as_string("res://item-definitions.local.json"))
	var approved := {}
	if FileAccess.file_exists("res://Presentation/reviewed-families.json"):
		for entry in JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/reviewed-families.json")).approved:
			for id in entry.ids: approved[int(id)] = true
	var result := {}
	var counts := {}
	for item in catalog.items:
		var id := int(item.id)
		var look := look_for(id,item,audited.get(str(id),{}),servers.get(str(id),{}))
		var checked: bool = audited.has(str(id)) or servers.has(str(id)) or int(item.britain) > 0 or not Reviewed.entry(id).is_empty() or approved.has(id)
		if look.status in ["kit","owner","built"] and not checked:
			look = {"status":"guess","detail":"untested guess: "+str(look.detail)}
		result[str(id)] = look
		counts[look.status] = int(counts.get(look.status,0))+1
	var file := FileAccess.open(args.get("out",""),FileAccess.WRITE)
	file.store_string("window.CURRENT="+JSON.stringify({"generated":Time.get_datetime_string_from_system(true),"looks":result})+";")
	file.close()
	print("CURRENT LOOKS: ",counts)
	# Coverage weighted by Britain placements (map statics and server decoration).
	var weights := {}
	var total := 0
	for item in catalog.items:
		var n := int(item.get("britain",0))+int(item.get("decoration",0))
		if n == 0: continue
		var status := str(result[str(int(item.id))].status)
		weights[status] = int(weights.get(status,0))+n
		total += n
	var summary := ""
	for status in ["scan","crafted","owner","kit","built","guess","original","hidden"]:
		summary += "%s %.1f%%  " % [status,100.0*float(weights.get(status,0))/maxf(total,1)]
	print("BRITAIN COVERAGE (placements): ",summary)
	quit(0)

# Tiledata flag names (catalogue order) back to their bit values.
const FLAG_NAMES := ["background","weapon","transparent","translucent","wall","damaging","impassable","wet","unknown","surface","bridge","stackable","window","noshoot","article-a","article-an","article-the","foliage","partial-hue","no-house","map","container","wearable","light","animated","hover","no-diagonal","armor","roof","door","stair-back","stair-right"]
static func flag_bits(names: Array) -> int:
	var bits := 0
	for name in names:
		var at := FLAG_NAMES.find(name)
		if at >= 0: bits |= 1 << at
	return bits

static func pack(asset: String) -> Dictionary:
	if asset.begins_with("procedural:") or asset.is_empty(): return {"status":"built","detail":"built in code"}
	if asset.begins_with("PolyHaven/"): return {"status":"scan","detail":"Poly Haven photoscan (CC0): "+asset.get_file().get_basename()}
	if asset.begins_with("Objaverse/"): return {"status":"scan","detail":"Sketchfab scan/PBR (see Art/Objaverse/NOTICE.md): "+asset.get_file().get_basename()}
	var vendor := "Poly Haven" if asset.begins_with("PolyHaven/") else ("Kenney" if asset.begins_with("Kenney/") else ("Medieval kit" if asset.begins_with("MedievalKit/") else "Quaternius"))
	return {"status":"kit","detail":"%s (CC0): %s" % [vendor,asset.get_file().get_basename()]}

func look_for(id: int,item: Dictionary,audited: Dictionary,server: Dictionary) -> Dictionary:
	var name := str(item.name)
	if item.flags.has("wearable") and item.world == 0:
		if preload("res://Presentation/HumanWardrobe.gd").GRAPHICS.has(id):
			return {"status":"kit","detail":"MakeHuman CC0: fitted human wardrobe category substitute"}
		return {"status":"original","detail":"worn model outside the first human wardrobe batch"}
	# Name-keyed scan replacements apply to map statics and server items alike.
	var found: Dictionary = preload("res://Presentation/PropReplacements.gd").entry(name)
	if not found.is_empty():
		var model := str(found.model)
		return pack(("Objaverse/%s/%s.glb" % [model.trim_prefix("Objaverse/"),model.trim_prefix("Objaverse/")]) if model.begins_with("Objaverse/") else "PolyHaven/%s/%s" % [model,model])
	var review: Dictionary = Reviewed.entry(id)
	# Counters are built cell by cell in photoscanned timber whatever their review says.
	if str(review.get("kind",audited.get("kind",""))) == "counter": return {"status":"crafted","detail":"panelled counter in photoscanned timber"}
	if review.has("asset"):
		var reviewed := pack(str(review.asset))
		reviewed.detail += " (reviewed)"
		return reviewed
	if review.has("construction") or str(review.get("renderer","")) == "shared-construction":
		var reviewed_kind := str(review.get("kind",audited.get("kind","")))
		if reviewed_kind in ["wall","window","corner","trim","beam","gable","arch","floor","landing","stairs","roof","bridge"] or str(review.get("construction","")) in ["wall","bridge","facade"]:
			return {"status":"crafted","detail":"built in code with photoscanned surfaces (reviewed)"}
		return {"status":"built","detail":"built in code (reviewed)"}
	if not server.is_empty() and audited.is_empty():
		var family := str(server.get("family",""))
		if family == "door": return {"status":"crafted","detail":"door leaf in photoscanned timber and iron"}
		if family in ["chest","drawers"]: return {"status":"crafted" if family == "chest" else "scan","detail":"iron-bound chest in photoscanned timber and iron" if family == "chest" else "Poly Haven photoscan (CC0): GothicCommode_01"}
		if family == "plant": return {"status":"scan","detail":"Poly Haven photoscan (CC0): potted plant"}
		if family == "sign": return {"status":"crafted","detail":"hanging sign board with painted face"}
		if family in ["crate","barrel"] and not LocalProps.items().is_empty(): return {"status":"owner","detail":"Dexsoft %s (your pack, local)" % family}
		if family == "lamp": return {"status":"kit","detail":"Medieval kit (CC0): lantern post, or built in code"}
		return {"status":"built","detail":"built in code: "+Appearance.variant(id,server)}
	var rule: Dictionary = audited if not audited.is_empty() else Rules.resolve(id,{"name":name,"height":item.height,"flags":flag_bits(item.flags)})
	if rule.is_empty(): return {"status":"original","detail":"no 3D look yet"}
	if rule.has("slot") and not preload("res://Presentation/Reconstruction.gd").art_tint(id).is_empty() and preload("res://Presentation/LocalLibrary.gd").has(str(rule.slot)):
		return {"status":"owner","detail":"your packs: %s (local library)" % rule.slot}
	var kind := str(rule.get("kind",""))
	var asset := str(rule.get("asset",""))
	match kind:
		"invisible": return {"status":"hidden","detail":"not drawn (editor marker)"}
		"sign": return {"status":"hidden","detail":"signpost drawn by its server sign"}
		"canopy":
			if LocalTrees.available(): return {"status":"owner","detail":"your tree packs (local): crown of a whole tree"}
			return pack(asset)
		"tree":
			if LocalTrees.available(): return {"status":"owner","detail":"your tree packs (local)"}
			return pack(asset)
		"grass","flower","bush","fern","plant":
			var plant := LocalPlants.rule(kind,name)
			if not plant.is_empty() and not LocalPlants.items(str(plant.group)).is_empty(): return {"status":"owner","detail":"your nature packs (local)"}
			return pack(asset)
		"prop":
			var local := LocalProps.kind_for(str(rule.model),name.to_lower())
			if local != "" and not LocalProps.items().is_empty(): return {"status":"owner","detail":"Dexsoft %s (your pack, local)" % local}
			if str(rule.model) == "display_case": return {"status":"crafted","detail":"glazed display cabinets in photoscanned timber"}
			if str(rule.model) == "cannon": return pack("PolyHaven/cannon_01/cannon_01_1k.gltf")
			return {"status":"built","detail":"built in code: "+str(rule.model)}
	if kind in FITTED: return pack(asset)
	var named := name.to_lower()
	if kind == "counter": return {"status":"crafted","detail":"panelled counter in photoscanned timber"}
	if kind == "carpet": return {"status":"crafted","detail":"woven rug from photoscanned fabric"}
	if kind == "table" and not ("stone" in named or "marble" in named or "sandstone" in named): return pack("Objaverse/table_wood_b/table_wood_b.glb")
	if kind == "bed": return pack("PolyHaven/GothicBed_01/GothicBed_01_1k.gltf")
	# Architecture and water are built from photoscanned surface sets.
	if kind in ["wall","window","corner","trim","beam","gable","pillar","floor","landing","stairs","roof","chimney","water","lava","waterfall","palisade","planter"]:
		return {"status":"crafted","detail":"built in code with photoscanned surfaces: "+kind}
	if kind in BUILT:
		var detail := "built in code: "+kind
		if kind == "window": detail += " + Medieval kit shutters"
		return {"status":"built","detail":detail}
	return {"status":"original","detail":"no 3D look yet ("+kind+")"}
