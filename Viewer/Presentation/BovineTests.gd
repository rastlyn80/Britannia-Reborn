extends SceneTree
const Registry=preload("res://Presentation/AnimalVisual.gd")
const Mounts=preload("res://Presentation/MountVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
var samples: Array=[]
var terrain: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func run() -> void:
	for body: int in Registry.BODIES:
		var lengths: Dictionary={}
		for treatment in ["original","rounded","modern"]:
			var actor:=Registry.create(body);actor.treatment=treatment;root.add_child(actor);actor.apply_identity(body,0);actor.set_physics_process(false);actor.contact.enabled=false
			var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
			var arrays:=mesh.mesh.surface_get_arrays(0);var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var valid:=true
			for i in int(weights.size()/4):
				var total:=0.
				for j in 4:total+=weights[i*4+j];valid=valid and is_finite(weights[i*4+j]) and weights[i*4+j]>=0.
				valid=valid and absf(total-1.)<.0001
			check(valid and rig.get_bone_count()==32,"Imported native rig has normalized finite weights")
			for clip in ["Idle","Walk","Run","Eat","Attack","Hit","Death","Fidget","LieDown"]:
				check(actor.animator.has_animation(clip),"Native source/category survives import")
				var length: float=actor.animator.get_animation(clip).length
				if treatment=="original":lengths[clip]=length
				check(is_equal_approx(length,lengths[clip]),"Treatments retain identical source timing; native Eat is not replaced")
				for phase in [0.,.125,.25,.375,.5,.625,.75,.875,.99]:
					actor.play(clip,0.);actor.animator.seek(length*phase,true);actor.animator.pause()
					for frame in 2:await process_frame
					var bounds:=Geometry.deformed_bounds(mesh,rig)
					check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.4 and bounds.size.length()<4.,"Skin stays finite/bounded")
					check(absf(bounds.position.y)<.035,"Flat source skin remains within 35 mm of support")
					check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Animation never changes native world coordinates")
					samples.append({"body":body,"treatment":treatment,"clip":clip,"phase":phase,"lowest_vertex_m":bounds.position.y})
			if treatment=="modern":
				for hue in [0,53,0x8000|53,0x901]:
					var id:=rig.get_instance_id();actor.apply_identity(body,hue)
					check(actor.native_body==body and actor.native_hue==hue and rig.get_instance_id()==id,"Native identity/hue bits survive without rig rebuild")
					var mat:=mesh.get_surface_override_material(0) as ShaderMaterial
					check(bool(mat.get_shader_parameter("dark_patches"))==(body==0xd8),"Only the native black/white cow uses dark patch interpretation")
			actor.free()
		var avatar:=preload("res://Presentation/HumanAvatar.gd").new();avatar.initial_body=body;root.add_child(avatar);avatar.set_physics_process(false);avatar.apply_server_appearance({"body":body,"hue":53},[])
		check(avatar.horse_visual!=null and avatar.human_visual==null and avatar.horse_visual.kind==Registry.kind(body),"Actual native avatar selects the bovine source rig")
		if body in [0xd8,0xe7]:
			check(avatar.receive_native_action({"protocol":"classic","action":8,"frames":0,"repeat_count":3}),"Native Cow.Tip signature is consumed")
			check(not avatar.horse_visual.dead and avatar.horse_visual.current_clip=="LieDown","A tipped living cow is not marked dead")
			avatar.horse_visual.action_remaining=.001;avatar.horse_visual._process(.01)
			check(avatar.horse_visual.current_clip=="Idle" and not avatar.horse_visual.dead,"A tipped cow recovers to idle")
		avatar.free()
	var ground:=StaticBody3D.new();root.add_child(ground);var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.1,20);collision.shape=box;collision.position.y=-.05;ground.add_child(collision)
	for body: int in Registry.BODIES:
		var actor:=Registry.create(body);root.add_child(actor);actor.apply_identity(body,0)
		for slope in [Vector2.ZERO,Vector2(.08,0),Vector2(0,.06)]:
			ground.rotation=Vector3(slope.x,0,slope.y);actor.play("Idle",0.);actor.animator.seek(0.,true);actor.animator.pause()
			for frame in 25:await physics_frame;await process_frame
			var good: bool=actor.contact.contacts.size()==4 and actor.contact.errors.size()==4
			for error: float in actor.contact.errors:good=good and error<.05
			check(good,"Four real stance soles retain support within 50 mm: "+str([body,slope,actor.contact.errors]))
			terrain.append({"body":body,"slope":str(slope),"errors_m":actor.contact.errors.duplicate()})
		actor.free()
	ground.free()
	var presenter:=preload("res://Presentation/WorldItems.gd").new();root.add_child(presenter)
	for body: int in Registry.BODIES:
		var holder:=Node3D.new();root.add_child(holder)
		check(presenter._equine_corpse(holder,{"amount":body,"hue":53},0x40012345),"Native bovine corpse amount selects its source death art")
		check(holder.get_node("CorpseVisual").dead,"Corpse remains dead, independent of the live cow tip signature")
		holder.free()
	presenter.hint.free();presenter.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/bovines"))
	var file:=FileAccess.open("res://../outputs/bovines/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"skin_samples":samples,"terrain_samples":terrain,"scope":"Actual source skin/timing, body/hue routing, cow-tip recovery, held corpses and real collision support. Finite offline samples; native interactions tested separately."},"\t"));file.close()
	print("BOVINE TESTS: ",checks-failures," / ",checks,"; ",samples.size()," skin poses");quit(1 if failures else 0)
