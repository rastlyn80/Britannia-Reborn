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
	var coverage := coverage_for(catalog,result)
	var file := FileAccess.open(args.get("out",""),FileAccess.WRITE)
	file.store_string("window.CURRENT="+JSON.stringify({"generated":Time.get_datetime_string_from_system(true),"coverage":coverage,"looks":result})+";")
	file.close()
	print("CURRENT LOOKS: ",counts)
	for scope in ["britain","world"]+FACETS:
		var line := ""
		for status in STATUSES: line += "%s %.1f%%  " % [status,100.0*float(coverage[scope].placements.get(status,0))/maxf(coverage[scope].total,1)]
		print("%s COVERAGE (placements): final %.1f%%  %s" % [scope.to_upper(),coverage[scope].final,line])
	print("WORLD GRAPHICS: final %.1f%% of %d placed graphics (%d open)" % [coverage.graphics.final,coverage.graphics.total,coverage.graphics.open])
	print("BRITAIN GRAPHICS: final %.1f%% of %d placed graphics (%d open)" % [coverage.britain_graphics.final,coverage.britain_graphics.total,coverage.britain_graphics.open])
	# The worklist: every placed family with graphics not yet at final quality.
	if args.has("open"):
		var open := open_work(catalog,result)
		var out := FileAccess.open(args.open,FileAccess.WRITE)
		out.store_string(JSON.stringify({"generated":Time.get_datetime_string_from_system(true),"families":open},"	"))
		out.close()
		print("OPEN WORK: %d families, %d graphics" % [open.size(),coverage.graphics.open])
	quit(0)

const STATUSES := ["scan","crafted","owner","kit","built","guess","original","hidden"]
const FINAL := ["scan","crafted","owner","hidden"]
const FACETS := ["Felucca","Trammel","Ilshenar","Malas","Tokuno","TerMur"]

# Placements of a graphic across the world. Felucca largely repeats Trammel,
# so the catalogue's "world" leaves it out; Felucca-only graphics still count.
static func placed(item: Dictionary) -> int:
	return maxi(int(item.get("world",0)),int(item.get("felucca",0)))

# Final-quality shares by placements in Britain, the world and each facet,
# and by distinct placed graphics.
static func coverage_for(catalog: Dictionary, looks: Dictionary) -> Dictionary:
	var scopes := {}
	for scope in ["britain","world"]+FACETS: scopes[scope] = {"placements":{},"total":0}
	var graphics := {"total":0,"open":0,"final":0.0}
	var britain_graphics := {"total":0,"open":0,"final":0.0}
	for item in catalog.items:
		var status := str(looks[str(int(item.id))].status)
		var weights := {"britain":int(item.get("britain",0))+int(item.get("decoration",0)),"world":placed(item)}
		var facets: Dictionary = item.get("facets",{}) if item.get("facets") is Dictionary else {}
		for facet in FACETS: weights[facet] = int(facets.get(facet,0))
		for scope in weights:
			if weights[scope] == 0: continue
			scopes[scope].placements[status] = int(scopes[scope].placements.get(status,0))+weights[scope]
			scopes[scope].total += weights[scope]
		if weights.world > 0:
			graphics.total += 1
			if not status in FINAL: graphics.open += 1
		if weights.britain > 0:
			britain_graphics.total += 1
			if not status in FINAL: britain_graphics.open += 1
	for scope in scopes:
		var done := 0
		for status in FINAL: done += int(scopes[scope].placements.get(status,0))
		scopes[scope].final = snappedf(100.0*done/maxf(scopes[scope].total,1),0.1)
	graphics.final = snappedf(100.0*(graphics.total-graphics.open)/maxf(graphics.total,1),0.1)
	britain_graphics.final = snappedf(100.0*(britain_graphics.total-britain_graphics.open)/maxf(britain_graphics.total,1),0.1)
	scopes["graphics"] = graphics
	scopes["britain_graphics"] = britain_graphics
	return scopes

