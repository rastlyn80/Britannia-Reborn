# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const CatOutput := "res://../work/creatures/native-form-audit/enhanced-source-gaps/cat-enhanced/201-modern.scn"
const CatClips := {4: "CatSpring", 15: "CatTailRecoil", 25: "CatQuietStand",
	26: "CatListening", 27: "CatRearAndSwipe", 28: "CatStartle"}
const CatLengths := {4: 1.0, 15: .6, 25: .7, 26: 1.0, 27: .8, 28: .4}
const CatJoints := ["bip01", "bip01 spine", "bip01 neck", "bip01 head", "tail1", "tail2", "tail3",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 r thigh", "bip01 r calf"]

func run() -> void:
	var source := Registry.asset_path(Registry.entry(201))
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		skins.append(Ground.skin_points(mesh, rig))
	for group: int in CatClips:
		var clip := fit_grounded(player, rig, skins, CatLengths[group], "bip01", CatJoints, pose_cat.bind(group), .002)
		if group == 4:
			add_spring_travel(clip, rig, player)
		assert(library.add_animation(CatClips[group], clip) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, CatOutput, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("CAT ENHANCED: retained licensed rig, all original keys and six source-guided motions")
	quit()

func add_spring_travel(clip: Animation, rig: Skeleton3D, player: AnimationPlayer) -> void:
	var root_bone := rig.find_bone("bip01")
	var parent_bone := rig.get_bone_parent(root_bone)
	var parent_basis := Basis.IDENTITY if parent_bone < 0 else rig.get_bone_global_pose(parent_bone).basis
	var world_to_parent := (rig.global_basis * parent_basis).inverse()
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var track := clip.find_track(NodePath("%s:bip01" % rig_path), Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	var forward := (joint_world(rig, "bip01 head") - hind_midpoint(rig)).slide(Vector3.UP).normalized()
	for key in clip.track_get_key_count(track):
		var phase := clip.track_get_key_time(track, key) / clip.length
		var flight := envelope(phase, .15, .34, .44, .73)
		var travel := envelope(phase, .22, .56, .71, .98)
		var position: Vector3 = clip.track_get_key_value(track, key)
		clip.track_set_key_value(track, key, position + world_to_parent * (Vector3.UP * .26 * flight + forward * .13 * travel))

func envelope(phase: float, start: float, peak: float, hold: float, finish: float) -> float:
	return smoothstep(start, peak, phase) * (1.0 - smoothstep(hold, finish, phase))

func pose_cat(rig: Skeleton3D, phase: float, group: int) -> void:
	var forward := (joint_world(rig, "bip01 head") - hind_midpoint(rig)).slide(Vector3.UP).normalized()
	var pitch_axis := Vector3.UP.cross(forward)
	var pulse := sin(phase * PI)
	match group:
		4:
			var spring := envelope(phase, .07, .32, .38, .54)
			var reach := envelope(phase, .35, .53, .61, .76)
			var land := envelope(phase, .52, .74, .82, 1.0)
			turn_world(rig, "bip01", pitch_axis, -.85 * spring + .55 * land)
			turn_world(rig, "bip01 spine", pitch_axis, .30 * spring - .20 * land)
			turn_world(rig, "bip01 neck", pitch_axis, -.20 * spring - .17 * land)
			for side: String in ["l", "r"]:
				turn_world(rig, "bip01 %s upperarm" % side, pitch_axis, -1.26 * spring - .62 * reach)
				turn_world(rig, "bip01 %s forearm" % side, pitch_axis, .55 * spring)
				turn_world(rig, "bip01 %s thigh" % side, pitch_axis, .65 * spring + .20 * land)
				turn_world(rig, "bip01 %s calf" % side, pitch_axis, -.74 * spring)
			turn_world(rig, "tail1", pitch_axis, -.55 * reach - .24 * land)
		15:
			var recoil := envelope(phase, .04, .30, .47, 1.0)
			turn_world(rig, "bip01 spine", pitch_axis, .14 * recoil)
			turn_world(rig, "bip01 neck", pitch_axis, .22 * recoil)
			turn_world(rig, "bip01 head", pitch_axis, -.14 * recoil)
			turn_world(rig, "tail1", pitch_axis, -.35 * recoil)
			turn_world(rig, "tail2", Vector3.UP, .30 * sin(phase * TAU))
		25:
			turn_world(rig, "bip01 spine", pitch_axis, .024 * sin(TAU * phase))
			turn_world(rig, "tail2", Vector3.UP, .09 * sin(TAU * phase))
		26:
			turn_world(rig, "bip01 neck", pitch_axis, -.22 * pulse)
			turn_world(rig, "bip01 head", Vector3.UP, .30 * pulse)
			turn_world(rig, "tail3", Vector3.UP, .20 * sin(TAU * phase))
		27:
			var up := envelope(phase, .07, .31, .68, .96)
			var swipe := envelope(phase, .32, .51, .64, .86)
			var anchor := hind_midpoint(rig)
			turn_world(rig, "bip01", pitch_axis, -1.05 * up)
			turn_world(rig, "bip01 spine", Vector3.UP, -.22 * swipe)
			turn_world(rig, "bip01 neck", pitch_axis, .23 * up)
			for side: String in ["l", "r"]:
				turn_world(rig, "bip01 %s thigh" % side, pitch_axis, .62 * up)
				turn_world(rig, "bip01 %s calf" % side, pitch_axis, .19 * up)
				turn_world(rig, "bip01 %s upperarm" % side, pitch_axis, -.98 * up)
				turn_world(rig, "bip01 %s forearm" % side, pitch_axis, .72 * up)
			turn_world(rig, "bip01 r upperarm", Vector3.UP, -.48 * swipe)
			turn_world(rig, "tail1", pitch_axis, .62 * up)
			turn_world(rig, "tail2", Vector3.UP, .62 * swipe)
			var hip := rig.find_bone("bip01")
			var transform := rig.get_bone_global_pose(hip)
			transform.origin += rig.global_basis.inverse() * (anchor - hind_midpoint(rig)).slide(Vector3.UP)
			rig.set_bone_global_pose(hip, transform)
		28:
			var startle := envelope(phase, 0.0, .26, .35, 1.0)
			turn_world(rig, "bip01 spine", pitch_axis, -.10 * startle)
			turn_world(rig, "bip01 neck", pitch_axis, -.27 * startle)
			turn_world(rig, "bip01 head", pitch_axis, .12 * startle)
			turn_world(rig, "tail1", pitch_axis, -.40 * smoothstep(.14, .85, phase))
