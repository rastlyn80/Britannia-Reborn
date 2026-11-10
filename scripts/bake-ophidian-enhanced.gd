# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-ophidian-bardiche-actions.gd"

const SerpentStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/tsuki-wolf-ophidian/"
const WarriorClips := {12: "OphidianOverheadThrust", 23: "OphidianUncoilRise", 26: "OphidianShaftWatch",
	27: "OphidianHighGuard", 28: "OphidianBladeAlert"}
const WarriorLengths := {12: 1.02, 23: 1.22, 26: 1.02, 27: 1.06, 28: .84}
const WarriorJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4", BARDICHE]

func _initialize() -> void:
	create_timer(185.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(86)
	for treatment: String in row.assets:
		var source: String = row.assets[treatment]
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		bake_actions(source, SerpentStage + "86-%s.scn" % treatment)
	quit()

func bake_actions(source: String, output: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var prop := model.find_child("OphidianBardiche", true, false) as MeshInstance3D
	var points: PackedVector3Array = prop.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(body != prop)
	var clearance := Clearance.new(body, rig)
	var skin := Ground.skin_points(body, rig)
	var weapon := rig.find_bone(BARDICHE)
	var grip := rig.find_bone("cp_grasp_rhand")
	assert(weapon >= 0 and grip >= 0 and rig.get_bone_parent(weapon) == grip)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for group: int in WarriorClips:
		var name: String = WarriorClips[group]
		assert(library.add_animation(name, fit_warrior(player, rig, skin, grip, weapon, group)) == OK)
		fit_clip(player, rig, grip, weapon, points, clearance, name)
	Exact.check_earlier_keys(player, source)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func fit_warrior(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, grip: int,
		weapon: int, group: int) -> Animation:
	var result := player.get_animation("Idle").duplicate(true) as Animation
	result.length = WarriorLengths[group]
	result.loop_mode = Animation.LOOP_NONE
	for track in result.get_track_count():
		for key in range(result.track_get_key_count(track) - 1, 0, -1):
			result.track_remove_key(track, key)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for name: String in WarriorJoints:
		var node := NodePath("%s:%s" % [path, name])
		var track := result.find_track(node, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = result.add_track(Animation.TYPE_ROTATION_3D)
			result.track_set_path(track, node)
		tracks[rig.find_bone(name)] = track
	var position := NodePath("%s:bip01" % path)
	var placement := result.find_track(position, Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = result.add_track(Animation.TYPE_POSITION_3D)
		result.track_set_path(placement, position)
	var root_joint := rig.find_bone("bip01")
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var shaft := pose_warrior(rig, phase, group)
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var desired := (socket.basis.inverse() * shaft.normalized()).normalized()
		rig.set_bone_pose_rotation(weapon, Quaternion(Vector3.UP, desired))
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var root_pose := rig.get_bone_global_pose(root_joint)
		root_pose.origin += rig.global_basis.inverse() * Vector3.UP * (.006 - gap)
		rig.set_bone_global_pose(root_joint, root_pose)
		var time := phase * result.length
		result.position_track_insert_key(placement, time, rig.get_bone_pose_position(root_joint))
		for joint: int in tracks:
			result.rotation_track_insert_key(tracks[joint], time, rig.get_bone_pose_rotation(joint))
	return result

func pulse(phase: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, phase) * (1.0 - smoothstep(c, d, phase))

func pose_warrior(rig: Skeleton3D, phase: float, group: int) -> Vector3:
	var lift := 0.0
	var strike := 0.0
	var coil := 0.0
	var guard := 0.0
	var turn_head := 0.0
	var tip := 0.0
	var shaft := Vector3(-.18, .80, .55)
	match group:
		12:
			lift = 1.0 - smoothstep(.25, .62, phase)
			strike = pulse(phase, .37, .59, .81, 1.0)
			coil = .52 * strike
			shaft = Vector3(-.25, .61, .76).lerp(Vector3(-.14, .18, .98), strike)
		23:
			coil = 1.0 - smoothstep(.10, .71, phase)
			lift = .58 * pulse(phase, .18, .48, .70, 1.0)
			tip = .70 * pulse(phase, .17, .52, .69, .98)
			shaft = Vector3(-.82, .42, .39).lerp(Vector3(-.32, .75, .55), 1.0 - coil)
		26:
			guard = .27 * pulse(phase, .06, .35, .62, .97)
			turn_head = .31 * sin(TAU * phase) * sin(PI * phase)
			shaft = shaft.lerp(Vector3(-.50, .71, .49), guard)
		27:
			lift = .76 + .18 * sin(PI * phase)
			guard = .62 * pulse(phase, .11, .46, .66, 1.0)
			tip = .30 * sin(TAU * phase)
			shaft = Vector3(-.81, .36, .47).lerp(Vector3(-.53, .73, .43), guard)
		28:
			coil = .48 * smoothstep(.12, .84, phase)
			guard = .45 * pulse(phase, .04, .41, .61, .99)
			shaft = shaft.lerp(Vector3(-.50, .42, .76), guard + .43 * coil)
	turn(rig, "bip01 pelvis", Vector3.RIGHT, .42 * coil)
	turn(rig, "bip01 spine", Vector3.RIGHT, .45 * coil + .29 * strike)
	turn(rig, "bip01 spine1", Vector3.RIGHT, .42 * coil - .17 * lift)
	turn(rig, "bip01 spine2", Vector3.UP, .18 * guard - .34 * strike)
	turn(rig, "bip01 neck", Vector3.RIGHT, -.38 * coil + .11 * strike)
	turn(rig, "bip01 head", Vector3.UP, turn_head)
	turn(rig, "bip01 r upperarm", Vector3.RIGHT, -1.77 * lift - .91 * strike + .49 * coil)
	turn(rig, "bip01 r forearm", Vector3.RIGHT, -.68 * lift - .38 * strike + .43 * coil)
	turn(rig, "bip01 r hand", Vector3.UP, .31 * guard)
	turn(rig, "bip01 l upperarm", Vector3.RIGHT, -.63 * guard - .50 * strike + .36 * coil)
	turn(rig, "bip01 l forearm", Vector3.RIGHT, -.73 * guard - .41 * strike)
	for index in 5:
		var name := "bip01 tail" if index == 0 else "bip01 tail%d" % index
		var weight := float(index) / 4.0
		turn(rig, name, Vector3.UP, .38 * coil + .16 * sin(phase * TAU - weight * PI) * guard)
		turn(rig, name, Vector3.RIGHT, (.44 * coil + .40 * tip) * weight)
	return shaft
