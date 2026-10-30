extends "res://Presentation/HumanWardrobe50LayerTests.gd"
## Native layers and selected split riding assets, independent cosmetic hues.
func run() -> void:
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../scripts/human-coverage-recipes.json"))
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;root.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
		var human: Node3D=actor.human_visual;human.set_process(false)
		for mounted in [false,true]:
			for row: Dictionary in definitions.assets:
				if row.kind!="expansion65":continue
				var layer: int={"head":6,"weapon":1,"shield":2,"feet":3,"legs":4,"shirt":5,"hands":7,"necklace":10,"gorget":10,"waist":12,"torso":13,"arms":19,"cloak":20,"backpack":21,"outer":22,"outer_legs":23,"talisman":9}.get(row.slot,0)
				var worn: Array=[{"id":0x1539,"layer":4},{"id":0x170b,"layer":3},{"id":0x1517,"layer":5},{"id":0x203d,"layer":11,"hue":1147},{"id":0x2040,"layer":16,"hue":1109},{"id":int(row.graphics[0]),"layer":layer,"hue":53}]
				if mounted:worn.append({"id":0x3e9f,"layer":25})
				actor.appearance_seen=false;actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
				var piece:=mesh_for(human,row.key)
				check(piece!=null and human.missing_art.is_empty() and human.unsupported_items.is_empty(),"Native layer/resource "+row.key)
				check(human.native_cosmetics.hair_id==0x203d and human.native_cosmetics.hair_hue==1147 and human.native_cosmetics.beard_id==0x2040 and human.native_cosmetics.beard_hue==1109,"Independent native cosmetics "+row.key)
				if row.has("riding_base") and piece!=null:check(piece.mesh.resource_path.contains(row.key+("_riding" if mounted else "")+".glb"),"Actual foot/riding selection "+row.key)
				if row.slot=="outer":check(not human.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Free_robe") or p.name=="Extra_shirt"),"No duplicate/obscured robe layer "+row.key)
				if row.get("integrated_lining",false):check(not human.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Extra_armour_undercoat")),"Integrated matching cloth without duplicate undercoat "+row.key)
		actor.free()
	print("WARDROBE65 LAYERS: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
