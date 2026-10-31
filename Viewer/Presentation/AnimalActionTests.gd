extends SceneTree
## All named classic low groups; unknown slot 4 remains explicitly unsupported.
const Mounts=preload("res://Presentation/MountVisual.gd")
const Horse=preload("res://Presentation/HorseVisual.gd")
const Registry=preload("res://Presentation/EquineRegistry.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func run() -> void:
	var bodies: Array=Registry.BODIES.keys()+Registry.COMPATIBILITY.keys()+Registry.DISTINCT.keys()+[0xd2,0xda,0xdb,0xdc,0x124]
	for body: int in bodies:
		var actor:=Mounts.create(body);root.add_child(actor);actor.apply_identity(body,53);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false
		var horse:=actor is Horse
		actor.animator.play("idle" if horse else "Idle",0.);actor.animator.seek(0.,true);actor.animator.pause()
		for frame in 2:await process_frame
		var mouth_height: float=actor.socket("mouth_socket" if horse else "mouth").origin.y
		for action in [0,1,2,3,5,6,7,8,9,10,11,12]:
			# Independent protocol fixtures, not resurrection in the live client.
			actor.dead=false;actor.action_remaining=0.
			check(actor.receive_action({"protocol":"classic","action":action,"frame_count":6,"repeat_count":1,"forward":true,"repeat":false,"delay":0}),"Named animal group has an explicit replacement: "+str([body,action]))
			var clip: String=actor.current_clip
			actor.animator.play(clip,0.) # Sample the target clip, not its entry blend.
			for phase in [0.,.5,.99]:
				actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause()
				for frame in 2:await process_frame
				if action==11 and horse:actor.fit_action_floor()
				var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
				var bounds:=Geometry.deformed_bounds(mesh,actor.skeleton)
				check(bounds.position.is_finite() and bounds.size.length()>.4 and bounds.size.length()<5.,"Action skin is finite/bounded")
				check(actor.transform.is_equal_approx(Transform3D.IDENTITY),"Native action does not change server position")
				if action==11:check(bounds.position.y>-.035,"Lying skin stays above the actual actor support plane")
				if action==3 and phase==.5:
					var drop: float=mouth_height-actor.socket("mouth_socket" if horse else "mouth").origin.y
					check(drop>.15,"Feeding visibly lowers the actual animated mouth: "+str([body,drop]))
				rows.append({"body":body,"action":action,"clip":clip,"phase":phase,"lowest_vertex_m":bounds.position.y})
			if action==11:
				check(not actor.dead and not actor.contact.enabled,"Lying is alive and disables standing foot IK")
				actor.play_gait(false,0.)
				check(actor.current_clip==clip,"Rest holds while stationary")
				actor.play_gait(true,1.8)
				check(actor.current_clip in ["walk","Walk"] and actor.contact.enabled,"Movement resumes standing gait and foot support")
		actor.dead=false
		check(not actor.receive_action({"protocol":"classic","action":4}),"Unknown low slot stays unknown")
		check(not actor.receive_action({"protocol":"new","type":99}),"Unknown new protocol action stays unsupported")
		actor.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/equines"))
	var file:=FileAccess.open("res://../outputs/equines/animal-actions.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"poses":rows,"known_low_groups":12,"unknown_low_slots":[4],"scope":"31 installed equine/ostard/llama body presentations, 12 named low groups, three skin samples each. Category replacements share attack/death/fidget art; feeding is authored and lying reuses collapse. Not 12 unique captured clips or exact native choreography."},"\t"));file.close()
	print("ANIMAL ACTIONS: ",checks-failures," / ",checks,"; ",rows.size()," poses");quit(1 if failures else 0)
