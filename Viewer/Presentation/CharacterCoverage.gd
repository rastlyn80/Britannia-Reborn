extends SceneTree
## Coverage is native-ID coverage, separate from mesh fidelity and animation QA.
const Wardrobe=preload("res://Presentation/HumanWardrobe.gd")
func _initialize() -> void:
	var catalog_path:="res://../outputs/item-catalog/catalog.js"
	var out:="res://../outputs/third-dawn/character-port-coverage.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--catalog="): catalog_path=arg.substr(10)
		if arg.begins_with("--out="): out=arg.substr(6)
	var text:=FileAccess.get_file_as_string(catalog_path).strip_edges().trim_prefix("window.CATALOG=").trim_suffix(";")
	var catalog: Variant=JSON.parse_string(text)
	if not catalog is Dictionary:
		push_error("Build the local item catalogue before auditing coverage")
		quit(1);return
	var records: Array=[]
	var mapped:=0
	for item: Dictionary in catalog.items:
		if not "wearable" in item.get("flags",[]): continue
		var id:=int(item.id)
		var covered:=Wardrobe.mapped(id)
		if covered: mapped+=1
		var current_parts: Array[String]=[]
		var mask: int=Wardrobe.GRAPHICS.get(id,0)
		for index in Wardrobe.SLOTS.size():
			if mask&(1<<index):current_parts.append(Wardrobe.SLOTS[index])
		if Wardrobe.EXTRA.has(id):current_parts.append(str(Wardrobe.EXTRA[id][1]))
		if Wardrobe.HAIR.has(id):current_parts.append("hair_"+str(Wardrobe.HAIR[id]))
		if Wardrobe.BEARDS.has(id):
			for family in Wardrobe.BEARDS[id]:current_parts.append("beard_"+str(family))
		records.append({"id":id,"name":item.name,"layer":item.get("layer"),"status":"category replacement" if covered else "missing","current_parts":", ".join(current_parts),"source_animation_reference":item.get("anim",0)})
	var hair: Array=[]
	for id in [0x203b,0x203c,0x203d,0x2044,0x2045,0x2046,0x2047,0x2048,0x2049,0x204a]:
		hair.append({"id":id,"status":"family replacement" if Wardrobe.HAIR.has(id) else "short-hair fallback; native identity preserved"})
	var report:={"generated":Time.get_datetime_string_from_system(true),"wearables":{"catalogued_graphics":records.size(),"mapped_graphics":mapped,"records":records},"human_hair":hair,"human_beard_ids":Wardrobe.BEARDS.keys(),"body_art":{"400":"male human","401":"female human"},"animation_transport":["0x6e classic action/frame/repeat/reverse/delay","0xe2 new action/frame/delay"],"server_action_playback":[],"locomotion_baseline":["Idle","Walk","Run"],"scope":"Local indexed client tile graphics, not a complete census of equippable server item classes. Category art, individual mesh quality and animation coverage are separate. Non-human bodies, exact head styles and full action playback remain open."}
	var file:=FileAccess.open(out,FileAccess.WRITE)
	report.animation_transport=["0x6e classic action/frame/repeat/reverse/delay","0xe2 type/subaction/variation; historical aliases retained"]
	report.server_action_playback={"bodies":[400,401],"classic_groups":preload("res://Presentation/HumanActions.gd").CLASSIC.keys(),"new_types":[0,3,4,11],"new_attack_subactions":[0,3,4,5,6,7,8],"status":"human category replacements; mounts and unsupported requests excluded"}
	report.server_action_playback.classic_replacements=preload("res://Presentation/HumanActions.gd").CLASSIC.duplicate()
	var requests: Dictionary={}
	for kind in range(32):
		for subaction in range(-1,35):
			var replacement:=preload("res://Presentation/HumanActions.gd").resolve({"body":400,"protocol":"new","type":kind,"subaction":subaction})
			if not replacement.is_empty():requests["%d:%d" % [kind,subaction]]=replacement
	report.server_action_playback.new_replacements=requests
	var categories: Array=Wardrobe.SLOTS.duplicate()
	for entry: Array in Wardrobe.EXTRA.values():
		if not categories.has(entry[1]):categories.append(entry[1])
	report.equipment_categories=categories
	report.prepared_locomotion=["Walk","Jog","Run","Sprint"]
	report.scope+=" Prepared human action playback is a subset; see HUMAN_MOTION_PASS.md."
	report.source_catalog = {"path":catalog_path,"sha256":FileAccess.get_sha256(catalog_path),"item_count":catalog.items.size()}
	file.store_string(JSON.stringify(report,"\t"))
	print("CHARACTER COVERAGE: ",mapped," / ",records.size()," indexed wearable graphics have category replacements; 2 body arts; human action subset installed")
	quit(0)
