extends SceneTree
## Public cat only: complete eight-influence skins, measured gaits and corpse.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const BaseAsset := "res://Art/Creatures/Cat/cat.glb"
const ActionsAsset := "res://Art/Creatures/Cat/cat-actions.scn"
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var registry=preload("res://Presentation/CreatureRegistry.gd");registry.load_index()
	check(not DirAccess.dir_exists_absolute("res://local-art"),"No original/private art is present")
	var has_actions := FileAccess.file_exists(ActionsAsset)
	check(registry.supports_body(201) and registry.entry(201).assets.modern==(ActionsAsset if has_actions else BaseAsset),"Public native Cat201 route resolves")
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Art/Creatures/Cat/provenance.json"))
	check(FileAccess.get_sha256(BaseAsset)==provenance.asset_sha256,"Public GLB matches its exact independent provenance")
	var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=201;root.add_child(actor);actor.set_physics_process(false)
	check(actor.human_visual==null and actor.horse_visual!=null,"Actual public cat avatar loads without source imports")
	if actor.horse_visual==null:quit(1);return
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(rig.get_bone_count()==24 and visual.contact.feet.size()==4 and visual.contact.stride==8,"All source bones and four multi-surface eight-influence paws ship")
	check(mesh.mesh.get_surface_count()==6,"Coat regions and three fixed eye surfaces are included")
	var valid:=true;var triangles:=0
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/vertices.size();triangles+=arrays[Mesh.ARRAY_INDEX].size()/3;valid=valid and stride==8
		for i in vertices.size():
			var total:=0.
			for j in stride:total+=weights[i*stride+j];valid=valid and weights[i*stride+j]>=0. and is_finite(weights[i*stride+j])
			valid=valid and absf(total-1.)<.0001
	check(valid and triangles==6006,"Complete public mesh and normalized source skin weights survive import")
	for speed in [.192,1.8,6.8]:
		actor.animate(true,0.,1./60.,speed);var expected: String="Walk" if speed<.4 else "Run" if speed<3.6 else "Gallop"
		check(visual.current_clip==expected and absf(visual.animator.speed_scale-1.)<.001,"Public actual avatar chooses the physical-speed gait")
		check(visual.animator.get_animation(expected).loop_mode==Animation.LOOP_LINEAR,"Public selected gait loops")
	for clip: String in provenance.preparation.clips:
		check(visual.animator.has_animation(clip),"Every declared public category ships: "+clip)
		visual.play(clip,0.);visual.animator.get_animation(clip).loop_mode=Animation.LOOP_NONE;visual.animator.pause()
		for i in (81 if clip=="Gallop" else 21 if clip=="Run" else 13):
			var phase:=float(i)/(80. if clip=="Gallop" else 20. if clip=="Run" else 12.);visual.animator.seek(visual.animator.current_animation_length*phase,true);await process_frame
			var bounds:=Geometry.deformed_bounds(mesh,rig)
			check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.3 and bounds.size.length()<1.,"Public complete skin stays finite and bounded")
			check(bounds.position.y>-.005,"Public short-stance motion retains skin-floor precision")
	for action in range(13):
		visual.dead=false;visual.action_remaining=0.;check(visual.receive_action({"protocol":"classic","action":action}),"Public animal group resolves: "+str(action))
	if has_actions:
		var action_provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Creatures/Cat/actions-provenance.json"))
		check(action_provenance.scene_sha256 == FileAccess.get_sha256(ActionsAsset) and action_provenance.source_sha256 == provenance.asset_sha256,
			"Public additional actions derive from the exact licensed source")
		var renderer := FileAccess.get_file_as_string(registry.entry(201).presentation_script).replace("\r\n", "\n")
		check(action_provenance.renderer_sha256 == renderer.sha256_text(),
			"Public collapse renderer matches the tested version")
		for slot: int in [8, 9, 10, 12]:
			var clip: String = {8: "Death2", 9: "CatStretch", 10: "Fidget2", 12: "Death"}[slot]
			visual.dead = false
			visual.action_remaining = 0.0
			check(visual.receive_action({"protocol": "classic", "action": slot}) and visual.current_clip == clip,
				"Public cat selects %s for Classic group %d" % [clip, slot])
			visual.animator.pause()
			for frame in 17:
				visual.animator.seek(visual.animator.current_animation_length * frame / 16.0, true)
				await process_frame
				var bounds := Geometry.deformed_bounds(mesh, rig)
				check(bounds.position.is_finite() and bounds.position.y >= -0.005 and bounds.size.length() > 0.30,
					"Public %s stays bounded above the floor" % clip)
		for example: Array in [[0x647, 5, "Alert"], [0x8647, 5, "Alert"], [2301, 5, "Death"], [0x647, 6, "Death"]]:
			visual.dead = false
			visual.apply_identity(201, example[0])
			var request := {"protocol": "classic", "body": 201, "action": 12, "frames": example[1],
				"repeat_count": 1, "reverse": false, "repeat": false, "delay": 0}
			check(visual.receive_action(request) and visual.current_clip == example[2]
				and visual.dead == (example[2] == "Death") and visual.get_meta("native_action") == request,
				"Public body 201 distinguishes the exact stock fire-breath windup and retains the packet")
	var corpses=preload("res://Presentation/CorpseModels.gd");var corpse: Node3D=corpses.build(201)
	check(corpse!=null and corpse.get_meta("corpse_body")==201 and corpse.get_meta("graphic_id")==0x2006,"Public native corpse graphic/body resolves")
	if corpse:
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and is_zero_approx(corpse.get_meta("corpse_bounds").position.y),"Cat cadaver is grounded static geometry")
		corpse.free()
	actor.queue_free();for frame in 2:await process_frame
	print("CAT DISTRIBUTION: ",checks-failures," / ",checks);quit(0 if failures==0 else 1)
