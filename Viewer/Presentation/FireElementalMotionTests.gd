extends SceneTree
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/fire-trial"));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<15:push_error(label)
func run() -> void:
	var actor:=load("res://local-art/fire/fire-modern.scn").instantiate() as Node3D;root.add_child(actor)
	var donor:=load("res://Art/Creatures/Water/water-elemental.scn").instantiate() as Node3D;root.add_child(donor)
	var rig:=actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D;var source:=donor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var body:=actor.find_child("FireBody",true,false) as MeshInstance3D;var ash:=actor.find_child("Ash",true,false) as MeshInstance3D
	var player:=actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer;var original:=donor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	check(rig.get_bone_count()==65,"Retained licensed65-bone source rig")
	var samples: Array=[];var source_error:=0.
	for category: String in player.get_animation_list():
		for step in 17:
			var phase:=float(step)/16.;player.play(category,0.);player.seek(player.get_animation(category).length*phase,true);player.pause();rig.force_update_all_bone_transforms()
			var box:=Geometry.deformed_bounds(body,rig)
			check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.05 and box.size.length()<4.,"Complete actual ribbon skin remains finite")
			if not category.begins_with("Death"):
				original.play(category,0.);original.seek(original.get_animation(category).length*phase,true);original.pause();source.force_update_all_bone_transforms()
				for bone in rig.get_bone_count():
					var error:=rig.get_bone_global_pose(bone).origin.distance_to(source.get_bone_global_pose(bone).origin);source_error=maxf(source_error,error)
					check(error<.00001 and rig.get_bone_name(bone)==source.get_bone_name(bone),"Every retained source joint centre matches the carrier")
			if category.begins_with("Death") and step==16:check(not body.visible and ash.visible,"Final flame dissipation leaves only static ash")
			samples.append({"clip":category,"phase":phase,"bounds_position":[box.position.x,box.position.y,box.position.z],"bounds_size":[box.size.x,box.size.y,box.size.z],"body_visible":body.visible,"ash_visible":ash.visible})
	actor.free();donor.free();FileAccess.open("res://../outputs/creatures/fire-trial/motion.json",FileAccess.WRITE).store_string(JSON.stringify({"test_sha256":FileAccess.get_sha256("res://Presentation/FireElementalMotionTests.gd"),"preparation_sha256":FileAccess.get_sha256("res://local-art/fire/preparation.json"),"checks":checks,"failures":failures,"source_position_error":source_error,"samples":samples,"asset_sha256":FileAccess.get_sha256("res://local-art/fire/fire-modern.scn"),"scope":"Private actual saved ribbon skin and retained non-death carrier joints; no native route or shader pixel-envelope/corpse proof."},"  "))
	print("PRIVATE FIRE MOTION: ",checks," / ",failures," failures; ",samples.size()," complete ribbon skins");quit(1 if failures else 0)
