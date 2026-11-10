# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Aim := preload("res://Presentation/ElementalClassicGestures.gd")
const SandGeometry := preload("res://Presentation/SandVortexGeometry.gd")
const Donor := "res://Art/Creatures/Air/air-elemental.scn"
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/golem-sand-vortex/"
const SandClips := {4: "SandVortexTwinSweep", 15: "SandVortexCoilRecoil", 23: "SandVortexDustRise",
	25: "SandVortexQuietSpiral", 26: "SandVortexGather", 27: "SandVortexCurl", 28: "SandVortexReachAlert"}
const SandLengths := {4: 1.08, 15: .87, 23: 1.30, 25: .92, 26: .93, 27: 1.02, 28: .78}
const SandJoints := ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]


func run() -> void:
	var air := Registry.entry(13)
	assert(Registry.asset_path(air) == Donor and FileAccess.get_sha256(Donor) == air.asset_sha256)
	var model := (load(Donor) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	SandGeometry.fit(model.find_child("CloudBody", true, false), rig)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	for group: int in SandClips:
		var motion := fit_grounded(player, rig, skins, SandLengths[group], "root", SandJoints,
			pose_sand.bind(group), .004)
		if group == 23:
			add_growth(motion, rig, player)
		assert(library.add_animation(SandClips[group], motion) == OK)
	verify_base_clips(player, Donor)
	var original := (load(Registry.asset_path(Registry.entry(790))) as PackedScene).instantiate()
	var original_player := original.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: String in library.get_animation_list():
		if not original_player.has_animation(clip) and clip not in SandClips.values():
			library.remove_animation(clip)
	original.free()
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, Destination + "790-modern.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("SAND VORTEX ENHANCED: seven fitted gestures, retained GPL wind geometry and CC0 rig")
	quit()


func growth_scale(phase: float) -> Vector3:
	var radius := lerpf(.40, 1.0, smoothstep(.08, .76, phase))
	var height := lerpf(.042, 1.0, smoothstep(.15, .77, phase))
	return Vector3(radius, height, radius)


func add_growth(motion: Animation, rig: Skeleton3D, player: AnimationPlayer) -> void:
	var path := NodePath("%s:root" % player.get_node(player.root_node).get_path_to(rig))
	var channel := motion.find_track(path, Animation.TYPE_SCALE_3D)
	if channel < 0:
		channel = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(channel, path)
	else:
		motion.track_remove_key(channel, 0)
	for frame in 81:
		var phase := float(frame) / 80.0
		motion.scale_track_insert_key(channel, phase * motion.length, growth_scale(phase))


func pose_sand(rig: Skeleton3D, phase: float, group: int) -> void:
	var lean := 0.0
	var turn := 0.0
	var gather := 0.0
	var open := 0.0
	var lift := 0.0
	match group:
		4:
			gather = .83 * envelope(phase, .0, .23, .34, .61)
			open = .97 * envelope(phase, .35, .64, .79, .99)
			lean = .41 * gather - .25 * open
			turn = -.45 * gather + .43 * open
		15:
			gather = .52 + .29 * envelope(phase, .07, .44, .59, .90)
			lean = .26 * gather
			turn = -.24 * sin(PI * phase)
			lift = .51 * gather
		23:
			turn = -2.70 * (1.0 - smoothstep(.03, .76, phase))
			gather = 1.0 - smoothstep(.17, .52, phase)
			lift = .88 * envelope(phase, .33, .61, .70, .92)
			lean = .26 * gather - .19 * lift
		25:
			lean = .052 * sin(TAU * phase)
			turn = .07 * sin(PI * phase)
		26:
			gather = .64 * envelope(phase, .06, .37, .59, .96)
			lean = .25 * gather
			turn = .28 * gather
		27:
			gather = .88 * envelope(phase, .09, .31, .42, .78)
			open = .69 * envelope(phase, .49, .72, .84, .99)
			lift = .61 * gather
			lean = .42 * gather - .22 * open
			turn = -.39 * gather + .25 * open
		28:
			open = .62 * smoothstep(.12, .83, phase)
			lift = .54 * open
			lean = .21 * open
			turn = -.33 * open
	turn_world(rig, "spine_01", Vector3.RIGHT, .41 * lean)
	turn_world(rig, "spine_02", Vector3.RIGHT, .37 * lean)
	turn_world(rig, "spine_03", Vector3.UP, .72 * turn if group != 23 else .11 * turn)
	turn_world(rig, "Head", Vector3.RIGHT, -.24 * lean - .17 * lift)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var high := lift if side == "r" else lift * .34
		var upper := rig.find_bone("upperarm_" + side)
		var fore := rig.find_bone("lowerarm_" + side)
		var hand := rig.find_bone("hand_" + side)
		Aim.aim(rig, upper, fore, Vector3(sign_x * .73, .26 + high, .70), open)
		Aim.aim(rig, fore, hand, Vector3(sign_x * .57, .12 + high, .75), open)
		Aim.aim(rig, upper, fore, Vector3(sign_x * .76, -.25, .70), gather)
		Aim.aim(rig, fore, hand, Vector3(sign_x * .40, .62, .68), gather)
		Aim.aim(rig, upper, fore, Vector3(sign_x * .23, .90, .35), high)
		Aim.aim(rig, fore, hand, Vector3(-sign_x * .08, .91, .37), high)
	turn_world(rig, "root", Vector3.UP, turn * (.84 if group == 23 else .26))
	# The arm solver needs orthonormal parent bases. Flatten the assembled pose afterward.
	if group == 23:
		rig.set_bone_pose_scale(rig.find_bone("root"), growth_scale(phase))
		rig.force_update_all_bone_transforms()