# Open families, most placed first: name, category, open graphic ids with
# their current status, open placements overall and per facet.
static func open_work(catalog: Dictionary, looks: Dictionary) -> Array:
	var items := {}
	for item in catalog.items: items[int(item.id)] = item
	var rows := []
	for family in catalog.families:
		var open_ids := []
		var statuses := {}
		var total := 0
		var facets := {}
		for id in family.ids:
			var item: Dictionary = items.get(int(id),{})
			var status := str(looks.get(str(int(id)),{}).get("status","original"))
			if item.is_empty() or placed(item) == 0 or status in FINAL: continue
			open_ids.append(int(id))
			statuses[status] = int(statuses.get(status,0))+1
			total += placed(item)
			var per: Dictionary = item.get("facets",{}) if item.get("facets") is Dictionary else {}
			for facet in per: facets[facet] = int(facets.get(facet,0))+int(per[facet])
		if open_ids.is_empty(): continue
		rows.append({"key":family.key,"name":family.name,"category":family.category,"ids":open_ids,"statuses":statuses,"placements":total,"britain":int(family.get("britain",0)),"facets":facets})
	rows.sort_custom(func(a,b): return a.placements > b.placements)
	return rows

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
	if asset.begins_with("Reduced/"): return {"status":"scan","detail":"Poly Haven photoscan (CC0), one variant: "+asset.get_file().get_basename()}
	if asset.begins_with("Objaverse/"): return {"status":"scan","detail":"Sketchfab scan/PBR (see Art/Objaverse/NOTICE.md): "+asset.get_file().get_basename()}
	var vendor := "Poly Haven" if asset.begins_with("PolyHaven/") else ("Kenney" if asset.begins_with("Kenney/") else ("Medieval kit" if asset.begins_with("MedievalKit/") else "Quaternius"))
	return {"status":"kit","detail":"%s (CC0): %s" % [vendor,asset.get_file().get_basename()]}

