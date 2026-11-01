extends SceneTree
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func run() -> void:
	var destination:="res://../outputs/creatures/air-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var actor:=load("res://local-art/air/air-modern.scn").instantiate() as Node3D;root.add_child(actor)
	var carrier:=load("res://Art/Creatures/Water/water-elemental.scn").instantiate() as Node3D;root.add_child(carrier)
	var rig:=actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D;var source_rig:=carrier.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var player:=actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer;var source_player:=carrier.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	var body:=actor.find_child("CloudBody",true,false) as MeshInstance3D;var dust:=actor.find_child("Dust",true,false) as MeshInstance3D
	check(body!=null and dust!=null,"Analytic cloud and spent dust remain distinct actual surfaces")
	check(rig.get_bone_count()==source_rig.get_bone_count(),"Retained CC0 source rig has no lost bones")
	var arrays:=body.mesh.surface_get_arrays(0);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	for vertex in points.size():
		var total:=0.
		for slot in 4:
			var bind:=indices[vertex*4+slot];check(bind>=0 and bind<body.skin.get_bind_count(),"Actual influence index has a real skin bind");total+=weights[vertex*4+slot]
		check(absf(total-1.)<.00001 and points[vertex].is_finite(),"Saved analytic cloud vertices/weights are finite and normalized")
	var samples: Array=[];var complete_skins:=0;var max_pose_delta:=0.
	for category: String in player.get_animation_list():
		player.play(category,0.);source_player.play(category,0.)
		for step in 17:
			var phase:=float(step)/16.;player.seek(player.get_animation(category).length*phase,true);player.pause();rig.force_update_all_bone_transforms()
			source_player.seek(source_player.get_animation(category).length*phase,true);source_player.pause();source_rig.force_update_all_bone_transforms()
			var body_box:=Geometry.deformed_bounds(body,rig);complete_skins+=1
			check(body_box.position.is_finite() and body_box.size.is_finite() and body_box.size.length()>.02 and body_box.size.length()<7.,"Actual complete weighted cloud is finite through "+category)
			if not category.begins_with("Death"):
				for bone in rig.get_bone_count():
					var a:=rig.get_bone_global_pose(bone);var b:=source_rig.get_bone_global_pose(bone);var delta:=a.origin.distance_to(b.origin);max_pose_delta=maxf(max_pose_delta,delta)
					check(delta<.00001 and absf(a.basis.get_rotation_quaternion().dot(b.basis.get_rotation_quaternion()))>.99999,"Retained source joint pose is unchanged through "+category)
			var dust_box: AABB=dust.global_transform*dust.mesh.get_aabb();var visible_box: AABB=body_box if body.visible else dust_box
			if body.visible and dust.visible:visible_box=visible_box.merge(dust_box)
			check(body.visible or dust.visible,"Every collapse sample retains cloud or spent dust")
			if category.begins_with("Death") and step==16:check(not body.visible and dust.visible,"Final wind death is settled dust, without liquid/human remains")
			samples.append({"category":category,"phase":phase,"body_visible":body.visible,"dust_visible":dust.visible,"position":[visible_box.position.x,visible_box.position.y,visible_box.position.z],"size":[visible_box.size.x,visible_box.size.y,visible_box.size.z]})
	var file:=FileAccess.open(destination+"/motion.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"complete_skins":complete_skins,"max_source_pose_delta":max_pose_delta,"samples":samples,"asset_sha256":FileAccess.get_sha256("res://local-art/air/air-modern.scn"),"recipe_sha256":FileAccess.get_sha256("res://Presentation/PrepareAirElemental.gd"),"geometry_sha256":FileAccess.get_sha256("res://Presentation/AirCloudGeometry.gd"),"shader_sha256":FileAccess.get_sha256("res://Presentation/AirElementalSurface.gdshader"),"test_sha256":FileAccess.get_sha256("res://Presentation/AirElementalMotionTests.gd"),"preparation_sha256":FileAccess.get_sha256("res://local-art/air/preparation.json"),"scope":"Actual analytic cloud topology/binds and complete saved skins, retained CC0 non-death poses, authored collapse/dust. GPU shader margins, runtime and native proof separate."},"\t"));file.close();print("AIR MOTION: ",checks," / ",failures," failures / ",complete_skins," complete skins");quit(1 if failures else 0)
