extends SceneTree
## Independent shipped art and actual avatar without original inputs or server.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Visual=preload("res://Presentation/BoglingVisual.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func run() -> void:
	check(not DirAccess.dir_exists_absolute("res://local-art") and not DirAccess.dir_exists_absolute("res://work") and not FileAccess.file_exists("res://hues.local.json"),"No donor/private art/game palette/server in isolated distribution")
	var record:=Registry.entry(779);check(not record.is_empty() and record.kind=="bogling" and Registry.asset_path(record)=="res://Art/Creatures/Bogling/bogling.glb","Shipped body779 resolves independently")
	var actor:=Avatar.new();actor.initial_body=779;root.add_child(actor);actor.apply_server_appearance({"body":779,"hue":0x8035},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.active=false;visual.contact.enabled=false
	var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(visual is Visual and visual.native_body==779 and visual.native_hue==0x8035 and visual.action_profile=="monster","Actual standalone avatar preserves native body/profile/raw partial hue")
	check(rig.get_bone_count()==33 and visual.contact.feet.size()==2,"Source rig and measured eight-weight feet retained")
	var a:=mesh.mesh.surface_get_arrays(0);var valid: bool=a[Mesh.ARRAY_BONES].size()==a[Mesh.ARRAY_VERTEX].size()*8
	for vertex in a[Mesh.ARRAY_VERTEX].size():
		var total:=0.
		for slot in 8:
			var weight: float=a[Mesh.ARRAY_WEIGHTS][vertex*8+slot];total+=weight;valid=valid and is_finite(weight) and weight>=0.
		valid=valid and absf(total-1.)<.0001
	check(valid,"Every shipped skin vertex has finite normalized eight-weight influences")
	var material:=mesh.get_active_material(0) as ShaderMaterial
	check(material!=null and material.get_shader_parameter("albedo_texture")!=null and material.get_shader_parameter("normal_texture")!=null and bool(material.get_shader_parameter("use_normal")),"Original embedded albedo/normal maps load without donor or texture sidecars")
	var samples:=0
	for clip: String in visual.animator.get_animation_list():
		for i in 9:
			visual.play(clip,0.);visual.animator.seek(float(visual.animator.current_animation_length)*i/8.,true);visual.animator.pause();rig.force_update_all_bone_transforms();visual.update_landmarks()
			var box:=Geometry.deformed_bounds(mesh,rig)
			check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.3 and box.size.length()<4.,"Every standalone complete action skin is finite and bounded")
			check(box.position.y>-.004,"Complete shipped action skin stays above the floor")
			check(float(visual.get_meta("nameplate_height"))>box.end.y+.015 and (visual.get_meta("pick_bounds") as AABB).grow(.01).encloses(box),"Standalone branch landmarks and selection contain the actual action skin")
			samples+=1
	var extra := record.has("additional_animation_library")
	check(samples == (171 if extra else 153), "All runtime categories sampled including retained source Run/Dance")
	if extra:
		for slot: int in [15, 16, 18]:
			var expected := "Uncurl" if slot == 18 else "RootGuard"
			check(visual.receive_action({"protocol": "classic", "action": slot, "frames": 5})
				and visual.current_clip == expected, "Independently shipped fitted gesture matches its Classic route")
		check(visual.receive_action({"protocol": "new", "type": 14, "action": 14})
			and visual.current_clip == "Pillage", "The original new-protocol gesture remains available")
	for speed in [1.8,6.8]:
		visual.dead=false;visual.action_remaining=0.;actor.animate(true,0.,1./60.,speed);var clip:="Walk" if speed<3.6 else "Run";var reference:=1.8 if clip=="Walk" else 5.5
		check(visual.current_clip==clip and visual.animator.get_animation(clip).loop_mode==Animation.LOOP_LINEAR and absf(float(visual.animator.speed_scale)-speed/reference)<.0001,"Actual standalone gait scales its calibrated physical reference speed")
	actor.free()
	var corpse:=Corpses.build(779,0x8035);check(corpse!=null,"Native corpse builds without original inputs")
	if corpse!=null:
		root.add_child(corpse);check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==779 and corpse.get_meta("native_hue")==0x8035,"Static native corpse preserves graphic/body/raw hue")
		var parts:=corpse.find_children("*","MeshInstance3D",true,false);check(parts.size()==1 and corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Shipped corpse is actual static geometry")
		for part: MeshInstance3D in parts:
			check(part.mesh.get_surface_count()==1,"Cadaver retains its visible surface")
			var arrays:=part.mesh.surface_get_arrays(0);check(arrays[Mesh.ARRAY_BONES]==null and arrays[Mesh.ARRAY_WEIGHTS]==null,"Frozen corpse drops live skin arrays")
		corpse.free()
	print("BOGLING DISTRIBUTION: ",checks-failures," / ",checks," checks; ",samples," complete skins");quit(1 if failures else 0)
