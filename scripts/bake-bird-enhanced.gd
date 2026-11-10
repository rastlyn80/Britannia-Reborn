# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-orc-enhanced.gd"

const BirdOutput := "res://../work/creatures/native-form-audit/enhanced-source-gaps/bird-only/bird-enhanced.scn"
const BirdJoints := ["spine", "neck", "head", "tail_base"]
# Group 26's profile turns through the opposite side over seven registered
# frames. These are world-space pitch and yaw estimates on the licensed rig.
const Glance: Array[Vector2] = [
	Vector2(0.00, 0.00), Vector2(.08, .15), Vector2(.27, .42), Vector2(.38, .61),
	Vector2(.29, .54), Vector2(.16, .31), Vector2(.05, .08),
]

func run() -> void:
	var source := Registry.asset_path(Registry.entry(6))
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	var settle := fit_grounded(player, rig, skins, .24, "root", BirdJoints, settle_pose, .0018)
	var glance := fit_grounded(player, rig, skins, .60, "root", BirdJoints, glance_pose, .0018)
	assert(library.add_animation("BirdQuietSettle", settle) == OK)
	assert(library.add_animation("BirdGlance", glance) == OK)
	Exact.check_earlier_keys(player, source)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, BirdOutput, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("BIRD ENHANCED: two source-guided movements on the retained CC0 rig")
	quit()

func settle_pose(rig: Skeleton3D, phase: float) -> void:
	# Hold the second source pose through the ordinary 120 ms action crossfade.
	var amount := smoothstep(0.0, .10 / .24, phase)
	turn_world(rig, "spine", Vector3.RIGHT, .035 * amount)
	turn_world(rig, "head", Vector3.RIGHT, -.060 * amount)
	turn_world(rig, "tail_base", Vector3.RIGHT, -.040 * amount)

func glance_pose(rig: Skeleton3D, phase: float) -> void:
	var frame := phase * (Glance.size() - 1)
	var index := mini(floori(frame), Glance.size() - 2)
	var angle := Glance[index].lerp(Glance[index + 1], smoothstep(0.0, 1.0, frame - index))
	turn_world(rig, "spine", Vector3.RIGHT, .30 * angle.x)
	turn_world(rig, "neck", Vector3.UP, .38 * angle.y)
	turn_world(rig, "head", Vector3.UP, .62 * angle.y)
	turn_world(rig, "head", Vector3.RIGHT, .70 * angle.x)
	turn_world(rig, "tail_base", Vector3.UP, -.16 * angle.y)
