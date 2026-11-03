extends SceneTree
## Saved candidate actors: native action timing, raw hues and material/skin reuse.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(120.).timeout.connect(func():push_error("Source-preserving action deadline");quit(1))
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run() -> void:
	var path:="res://local-art/creatures/source_preserving/preparation.json"
	var prepared: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var rows: Array=[]
	Registry.load_index();var accepted_pin:=FileAccess.get_sha256("res://local-art/creatures/accepted-index.json")
	for entry: Dictionary in prepared.models:
		var body:=int(entry.bodies[0].body);var previous: Variant=Registry.entries.get(body,null)
		var activated:=FileAccess.file_exists("res://local-art/creatures/source_preserving/local-presentation.json") and body not in [193,272]
		if activated:
			check(Registry.supports_body(body),"Normal client registry supports the activated body")
			var registered:=Registry.entry(body)
			check(registered.kind==entry.kind and registered.assets==entry.assets and registered.presentation_script==entry.presentation_script,"Normal client uses the exact checked presentation")
		else:Registry.entries[body]=entry
		var actor: Node3D=Registry.create(body);root.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.active=false
		actor.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
		var data:=mesh.mesh.surface_get_arrays(0)
		check((data[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()==int(entry.saved_scenes.modern.vertices),"Actual actor uses the baked skin without a second subdivision: "+str(entry.kind))
		check(actor.skeleton.get_bone_count()==int(entry.stats.original.bones),"Complete original rig retained: "+str(entry.kind))
		for hue in [0,2101,0x8515]:
			actor.apply_identity(body,hue)
			check(actor.native_body==body and actor.native_hue==hue,"Native identity/raw hue retained: "+str(entry.kind))
			var material:=mesh.get_active_material(0) as ShaderMaterial
			check(material!=null and bool(material.get_shader_parameter("partial_hue"))==((hue&0x8000)!=0),"Actual material receives partial hue: "+str(entry.kind))
			if str(entry.kind)=="golem_iron":check(float(material.get_shader_parameter("metallic_strength"))>=.8,"Iron golem opts into metal instead of a skin material")
			if str(entry.kind)=="slimes_slime_frost":
				check(actor.contact.feet.is_empty(),"Legless ooze uses whole-skin plane support")
				check(bool(material.get_shader_parameter("gel_surface")) and is_zero_approx(float(material.get_shader_parameter("gel_strength"))),"Frost gel keeps its own icy atlas colour")
		var source: Dictionary=entry.source_provenance
		var cast_required:=bool(source.get("authored_cast",false)) or str(source.get("clip_labels",{}).get("cast2",""))=="Cast"
		if cast_required:
			var native_position:=actor.global_position
			for rate in [.25,1.,3.2]:
				for request: Dictionary in [{"protocol":"classic","action":12,"frames":5,"delay":0},{"protocol":"classic","action":14,"frames":5,"delay":0},{"protocol":"new","type":11,"frames":5,"delay":0}]:
					actor.dead=false;actor.animator.speed_scale=rate
					check(actor.receive_action(request) and actor.current_clip=="Cast","Both classic casts and new cast select an explicit motion: "+str(entry.kind))
					var length:=float(actor.animator.get_animation("Cast").length)
					# New animation packets carry a subaction, not classic frame timing.
					var seconds:=.8 if request.protocol=="classic" else length
					actor.animator.advance(seconds*.5)
					check(absf(actor.animator.current_animation_position-length*.5)<.001,"Native cast duration is independent of prior gait rate")
					check(actor.receive_action(request),"Repeated native cast is consumed");actor.animator.advance(seconds*.5)
					check(absf(actor.animator.current_animation_position-length*.5)<.001,"Repeated native cast restarts at its beginning")
					check(actor.global_position==native_position,"Cast leaves authoritative native coordinates unchanged")
		rows.append({"kind":entry.kind,"body":body,"cast_checked":cast_required})
		actor.free()
		if previous==null:Registry.entries.erase(body)
		else:Registry.entries[body]=previous
	check(accepted_pin==FileAccess.get_sha256("res://local-art/creatures/accepted-index.json"),"Candidate action checks leave accepted routes unchanged")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../work/creatures/source-preserving"))
	FileAccess.open("res://../work/creatures/source-preserving/actions.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"models":rows,"preparation_sha256":FileAccess.get_sha256(path),"test_sha256":FileAccess.get_sha256("res://Presentation/SourcePreservingActionTests.gd"),"scope":"Actual saved candidate actors, baked vertex/rig counts, raw/full/partial hue material parameters and repeated classic12/14/new11 casting duration across three preceding rates. Headless action/material contract; no GPU appearance or native-server/AI certificate."},"\t"))
	print("SOURCE PRESERVING ACTIONS: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
