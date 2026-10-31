extends SceneTree
## Test actual avatar/skin routes, including legacy raw identity preservation.
const Registry=preload("res://Presentation/EquineRegistry.gd")
const Mounts=preload("res://Presentation/MountVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
var samples: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func run() -> void:
	var indexed: Array=Registry.BODIES.keys()+Registry.COMPATIBILITY.keys()+Registry.DISTINCT.keys()
	check(indexed.size()==26,"Original indexed denominator stays 26")
	for body: int in indexed:check(Mounts.supports_body(body),"Every indexed body has installed presentation")
	var view:=preload("res://Presentation/WorldItems.gd").new();root.add_child(view)
	for body: int in Registry.COMPATIBILITY:
		check(int(Registry.COMPATIBILITY[body][2])==0,"Compatibility artwork invents no ridden item")
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=body;root.add_child(actor);actor.set_physics_process(false)
		for hue in [0,53,0x8000|53,0x4001]:
			actor.apply_server_appearance({"body":body,"hue":hue},[])
			var horse: Node3D=actor.horse_visual
			check(horse!=null and actor.human_visual==null and horse.native_body==body and horse.native_hue==hue and horse.native_mount_item==0,"Legacy appearance retains original body/hue and stays loose")
			check(bool(horse.get_meta("equine_profile").get("compatibility",false)),"Compatibility status remains inspectable")
			for clip in ["idle","walk","gallop","rear","hit","death"]:
				horse.current_clip=clip;horse.animator.play(clip,0.)
				for phase in [0.,.35,.7,.99]:
					horse.animator.seek(horse.animator.current_animation_length*phase,true);horse.animator.pause()
					for frame in 2:await process_frame
					var mesh: MeshInstance3D=horse.model.find_children("*","MeshInstance3D",true,false)[0]
					var bounds:=Geometry.deformed_bounds(mesh,horse.skeleton)
					check(bounds.position.is_finite() and bounds.size.length()>.4 and bounds.size.length()<5.,"Compatibility skin stays finite/bounded")
					check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"No visual action moves the authoritative root")
					samples.append({"body":body,"hue":hue,"clip":clip,"phase":phase})
		actor.free()
		var corpse_root:=Node3D.new();root.add_child(corpse_root)
		check(view._equine_corpse(corpse_root,{"amount":body,"hue":53},0x40012345),"Legacy corpse preserves its source identity")
		corpse_root.free()
	view.hint.free();view.free()
	# Switching live layer 25 must rebuild between opaque and ethereal source
	# rigs, but colour changes within the same form must retain its sockets.
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;root.add_child(actor);actor.set_physics_process(false)
		for item in [0x3ead,0x3e9c,0x3ead,0x3e9c]:
			actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},[{"id":item,"layer":25,"hue":0x4001}])
			check(actor.horse_visual.kind==Mounts.kind(0x84,item),"Ethereal/ordinary ki-rin switches to exact form")
			check(actor.horse_visual.contact.feet.size()==4,"Ethereal ki-rin retains all four foot chains")
			var id: int=actor.horse_visual.skeleton.get_instance_id()
			actor.apply_server_appearance({"body":actor.initial_body},[{"id":item,"layer":25,"hue":0x8000|53}])
			check(actor.horse_visual.skeleton.get_instance_id()==id and actor.horse_visual.native_hue==(0x8000|53),"Raw dye update keeps the rig and native flags")
		actor.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/equines"))
	var file:=FileAccess.open("res://../outputs/equines/completion-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"skin_samples":samples,"scope":"Offline actual avatar, deformed skin, native raw identity, corpse and form-switch checks. Compatibility routes are not active server classes or riding permissions."},"\t"));file.close()
	print("EQUINE COMPLETION: ",checks-failures," / ",checks,"; ",samples.size()," deformed samples");quit(1 if failures else 0)
