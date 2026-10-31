extends SceneTree
## Exercise the optional long-toe solver on actual animated source skins.
const Visual=preload("res://Presentation/CreatureVisual.gd")
var family:="dragons"
var checks:=0
var failures:=0
var samples: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/"+family+"/preparation.json"))
	var ground:=StaticBody3D.new();root.add_child(ground)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100.,.1,100.);collision.shape=box;collision.position.y=-.05;ground.add_child(collision)
	var tested: Array=[]
	for record: Dictionary in preparation.models:
		if record.status!="prepared":continue
		var actor:=Visual.new();actor.entry=record;root.add_child(actor);actor.set_process(false)
		if not actor.contact.align_skinned_soles:actor.free();continue
		var measured:=0
		for slope in [Vector2.ZERO,Vector2(.08,0),Vector2(0,.06)]:
			ground.rotation=Vector3(slope.x,0.,slope.y)
			for clip in ["Walk","Run","Attack"]:
				for phase in [0.,.25,.5,.75]:
					actor.play(clip,0.);actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause()
					for frame in 6:await physics_frame;await process_frame
					var valid:=true
					for error: float in actor.contact.errors:valid=valid and is_finite(error) and error<.05
					if not actor.contact.errors.is_empty():
						measured+=1;check(valid,"Animated stance soles within 50 mm: "+str(record.kind)+" / "+clip+" / "+str(phase))
					check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Contact correction preserves native entity coordinates")
					samples.append({"kind":record.kind,"clip":clip,"phase":phase,"slope":str(slope),"measured_errors_m":actor.contact.errors.duplicate()})
		check(measured>0,"Actual animated contact samples exist: "+str(record.kind))
		tested.append({"kind":record.kind,"asset_sha256":FileAccess.get_sha256("res://local-art/creatures/"+str(record.kind)+"-modern.gltf"),"import_sha256":FileAccess.get_sha256("res://local-art/creatures/"+str(record.kind)+"-modern.gltf.import")});actor.free()
	ground.free()
	var inputs: Dictionary={}
	for file in ["CreatureContactTests.gd","CreatureVisual.gd","SourceMountContact.gd","FootContact.gd"]:inputs[file]=FileAccess.get_sha256("res://Presentation/"+file)
	var output:=FileAccess.open("res://../outputs/creatures/"+family+"/contact-motion.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"models":tested,"samples":samples,"runtime_sha256":inputs,"scope":"Long-toe solver on bounded animated stance samples and three planes; no arbitrary-terrain certification."},"\t"));output.close()
	print("CREATURE CONTACT MOTION / ",family,": ",checks-failures," / ",checks);quit(1 if failures else 0)
