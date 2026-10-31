extends SceneTree
const Visual=preload("res://Presentation/CreatureVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var family:="bruins"
var checks:=0
var failures:=0
var samples: Array=[]
var terrain: Array=[]
var models: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func run() -> void:
	var path:="res://local-art/creatures/"+family+"/preparation.json"
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for record: Dictionary in preparation.models:
		if record.status!="prepared":continue
		var before:=failures
		var lengths: Dictionary={}
		for treatment in ["original","rounded","modern"]:
			var actor:=Visual.new();actor.entry=record;actor.treatment=treatment;root.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false
			var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
			var arrays:=mesh.mesh.surface_get_arrays(0);var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var valid:=true
			for i in int(weights.size()/4):
				var total:=0.
				for j in 4:total+=weights[i*4+j];valid=valid and is_finite(weights[i*4+j]) and weights[i*4+j]>=0.
				valid=valid and absf(total-1.)<.0001
			check(valid and rig.get_bone_count()==int(record.stats.original.bones),"Original rig and normalised finite weights: "+str(record.kind))
			for clip: StringName in actor.animator.get_animation_list():
				if clip=="RESET":continue
				var length: float=actor.animator.get_animation(clip).length
				if treatment=="original":lengths[clip]=length
				check(length>0. and is_equal_approx(length,float(lengths.get(clip,-1.))),"Treatment retains source/category timing: "+str(clip))
				for phase in [0.,.167,.333,.5,.667,.833,.99]:
					actor.play(clip,0.);actor.animator.seek(length*phase,true);actor.animator.pause()
					for frame in 2:await process_frame
					var bounds:=Geometry.deformed_bounds(mesh,rig)
					check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.05 and bounds.size.length()<float(record.stats.original.height_m)*8.,"Finite bounded deformed mesh: "+str(record.kind)+" / "+str(clip))
					check(absf(bounds.position.y)<.06,"Sampled flat-floor clearance remains within 60 mm")
					check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Visual clips never move native world coordinates")
					samples.append({"kind":record.kind,"treatment":treatment,"clip":str(clip),"phase":phase,"lowest_vertex_m":bounds.position.y})
			for identity: Dictionary in record.bodies:
				for hue in [0,53,0x8000|53]:
					actor.apply_identity(int(identity.body),hue)
					check(actor.native_body==int(identity.body) and actor.native_hue==hue,"Exact native body and raw dye flags retained")
					check(actor.action_profile==str(identity.get("native_profile",record.profile)),"Native server body class selects the correct animation group")
			actor.free()
		var hashes: Dictionary={}
		for treatment in ["original","rounded","modern"]:hashes[treatment]=FileAccess.get_sha256("res://local-art/creatures/"+str(record.kind)+"-"+treatment+".gltf")
		models.append({"kind":record.kind,"passed":before==failures,"asset_sha256":hashes})
	var ground:=StaticBody3D.new();root.add_child(ground);var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,.1,30);collision.shape=box;collision.position.y=-.05;ground.add_child(collision)
	for record: Dictionary in preparation.models:
		if record.status!="prepared":continue
		var actor:=Visual.new();actor.entry=record;root.add_child(actor);actor.set_process(false)
		if actor.contact.feet.is_empty():
			terrain.append({"kind":record.kind,"support":"No compatible stance chain configured; not terrain-certified"});actor.free();continue
		for slope in [Vector2.ZERO,Vector2(.08,0),Vector2(0,.06)]:
			ground.rotation=Vector3(slope.x,0,slope.y);actor.play("Idle",0.);actor.animator.seek(0.,true);actor.animator.pause()
			for frame in 25:await physics_frame;await process_frame
			var valid:=true
			for error: float in actor.contact.errors:valid=valid and error<.05
			check(valid,"Configured stance soles remain supported within 50 mm")
			terrain.append({"kind":record.kind,"slope":str(slope),"configured_feet":actor.contact.feet.size(),"measured_errors_m":actor.contact.errors.duplicate()})
		for identity: Dictionary in record.bodies:
			actor.apply_identity(int(identity.body),0)
			var expected_scale:=actor.model.scale
			for frame in 8:await physics_frame;await process_frame
			check(actor.model.scale.is_equal_approx(expected_scale),"Terrain adjustment retains native body proportions: "+str(identity.body))
		actor.free()
	ground.free()
	check(not models.is_empty(),"At least one source model exercised")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/"+family))
	var file:=FileAccess.open("res://../outputs/creatures/"+family+"/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"family":family,"checks":checks,"failures":failures,"models":models,"skin_samples":samples,"terrain_samples":terrain,"scope":"Finite actual source/refined skin samples, timing, raw identities and configured collision support. No native server or universal terrain/choreography evidence."},"\t"));file.close()
	print("CREATURE POSES / ",family,": ",checks-failures," / ",checks,"; ",samples.size()," deformed samples");quit(1 if failures else 0)
