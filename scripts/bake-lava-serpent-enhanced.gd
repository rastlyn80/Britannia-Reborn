# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/ratman-mage-lava-serpent/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Clips := {4: "LavaSerpentCoilLash", 23: "LavaSerpentThreadEmergence", 28: "LavaSerpentCoiledAlert"}
const Durations := {4: .88, 23: 1.13, 28: .68}
const Breath := "LavaSerpentFireBreath"
const BreathDuration := 1.7


func run() -> void:
	var row := Registry.entry(90)
	for treatment: String in Profile.registered_assets(row):
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var skins: Array[Dictionary] = [Ground.skin_points(body, rig)]
		var lib := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", lib)
		for group: int in Clips:
			var clip := fit_grounded(player, rig, skins, Durations[group], RootJoint,
				Neck + Tail + ["bip01 ponytail1"], pose_lava.bind(group), .006)
			if group == 23:
				offset_root(clip, rig, func(phase: float): return -emergence_depth(phase))
			assert(lib.add_animation(Clips[group], clip) == OK)
		var breath := fit_grounded(player, rig, skins, BreathDuration, RootJoint,
			Neck + Tail + ["bip01 ponytail1"], pose_breath, .006)
		assert(lib.add_animation(Breath, breath) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "90-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("LAVA SERPENT ENHANCED ", treatment, ": retained keys, three fitted actions and native Fire Breath")
	quit()


static func emergence_depth(phase: float) -> float:
	return .63 * (1.0 - smoothstep(.02, .87, phase))


func pose_breath(rig: Skeleton3D, phase: float) -> void:
	var draw := envelope(phase, .05, .46, .58, .77)
	var release := envelope(phase, .56, .75, .83, .99)
	var forward := (joint_world(rig, Neck[-1]) - joint_world(rig, Neck[0])).slide(Vector3.UP).normalized()
	for index in Neck.size() - 1:
		var fraction := float(index) / (Neck.size() - 2)
		var arc := lerpf(.44, -.68, fraction) * draw + lerpf(.04, -.11, fraction) * release
		var direction := forward.rotated(Vector3.UP, arc)
		direction += Vector3.UP * (draw * lerpf(.25, 1.02, fraction) + release * lerpf(.30, -.27, fraction))
		aim_chain(rig, Neck[index], Neck[index + 1], direction, .22 + .62 * maxf(draw, release))
	var pitch := forward.cross(Vector3.UP)
	turn_world(rig, Neck[-1], pitch, -.19 * draw + .17 * release)
	turn_world(rig, "bip01 ponytail1", pitch, -.12 * draw - .72 * release)
	for index in range(1, Tail.size()):
		turn_world(rig, Tail[index], Vector3.UP, -.26 * draw + .11 * release)


func pose_lava(rig: Skeleton3D, phase: float, group: int) -> void:
	var strike := 0.0
	var coil := 0.0
	var lift := 0.0
	var twist := 0.0
	match group:
		4:
			strike = envelope(phase, .13, .36, .42, .60)
			coil = .92 * (1.0 - strike)
			lift = .84 * (1.0 - strike) - .12 * strike
			twist = .25 * sin(TAU * phase)
		23:
			var emerges := smoothstep(.08, .85, phase)
			strike = .63 * (1.0 - emerges)
			coil = .73 * emerges
			lift = .24 + .50 * emerges
			twist = -.25 * sin(TAU * phase) * sin(PI * phase)
		28:
			var alert := smoothstep(.08, .83, phase)
			strike = .72 * (1.0 - alert)
			coil = .91 * alert
			lift = .18 + .68 * alert
			twist = .18 * sin(PI * phase)
	var forward := (joint_world(rig, Neck[-1]) - joint_world(rig, Neck[0])).slide(Vector3.UP).normalized()
	for index in Neck.size() - 1:
		var portion := float(index) / float(Neck.size() - 2)
		var direction := forward.rotated(Vector3.UP, lerpf(.54, -.58, portion) * coil + twist)
		direction += Vector3.UP * (lift * lerpf(.55, 1.18, portion) - .21 * strike)
		aim_chain(rig, Neck[index], Neck[index + 1], direction, .58 + .38 * maxf(strike, coil))
	var pitch := forward.cross(Vector3.UP)
	turn_world(rig, Neck[-1], pitch, -.26 * lift - .16 * strike)
	turn_world(rig, "bip01 ponytail1", pitch, -.55 * strike - .09 * sin(PI * phase))
	for index in range(1, Tail.size()):
		var lag := sin(TAU * phase - .5 * index)
		turn_world(rig, Tail[index], Vector3.UP, -.53 * coil + .25 * strike + .11 * lag)


func aim_chain(rig: Skeleton3D, root_name: String, child_name: String, direction: Vector3, amount: float) -> void:
	var joint := rig.find_bone(root_name)
	var child := rig.find_bone(child_name)
	var start := rig.get_bone_global_pose(joint).origin
	var end := rig.get_bone_global_pose(child).origin
	var target := start + rig.global_basis.inverse() * direction.normalized() * start.distance_to(end)
	Arms.aim(rig, joint, child, end.lerp(target, amount))
	rig.force_update_all_bone_transforms()
