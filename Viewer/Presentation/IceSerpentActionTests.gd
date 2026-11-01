extends SceneTree
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Visual=preload("res://Presentation/IceSerpentVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func _initialize() -> void:call_deferred("run")
func points(mesh: MeshInstance3D,rig: Skeleton3D) -> PackedVector3Array:
	var matrices: Array[Transform3D]=[]
	for i in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
	var result:=PackedVector3Array()
	for surface in mesh.mesh.get_surface_count():
		var a:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var binds: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/vertices.size()
		for vertex in vertices.size():
			var p:=Vector3.ZERO
			for slot in stride:p+=(matrices[binds[vertex*stride+slot]]*vertices[vertex])*weights[vertex*stride+slot]
			result.append(rig.to_global(p))
	return result
func run() -> void:
	var preparation:="res://local-art/creatures/ice_serpents/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var record: Dictionary=prep.models[0];Registry.load_index();Registry.entries[89]=record
	var actor:=Avatar.new();actor.initial_body=89;root.add_child(actor);actor.set_physics_process(false)
	var modern: Node3D=actor.horse_visual;modern.set_process(false);modern.set_physics_process(false);modern.contact.enabled=false;modern.contact.active=false
	var reference:=Visual.new();reference.entry=record;reference.treatment="rounded";root.add_child(reference);reference.set_process(false);reference.set_physics_process(false);reference.contact.enabled=false;reference.contact.active=false
	check(modern is Visual and modern.native_body==89 and modern.action_profile=="monster","Actual native89 avatar uses retained-source ice renderer")
	var modern_mesh: MeshInstance3D=modern.model.find_children("*","MeshInstance3D",true,false)[0];var reference_mesh: MeshInstance3D=reference.model.find_children("*","MeshInstance3D",true,false)[0];var rig: Skeleton3D=modern.skeleton;var other: Skeleton3D=reference.skeleton;var jaw:=rig.find_bone("bip01 ponytail1")
	modern.play("Idle",0.);modern.animator.seek(0.,true);modern.animator.pause();var jaw_idle:=rig.get_bone_pose_rotation(jaw)
	var samples: Array=[];var maximum_relative_error:=0.;var maximum_jaw_angle:=0.;var source_jaw_angle:=0.
	for clip: String in modern.animator.get_animation_list():
		if clip=="RESET":continue
		for step in 23:
			var phase:=(float(step)+.413)/23.
			for visual: Node3D in [modern,reference]:visual.play(clip,0.);visual.animator.seek(visual.animator.current_animation_length*phase,true);visual.animator.pause();visual.skeleton.force_update_all_bone_transforms();visual.apply_ground()
			var a:=points(reference_mesh,other);var b:=points(modern_mesh,rig);var box:=Geometry.deformed_bounds(modern_mesh,rig)
			check(a.size()==b.size() and box.position.is_finite() and box.size.is_finite(),"Retained source and modern complete skins are finite")
			check(absf(box.position.y)<.008,"Actual off-grid shared grounding keeps complete underside within8mm")
			check((modern.global_transform*(modern.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Weighted bounds cover every saved and compatibility skin")
			check(float(modern.get_meta("nameplate_height"))>box.end.y+.025,"Nameplate clears every sampled full skin")
			var root_shift:=rig.to_global(rig.get_bone_global_pose(0).origin)-other.to_global(other.get_bone_global_pose(0).origin);var skin_error:=0.;var bone_error:=0.
			for i in rig.get_bone_count():bone_error=maxf(bone_error,(rig.to_global(rig.get_bone_global_pose(i).origin)-root_shift).distance_to(other.to_global(other.get_bone_global_pose(i).origin)))
			check(bone_error<.00001,"Modern material and jaw rotation preserve every joint centre after shared floor translation")
			if clip!="Attack":
				for i in a.size():skin_error=maxf(skin_error,(b[i]-root_shift).distance_to(a[i]))
				check(skin_error<.00001,"Every retained source and feeding/collapse skin preserves relative geometry")
				maximum_relative_error=maxf(maximum_relative_error,skin_error)
			var angle:=rad_to_deg(jaw_idle.angle_to(rig.get_bone_pose_rotation(jaw)))
			if clip=="Attack":maximum_jaw_angle=maxf(maximum_jaw_angle,angle)
			if clip=="SourceAttack":source_jaw_angle=maxf(source_jaw_angle,angle)
			samples.append({"clip":clip,"phase":phase,"floor_m":box.position.y,"relative_skin_error_m":skin_error,"joint_centre_error_m":bone_error,"jaw_excursion_degrees":angle})
	check(maximum_jaw_angle>20. and maximum_jaw_angle<32.01 and source_jaw_angle>45.,"Active shorter jaw gape is explicit while original larger SourceAttack remains")
	var rates: Array=[]
	for speed in [1.8,6.8]:
		modern.dead=false;modern.action_remaining=0.;actor.animate(true,0.,1./60.,speed);var clip:="Walk" if speed<3.6 else "Run";var reference_speed:=float(record.locomotion.walk_reference_mps if clip=="Walk" else record.locomotion.run_reference_mps)
		check(modern.current_clip==clip and absf(float(modern.animator.speed_scale)-speed/reference_speed)<.0001,"Actual walking/running select declared unclamped source cadence")
		rates.append({"speed_mps":speed,"clip":clip,"rate":modern.animator.speed_scale})
	for action in [4,10,17,2]:
		modern.dead=false;check(modern.receive_action({"protocol":"classic","action":action}),"Native monster attack/hit/fidget/death has a replacement")
	check(actor.global_position.is_zero_approx(),"Visual floor support never moves native entity coordinates")
	reference.free();actor.free();var runtime: Dictionary={}
	for name in ["IceSerpentActionTests.gd","IceSerpentVisual.gd","SmallSnakeVisual.gd","SourceGroundLookup.gd","CreatureRegistry.gd","HumanAvatar.gd","CreatureVisual.gd","SkinGeometry.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:="res://local-art/creatures/serpents_snake_giant_ice-modern.gltf";var baseline:="res://local-art/creatures/serpents_snake_giant_ice-rounded.gltf";var output:="res://../outputs/creatures/ice_serpents";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var receipt:={"checks":checks,"failures":failures,"samples":samples,"rates":rates,"maximum_retained_relative_skin_error_m":maximum_relative_error,"maximum_active_jaw_degrees":maximum_jaw_angle,"maximum_source_jaw_degrees":source_jaw_angle,"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(preparation),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"reference_sha256":FileAccess.get_sha256(baseline),"reference_import_sha256":FileAccess.get_sha256(baseline+".import"),"ground_lookup_sha256":FileAccess.get_sha256(str(record.ground_lookup)),"scope":"Actual native89 avatar and paired saved rounded/modern source skins; explicit jaw-only rotation amendment, shared floor translation, dynamic bounds, native action/gait selection. Not native server or arbitrary terrain proof."}
	FileAccess.open(output+"/actions.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "));print("ICE SERPENT ACTIONS: ",checks," checks / ",failures," failures; ",samples.size()," paired skins");quit(1 if failures else 0)
