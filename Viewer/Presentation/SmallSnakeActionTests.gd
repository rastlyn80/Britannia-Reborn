extends SceneTree
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Visual=preload("res://Presentation/SmallSnakeVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func run() -> void:
	var prep_path:="res://local-art/creatures/small_snakes/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path));var record: Dictionary=prep.models[0];Registry.load_index();Registry.entries[52]=record
	var actor:=Avatar.new();actor.initial_body=52;root.add_child(actor);actor.set_physics_process(false);var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false
	check(visual is Visual and visual.native_body==52 and visual.action_profile=="animal","Actual native52 actor selects dynamic legless source presenter")
	var mesh:=visual.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D;var rig: Skeleton3D=visual.skeleton;var samples: Array=[]
	for clip: String in visual.animator.get_animation_list():
		visual.play(clip,0.)
		for step in 17:
			var phase:=(float(step)+.23)/17.;visual.animator.seek(float(visual.animator.current_animation_length)*phase,true);visual.animator.pause();rig.force_update_all_bone_transforms();visual.update_landmarks();var box:=Geometry.deformed_bounds(mesh,rig)
			check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.03 and box.size.length()<1.6,"Every actual source/authored/compatibility skin is finite")
			check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Current animated pick bounds contain independent full-skin samples")
			check(float(visual.get_meta("nameplate_height"))>box.end.y+.025,"Animated upper landmark clears every full skin")
			samples.append({"clip":clip,"phase":phase,"position":[box.position.x,box.position.y,box.position.z],"size":[box.size.x,box.size.y,box.size.z]})
	check(visual.animator.has_animation("SourceRun") and absf(float(visual.animator.get_animation("Run").length)-float(visual.animator.get_animation("Walk").length)*.6)<.001,"Retimed Run uses active Walk while original SourceRun remains separate")
	var rates: Array=[]
	for speed in [1.8,6.8]:
		visual.dead=false;visual.action_remaining=0.;actor.animate(true,0.,1./60.,speed);var clip:="Walk" if speed<3.6 else "Run";var reference:=float(record.locomotion.walk_reference_mps if clip=="Walk" else record.locomotion.run_reference_mps)
		check(visual.current_clip==clip and absf(float(visual.animator.speed_scale)-speed/reference)<.0001,"Actual movement selects declared size-scaled gait rate")
		check(float(visual.animator.speed_scale)<3.2,"Native walking/running rates avoid clamping or excessive playback")
		rates.append({"speed_mps":speed,"clip":clip,"rate":visual.animator.speed_scale})
	actor.free();var asset:="res://local-art/creatures/small_snakes-modern.gltf";var result:={"checks":checks,"failures":failures,"samples":samples,"rates":rates,"test_sha256":FileAccess.get_sha256("res://Presentation/SmallSnakeActionTests.gd"),"runtime_sha256":{"SmallSnakeVisual.gd":FileAccess.get_sha256("res://Presentation/SmallSnakeVisual.gd"),"CreatureVisual.gd":FileAccess.get_sha256("res://Presentation/CreatureVisual.gd"),"CreatureRegistry.gd":FileAccess.get_sha256("res://Presentation/CreatureRegistry.gd")},"preparation_sha256":FileAccess.get_sha256(prep_path),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"scope":"Actual dynamic source skin envelopes and declared size-based retimed gait selection; no recovered UO cadence or no-slip claim."}
	FileAccess.open("res://../outputs/creatures/small_snakes/actions.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("SMALL SNAKE ACTIONS: ",checks," / ",failures," failures; ",samples.size()," complete skins");quit(1 if failures else 0)
