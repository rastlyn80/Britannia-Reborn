extends SceneTree
## Shipped independent rabbit: no original donor, private art or game inputs.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Visual=preload("res://Presentation/RabbitVisual.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(label)
func run() -> void:
	check(not DirAccess.dir_exists_absolute("res://local-art") and not DirAccess.dir_exists_absolute("res://work"),"No private art, donor, source cache or server in clean project")
	var record:=Registry.entry(205);check(not record.is_empty() and record.kind=="rabbit" and Registry.asset_path(record)=="res://Art/Creatures/Rabbit/rabbit.glb","Public rabbit205 route exists independently")
	var actor:=Avatar.new();actor.initial_body=205;root.add_child(actor);actor.apply_server_appearance({"body":205,"hue":0x8035},[]);actor.set_physics_process(false)
	var visual: Node3D=actor.horse_visual;visual.set_process(false);visual.set_physics_process(false);visual.contact.active=false;visual.contact.enabled=false
	var rig: Skeleton3D=visual.skeleton;var meshes: Array=visual.model.find_children("*","MeshInstance3D",true,false)
	check(visual is Visual and visual.native_body==205 and visual.native_hue==0x8035 and visual.action_profile=="animal","Actual standalone avatar preserves body/profile/raw partial hue")
	check(rig.get_bone_count()==37 and meshes.size()==2 and visual.contact.feet.size()==4,"Original body/fur rig and four real paws retained")
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/vertices.size();var valid:=stride==8
			for i in vertices.size():
				var total:=0.
				for j in stride:total+=weights[i*stride+j];valid=valid and weights[i*stride+j]>=0. and is_finite(weights[i*stride+j])
				valid=valid and absf(total-1.)<.0001
			check(valid,"Every shipped vertex retains normalized eight-weight skin")
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D;var material:=mesh.get_active_material(surface) as ShaderMaterial
			check(source.albedo_texture!=null and material!=null and material.get_shader_parameter("albedo_texture")==source.albedo_texture,"Actual embedded artist alpha/albedo bound without original source")
			if source.normal_texture!=null:check(material.get_shader_parameter("normal_texture")==source.normal_texture,"Embedded original normal map retained")
	var samples:=0;var airborne:=0
	for clip: String in record.stats.modern.clips:
		check(visual.animator.has_animation(clip),"Shipped source/declared category:"+clip)
		for i in 9:
			visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*float(i)/8.,true);visual.animator.pause();await process_frame;await process_frame
			var bounds:=Geometry.deformed_bounds(meshes[0],rig)
			for j in range(1,meshes.size()):bounds=bounds.merge(Geometry.deformed_bounds(meshes[j],rig))
			check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.2 and bounds.size.length()<1.5,"Actual standalone complete skin finite and bounded")
			check(bounds.position.y>-.004,"Shipped complete skin avoids penetration")
			if clip in ["Run","Walk","Jump"] and bounds.position.y>.025:airborne+=1
			samples+=1
	check(samples==record.stats.modern.clips.size()*9 and airborne>=6,"All shipped categories and genuine airborne phases measured")
	if record.has("additional_animation_library"):
		var routes := {6: "RabbitLunge", 10: "RabbitEarCheck", 12: "Death2"}
		for group: int in routes:
			check(actor.receive_native_action({"protocol": "classic", "action": group, "frames": 5})
				and visual.current_clip == routes[group], "Public standalone rabbit plays its distinct Classic action")
	for speed in [1.8,6.8]:
		visual.dead=false;visual.action_remaining=0.;actor.animate(true,0.,1./60.,speed);var clip: String="Walk" if speed<3.6 else "Run"
		check(visual.current_clip==clip and visual.animator.get_animation(clip).loop_mode==Animation.LOOP_LINEAR,"Standalone avatar selects looping calibrated gait")
	actor.free()
	var corpse:=Corpses.build(205,0x8035);check(corpse!=null,"Public native corpse builds without private inputs")
	if corpse!=null:
		root.add_child(corpse);check(corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("corpse_body")==205 and corpse.get_meta("native_hue")==0x8035,"Standalone corpse preserves native graphic/body/raw hue")
		var parts:=corpse.find_children("*","MeshInstance3D",true,false);check(parts.size()==2 and corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Static body and original fur are both present without a live rig")
		for part: MeshInstance3D in parts:
			check(part.mesh.get_surface_count()>0,"Custom UV formats create actual cadaver surfaces")
			for surface in part.mesh.get_surface_count():
				var arrays:=part.mesh.surface_get_arrays(surface);check(arrays[Mesh.ARRAY_BONES]==null and arrays[Mesh.ARRAY_WEIGHTS]==null,"Frozen cadaver drops skin arrays while retaining source UVs")
		corpse.free()
	print("RABBIT DISTRIBUTION: ",checks-failures," / ",checks,"; ",samples," complete skins; no private art, donor, game inputs or server");quit(1 if failures else 0)
