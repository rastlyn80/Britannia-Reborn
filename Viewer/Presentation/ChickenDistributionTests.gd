extends SceneTree
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Visual=preload("res://Presentation/ChickenVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<16:push_error(label)
func run() -> void:
	for missing in ["res://local-art","res://work","res://../Server"]:check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(missing)),"No source cache, game inputs or server required")
	var record:=Registry.entry(208);check(record.get("kind")=="chicken" and Registry.asset_path(record)=="res://Art/Creatures/Chicken/chicken.glb","Installed public native208 route loads independently")
	var actor:=Avatar.new();actor.initial_body=208;var picker:=StaticBody3D.new();picker.set_meta("server_mobile",208);picker.collision_layer=2;var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker);root.add_child(actor);actor.apply_server_appearance({"body":208,"hue":0x8035},[]);actor.set_physics_process(false);var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.active=false;visual.contact.enabled=false;var rig: Skeleton3D=visual.skeleton;var meshes: Array=visual.model.find_children("*","MeshInstance3D",true,false)
	check(visual is Visual and visual.native_body==208 and visual.native_hue==0x8035 and visual.action_profile=="animal","Actual public avatar retains body/profile/raw partial hue")
	check(rig.get_bone_count()==47 and meshes.size()==2 and visual.contact.feet.is_empty(),"Original body/eyes and forty source plus seven segment joints load without donor")
	var maps:=0;var eyes:=0
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var a:=mesh.mesh.surface_get_arrays(surface);var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/v.size();var valid:=stride in [4,8]
			for i in v.size():
				var sum:=0.
				for j in stride:sum+=weights[i*stride+j];valid=valid and is_finite(weights[i*stride+j]) and weights[i*stride+j]>=0.
				valid=valid and absf(sum-1.)<.0001
			check(valid,"Every public skin vertex retains positive normalized influences")
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D;var active:=mesh.get_active_material(surface)
			if source.normal_texture!=null:maps+=1;check(active is ShaderMaterial and active.get_shader_parameter("albedo_texture")==source.albedo_texture and active.get_shader_parameter("normal_texture")==source.normal_texture,"Original embedded coat maps load independently")
			if source.albedo_texture==null and source.roughness<.5:eyes+=1;check(active==source,"Dark original eye material remains protected")
	check(maps==1 and eyes==1,"Distinct source normal-mapped coat and eye components")
	var samples:=0;var airborne:=0
	for clip: String in record.stats.modern.clips:
		check(visual.animator.has_animation(clip),"Public package retains declared source/active category "+clip)
		for i in 9:
			visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*float(i)/8.,true);visual.animator.pause();rig.force_update_all_bone_transforms();visual.update_landmarks();var box:=Geometry.deformed_bounds(meshes[0],rig)
			for j in range(1,meshes.size()):box=box.merge(Geometry.deformed_bounds(meshes[j],rig))
			check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.1 and box.size.length()<1.2,"Standalone complete skin is finite and bounded")
			check(box.position.y>-.008 and box.position.y<.07,"Source floor correction and positive authored lift survive clean import")
			check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Public dynamic bounds contain both complete skins")
			await process_frame;await process_frame
			var actual_pick: AABB=pick_shape.global_transform*AABB(-pick_shape.shape.size*.5,pick_shape.shape.size)
			check(actual_pick.grow(.001).encloses(box),"Actual public picking volume resizes and contains the animated source skin")
			if clip=="Run" and box.position.y>.01:airborne+=1
			samples+=1
	var distinct: bool = record.has("additional_animation_library")
	check(samples==(189 if distinct else 171) and airborne>=2,"All saved categories and positive running clearance measured")
	if distinct:
		for slot: int in [4, 5, 6, 8, 9, 10, 12]:
			visual.dead = false
			check(visual.receive_action({"protocol": "classic", "action": slot, "frames": 5}) and
				visual.current_clip == record.classic_action_categories[str(slot)], "Distinct public Classic route %d" % slot)
	for speed in [1.8,6.8]:
		visual.dead=false;visual.action_remaining=0.;actor.animate(true,0.,1./60.,speed);var clip: String="Walk" if speed<3.6 else "Run";check(visual.current_clip==clip and visual.animator.get_animation(clip).loop_mode==Animation.LOOP_LINEAR and visual.animator.speed_scale<4.,"Actual public avatar selects unclamped calibrated looping gait")
	actor.free()
	for hue in [0,53,0x8035]:
		var corpse:=Corpses.build(208,hue);check(corpse!=null,"Independent native208 static cadaver loads")
		if corpse==null:continue
		root.add_child(corpse);check(corpse.get_meta("corpse_body")==208 and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==hue,"Static cadaver retains native graphic/body/hue")
		check(corpse.find_children("*","Skeleton3D",true,false).is_empty() and corpse.find_children("*","MeshInstance3D",true,false).size()==2,"Both original components survive without a live rig")
		for mesh: MeshInstance3D in corpse.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():var arrays:=mesh.mesh.surface_get_arrays(surface);check(arrays[Mesh.ARRAY_BONES]==null and arrays[Mesh.ARRAY_WEIGHTS]==null and arrays[Mesh.ARRAY_TEX_UV]!=null,"Frozen geometry drops bones/weights and retains source UVs")
		corpse.free()
	print("CHICKEN DISTRIBUTION: ",checks-failures," / ",checks,"; ",samples," complete skins; no private art, donor, game inputs or server");quit(1 if failures else 0)
