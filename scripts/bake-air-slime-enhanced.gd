# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const AirSlimeStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/air-slime/"
const Aim := preload("res://Presentation/ElementalClassicGestures.gd")
const AirClips := {23: "AirVortexFormation", 28: "AirSpreadAlert"}
const SlimeClips := {4: "SlimeCrestLash", 25: "SlimeQuietPulse"}
const AirJoints := ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]
const SlimeJoints := [RootJoint, "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head", "bip01 tail", "bip01 tail1",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"]

func run() -> void:
	bake_air()
	prepare_body(51, SlimeClips, {4: .68, 25: 1.02}, SlimeJoints, pose_slime, AirSlimeStage)
	quit()

func bake_air() -> void:
	var entry := Registry.entry(13)
	var source := Registry.asset_path(entry)
	assert(FileAccess.get_sha256(source) == entry.asset_sha256)
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
	for group: int in AirClips:
		var motion := fit_grounded(player, rig, skins, 1.25 if group == 23 else .58, "root",
			AirJoints, pose_air.bind(group), .005)
		if group == 23:
			add_vortex_scale(motion, rig, player)
		assert(library.add_animation(AirClips[group], motion) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, AirSlimeStage + "13-modern.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("AIR ELEMENTAL ENHANCED: vortex formation and spread alert fitted on the retained wind carrier")

func add_vortex_scale(clip: Animation, rig: Skeleton3D, player: AnimationPlayer) -> void:
	var path := NodePath("%s:root" % player.get_node(player.root_node).get_path_to(rig))
	var scale_track := clip.find_track(path, Animation.TYPE_SCALE_3D)
	if scale_track < 0:
		scale_track = clip.add_track(Animation.TYPE_SCALE_3D)
		clip.track_set_path(scale_track, path)
	else:
		clip.track_remove_key(scale_track, 0)
	for frame in 81:
		var phase := float(frame) / 80.0
		var radius := lerpf(.055, 1.0, smoothstep(.01, .70, phase))
		var height := lerpf(.042, 1.0, smoothstep(.10, .69, phase))
		clip.scale_track_insert_key(scale_track, phase * clip.length, Vector3(radius, height, radius))

func pose_air(rig: Skeleton3D, phase: float, group: int) -> void:
	var spiral := 0.0
	var tuck := 0.0
	var spread := 0.0
	if group == 23:
		spiral = 2.28 * (1.0 - smoothstep(.08, .74, phase))
		tuck = 1.0 - smoothstep(.16, .56, phase)
		spread = envelope(phase, .25, .54, .80, .98)
	else:
		spread = .90 * envelope(phase, .08, .38, .72, .99)
	turn_world(rig, "root", Vector3.UP, spiral)
	turn_world(rig, "spine_01", Vector3.RIGHT, .34 * tuck - .10 * spread)
	turn_world(rig, "spine_02", Vector3.RIGHT, .28 * tuck)
	turn_world(rig, "spine_03", Vector3.BACK, .17 * spread * sin(TAU * phase))
	turn_world(rig, "Head", Vector3.RIGHT, -.26 * tuck - .15 * spread)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var upper := rig.find_bone("upperarm_" + side)
		var fore := rig.find_bone("lowerarm_" + side)
		var hand := rig.find_bone("hand_" + side)
		Aim.aim(rig, upper, fore, Vector3(sign_x, .16, .20), spread)
		Aim.aim(rig, fore, hand, Vector3(sign_x, -.14, .16), spread)
		Aim.aim(rig, upper, fore, Vector3(-sign_x * .50, -.45, .73), tuck)
		Aim.aim(rig, fore, hand, Vector3(-sign_x * .48, .42, .38), tuck)

func pose_slime(rig: Skeleton3D, phase: float, group: int) -> void:
	if group == 25:
		var pulse := sin(TAU * phase)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.054 * pulse)
		turn_world(rig, "bip01 tail", Vector3.RIGHT, .07 * pulse)
		turn_world(rig, "bip01 neck", Vector3.UP, .060 * pulse)
		return
	var rise := envelope(phase, .00, .21, .45, .83)
	var lash := envelope(phase, .11, .29, .38, .72)
	var spread := envelope(phase, .66, .86, .95, 1.0)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, -1.06 * rise + .12 * spread)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.68 * rise + .36 * lash)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.15 * rise + .57 * lash)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .63 * lash)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, .34 * rise)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.UP, -sign_x * (.51 * rise + .14 * spread))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .39 * lash)
