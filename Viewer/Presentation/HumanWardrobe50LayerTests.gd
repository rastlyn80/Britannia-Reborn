extends SceneTree
## Native layer interactions and the actual selected resources on both rigs.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func mesh_for(human: Node3D,key: String) -> MeshInstance3D:
	for mesh: MeshInstance3D in human.parts:
		if mesh.name=="Extra_"+key:return mesh
	return null
func run() -> void:
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;root.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
		var human: Node3D=actor.human_visual;human.set_process(false)
		for mounted in [false,true]:
			var worn: Array=[{"id":0x1517,"layer":5},{"id":0x1539,"layer":4},{"id":0x170b,"layer":3},{"id":0x1415,"layer":13},{"id":0x1410,"layer":19},{"id":0x1f7b,"layer":17},{"id":0x230d,"layer":22,"hue":1153},{"id":0x203d,"layer":11,"hue":1147}]
			if mounted:worn.append({"id":0x3e9f,"layer":25})
			actor.appearance_seen=false;actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
			var dress:=mesh_for(human,"gilded_dress")
			check(dress!=null and dress.mesh.resource_path.contains("gilded_dress"+("_riding" if mounted else "")+".glb"),"Native dress selects its real foot/riding resource")
			check(not human.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Free_robe") or p.name in ["Extra_shirt","Extra_doublet","Extra_plate_torso","Extra_plate_arms"]),"Outer garment replaces obscured upper layers without duplicate robe")
			check((int(human.get_meta("body_mask_bits"))&8)!=0 and human.native_cosmetics.hair_id==0x203d and human.native_cosmetics.hair_hue==1147,"Existing robe mask and independent ponytail identity")
			check(human.stance_clip("Run")==("Rider_Run" if mounted else "Jog"),"Native outer garment selects cloth-safe or rider locomotion")
			worn=[{"id":0x1517,"layer":5},{"id":0x2309,"layer":20,"hue":0x8035},{"id":0x203c,"layer":11,"hue":1147},{"id":0x1539,"layer":4},{"id":0x170b,"layer":3}]
			if mounted:worn.append({"id":0x3e9f,"layer":25})
			actor.appearance_seen=false;actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
			check(mesh_for(human,"fur_cape")!=null and human.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Extra_hair_long_layered_cloak")),"Native fur cape retains its independent long-hair layer")
		actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},[{"id":0x26af,"layer":3},{"id":0x1539,"layer":4}])
		check(mesh_for(human,"arcane_boots")!=null and (int(human.get_meta("body_mask_bits"))&4)!=0 and not human.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Free_boots")),"Native fitted boots reuse foot mask without duplicate boots")
		actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},[{"id":0x2fb8,"layer":6},{"id":0x203b,"layer":11,"hue":1147},{"id":0x204c,"layer":16,"hue":1109}])
		check(human.native_cosmetics.hair_id==0x203b and human.native_cosmetics.beard_id==0x204c and human.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Extra_beard_")),"Spectacles preserve native scalp/beard identity and visible beard")
		actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},[{"id":0xa3ea,"layer":6},{"id":0x203d,"layer":11,"hue":1147},{"id":0x204c,"layer":16,"hue":1109}])
		check(human.native_cosmetics.beard_id==0x204c and human.native_cosmetics.beard_hue==1109 and not human.parts.any(func(p: MeshInstance3D):return p.name.begins_with("Extra_beard_")),"Closed pumpkin mask conceals beard mesh while retaining native beard properties")
		actor.free()
	print("WARDROBE50 LAYERS: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
