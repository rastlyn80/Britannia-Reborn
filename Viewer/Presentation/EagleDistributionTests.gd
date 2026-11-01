extends SceneTree
## A real public avatar in an isolated project, without donor or private art.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func wait_seconds(seconds: float) -> void:
	var until:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<until:await process_frame
func run() -> void:
	Registry.load_index();check(not DirAccess.dir_exists_absolute("res://local-art"),"No private/original art present")
	check(Registry.supports_body(5) and Registry.entry(5).assets.modern=="res://Art/Creatures/Eagle/eagle.glb","Public native eagle route resolves")
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Art/Creatures/Eagle/provenance.json"))
	check(FileAccess.get_sha256("res://Art/Creatures/Eagle/eagle.glb")==provenance.asset_sha256,"Exact independent asset matches provenance")
	var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=5;root.add_child(actor);actor.set_physics_process(false)
	check(actor.human_visual==null and actor.horse_visual!=null,"Public actual eagle avatar loads")
	if actor.horse_visual==null:quit(1);return
	var visual: Node3D=actor.horse_visual;visual.set_physics_process(false);visual.contact.enabled=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(rig.get_bone_count()==24 and mesh.mesh.get_surface_count()==7,"Preserved donor bones and all seven eye/body surfaces ship")
	var valid:=true;var triangles:=0
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/vertices.size();triangles+=arrays[Mesh.ARRAY_INDEX].size()/3;valid=valid and stride==8
		for i in vertices.size():
			var total:=0.
			for j in stride:total+=weights[i*stride+j];valid=valid and weights[i*stride+j]>=0. and is_finite(weights[i*stride+j])
			valid=valid and absf(total-1.)<.0001
	check(valid and triangles==7544,"Complete refined geometry and eight-influence skin ship")
	actor.animate(true,0.,1./60.,1.8);check(visual.current_clip=="TakeOff","Public avatar starts take-off")
	await wait_seconds(.85);check(visual.current_clip=="Run" and visual.animator.is_playing(),"Public take-off reaches looping flight")
	actor.animate(false,0.,1./60.,0.);check(visual.current_clip=="Land","Public avatar starts landing")
	await wait_seconds(.95);check(visual.current_clip=="Idle","Public landing returns to perch")
	visual.set_process(false)
	for clip: String in provenance.preparation.clips:
		check(visual.animator.has_animation(clip),"Declared public category ships: "+clip)
		visual.play(clip,0.);visual.animator.get_animation(clip).loop_mode=Animation.LOOP_NONE;visual.animator.pause()
		for i in 25:
			visual.animator.seek(visual.animator.current_animation_length*i/24.,true);await process_frame
			var bounds:=Geometry.deformed_bounds(mesh,rig)
			check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.2 and bounds.size.length()<2.6,"Complete public skin stays bounded")
			check(bounds.position.y>-.004,"Public skin preserves support precision")
			if clip in ["Run","Fly","AirIdle"]:check(bounds.position.y>.07,"Public flight retains actual wing clearance")
	for action in range(13):
		visual.dead=false;visual.action_remaining=0.;visual.transition_remaining=0.;visual.flight_state="ground"
		check(visual.receive_action({"protocol":"classic","action":action}),"Public animal category resolves: "+str(action))
	var listed:=false
	for row: Dictionary in Corpses.catalogue():
		if int(row.body)==5:listed=int(row.graphic)==0x2006 and int(row.amount)==5
	check(listed,"Eagle cadaver is listed using actual native graphic/amount")
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(5,hue);check(corpse!=null,"Public static eagle corpse resolves")
		if corpse:
			check(corpse.get_meta("corpse_body")==5 and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Public cadaver preserves native identity/hue")
			check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and is_zero_approx(corpse.get_meta("corpse_bounds").position.y) and corpse.get_meta("corpse_bounds").size.y<.22,"Public cadaver is grounded static geometry")
			corpse.free()
	actor.queue_free();for frame in 2:await process_frame
	print("EAGLE DISTRIBUTION: ",checks-failures," / ",checks);quit(1 if failures else 0)
