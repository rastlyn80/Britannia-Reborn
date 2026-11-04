extends SceneTree
## Source-only disposable project: no original game inputs or private artwork.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var registry=preload("res://Presentation/CreatureRegistry.gd");registry.load_index()
	check(not DirAccess.dir_exists_absolute("res://local-art"),"No local/private art is present")
	var scene := "res://Art/Creatures/Rat/rat-fidgets.scn"
	var has_fidgets := FileAccess.file_exists(scene)
	var expected := scene if has_fidgets else "res://Art/Creatures/Rat/rat.glb"
	check(registry.supports_body(238) and registry.entry(238).assets.modern==expected,"Public native Rat route resolves")
	if has_fidgets:
		var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Creatures/Rat/provenance.json"))
		check(provenance.classic_fidgets.scene_sha256 == FileAccess.get_sha256(scene), "Exact authored fidget scene ships")
	var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=238;root.add_child(actor);actor.set_physics_process(false)
	check(actor.human_visual==null and actor.horse_visual!=null,"Actual public rat avatar loads")
	if actor.horse_visual==null:quit(1);return
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(rig.get_bone_count()==21 and visual.contact.feet.size()==4,"Source rig and four real two-joint legs ship")
	check(mesh.get_active_material(0).shader==preload("res://Presentation/CreatureFurSurface.gdshader"),"Public avatar keeps matte fur")
	var arrays:=mesh.mesh.surface_get_arrays(0);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/points.size();var valid:=stride==4
	for i in points.size():
		var total:=0.
		for j in stride:total+=weights[i*stride+j];valid=valid and weights[i*stride+j]>=0. and is_finite(weights[i*stride+j])
		valid=valid and absf(total-1.)<.0001
	check(valid,"Public skin weights remain finite and normalized")
	var clips := ["Idle","Walk","Run","Attack","Attack2","Hit","Fidget","Eat","Alert","Death"]
	if has_fidgets:
		clips.append_array(["RatRear", "Fidget2"])
	for clip in clips:
		check(visual.animator.has_animation(clip),"Every declared public category ships: "+clip)
		visual.play(clip,0.);visual.animator.get_animation(clip).loop_mode=Animation.LOOP_NONE;visual.animator.pause()
		for i in 13:
			visual.animator.seek(visual.animator.current_animation_length*float(i)/12.,true);await process_frame
			var bounds:=Geometry.deformed_bounds(mesh,rig)
			check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.2 and bounds.size.length()<.9,"Public full skin stays finite and bounded")
			check(bounds.position.y>-.006,"Public actual skin floor correction survives distribution")
	for action in range(13):
		visual.dead=false;visual.action_remaining=0.;check(visual.receive_action({"protocol":"classic","action":action}),"Public animal group routes: "+str(action))
	if has_fidgets:
		for slot: int in [9, 10]:
			visual.dead = false
			check(visual.receive_action({"protocol": "classic", "action": slot}), "Public fidget packet is consumed")
			check(visual.current_clip == ("RatRear" if slot == 9 else "Fidget2"), "Public fidget selects its own motion")
	var corpses=preload("res://Presentation/CorpseModels.gd");var corpse: Node3D=corpses.build(238)
	check(corpse!=null and corpse.get_meta("corpse_body")==238 and corpse.get_meta("graphic_id")==0x2006,"Native corpse graphic/body resolves without original game data")
	if corpse:
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and is_zero_approx(corpse.get_meta("corpse_bounds").position.y),"Public cadaver is grounded static geometry")
		corpse.free()
	actor.queue_free();for frame in 2:await process_frame
	print("RAT DISTRIBUTION: ",checks-failures," / ",checks);quit(0 if failures==0 else 1)