func look_for(id: int,item: Dictionary,audited: Dictionary,server: Dictionary) -> Dictionary:
	# Shop and guild sign boards placed by decoration (WorldItems.definition).
	if id >= 2979 and id <= 3086 and not "broken" in str(item.name) and not "bench" in str(item.name) and not "signpost" in str(item.name): return {"status":"crafted","detail":"hanging sign board with painted face"}
	# The catalogue shows empty tiledata names as "unnamed"; the client sees "".
	var name := "" if str(item.name) == "unnamed" else str(item.name)
	# No original artwork (or a blank strip under 3 px): the native client draws nothing.
	if (item.get("art") == null or int(item.art[1]) < 3) and audited.is_empty() and server.is_empty(): return {"status":"hidden","detail":"no original artwork (the native client draws nothing)"}
	if item.flags.has("wearable") and item.world == 0:
		if preload("res://Presentation/HumanWardrobe.gd").mapped(id):
			return {"status":"kit","detail":"MakeHuman CC0: fitted human wardrobe category substitute"}
		return {"status":"original","detail":"worn model outside the first human wardrobe batch"}
	# Name-keyed scan replacements apply to map statics and server items alike.
	var found: Dictionary = preload("res://Presentation/PropReplacements.gd").entry_for(name,id)
	var found_rule: Dictionary = audited if not audited.is_empty() else Rules.resolve(id,{"name":name,"height":item.height,"flags":flag_bits(item.flags)})
	if not found.is_empty() and not preload("res://Presentation/PropReplacements.gd").applies(str(found_rule.get("kind","prop"))): found = {}
	if found.is_empty() and preload("res://Presentation/PropReplacements.gd").applies(str(found_rule.get("kind","prop"))) and preload("res://Presentation/CraftedProps.gd").handles(name):
		return {"status":"crafted","detail":"built from photoscanned timber, iron, cloth and stone"}
	if not found.is_empty():
		var model := str(found.get("model",found.get("models",[""])[0]))
		if found.get("hide",false): return {"status":"scan","detail":"part drawn by the scanned model of its whole object"}
		if model.begins_with("Reduced/"): return pack(model)
		return pack(("Objaverse/%s/%s.glb" % [model.trim_prefix("Objaverse/"),model.trim_prefix("Objaverse/")]) if model.begins_with("Objaverse/") else "PolyHaven/%s/%s" % [model,model])
	var review: Dictionary = Reviewed.entry(id)
	# Counters are built cell by cell in photoscanned timber whatever their review says.
	if str(review.get("kind",audited.get("kind",""))) == "counter": return {"status":"crafted","detail":"panelled counter in photoscanned timber"}
	if str(review.get("kind","")) == "bench" and not ("stone" in name.to_lower() or "marble" in name.to_lower()): return pack("Objaverse/bench_scan/bench_scan.glb")
	if review.has("asset"):
		var reviewed := pack(str(review.asset))
		reviewed.detail += " (reviewed)"
		return reviewed
	if review.has("construction") or str(review.get("renderer","")) == "shared-construction":
		var reviewed_kind := str(review.get("kind",audited.get("kind","")))
		if reviewed_kind in ["wall","window","corner","trim","beam","gable","arch","floor","landing","stairs","roof","bridge"] or str(review.get("construction","")) in ["wall","bridge","facade"]:
			return {"status":"crafted","detail":"built in code with photoscanned surfaces (reviewed)"}
		return {"status":"built","detail":"built in code (reviewed)"}
	# Map statics draw from their static rule even if the server decoration
	# also places a few copies; only server-only items use the item stand-ins.
	if not server.is_empty() and audited.is_empty() and int(item.get("britain",0)) == 0 and int(item.get("world",0)) == 0 and int(item.get("felucca",0)) <= int(item.get("decoration",0)):
		var family := str(server.get("family",""))
		if family == "door": return {"status":"crafted","detail":"door leaf in photoscanned timber and iron"}
		# Decoration drawn by the static builders (WorldItems mirrors Reconstruction).
		var built_rule := Rules.resolve(id,{"name":name,"height":item.height,"flags":flag_bits(item.flags)})
		if str(built_rule.get("kind","")) in ["effect","decal"] or (str(built_rule.get("kind","")) == "vine" and built_rule.has("builder")) or (str(built_rule.get("kind","")) == "fence" and preload("res://Presentation/FenceBuilder.gd").handles(name)):
			return {"status":"crafted","detail":"built from photoscanned materials / effects: "+str(built_rule.kind)}
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
	if kind == "fence" and preload("res://Presentation/FenceBuilder.gd").handles(name): return {"status":"crafted","detail":"fence built in photoscanned timber, stone and wrought iron"}
	if kind == "vine" and str(rule.get("builder","")) == "vine": return {"status":"crafted","detail":"vine stems in photoscanned bark with scanned ivy"}
	if kind == "arch": return {"status":"crafted","detail":"arch pier/archway built in photoscanned masonry"}
	if kind == "post": return {"status":"crafted","detail":"post in photoscanned timber or masonry"}
	if kind in FITTED: return pack(asset)
	var named := name.to_lower()
	if kind == "counter": return {"status":"crafted","detail":"panelled counter in photoscanned timber"}
	if kind == "carpet": return {"status":"crafted","detail":"woven rug from photoscanned fabric"}
	if kind == "door": return {"status":"crafted","detail":"door leaf in photoscanned timber and iron"}
	if kind == "effect": return {"status":"crafted","detail":"particle and glow effect: "+str(rule.get("effect",""))}
	if kind == "decal": return {"status":"crafted","detail":"ground decal on a photoscanned surface: "+str(rule.get("decal",""))}
	if kind == "table" and not ("stone" in named or "marble" in named or "sandstone" in named): return pack("Objaverse/table_wood_b/table_wood_b.glb")
	if kind == "bed": return pack("PolyHaven/GothicBed_01/GothicBed_01_1k.gltf")
	if kind == "bench" and not ("stone" in named or "marble" in named): return pack("Objaverse/bench_scan/bench_scan.glb")
	if kind in ["table","bench"]: return {"status":"crafted","detail":"stone furniture built in photoscanned masonry"}
	# Architecture and water are built from photoscanned surface sets.
	if kind in ["wall","window","corner","trim","beam","gable","pillar","floor","landing","stairs","roof","chimney","water","lava","waterfall","palisade","planter"]:
		return {"status":"crafted","detail":"built in code with photoscanned surfaces: "+kind}
	if kind in BUILT:
		var detail := "built in code: "+kind
		if kind == "window": detail += " + Medieval kit shutters"
		return {"status":"built","detail":detail}
	return {"status":"original","detail":"no 3D look yet ("+kind+")"}
