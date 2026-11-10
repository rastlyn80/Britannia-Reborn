# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/pixie-frost-troll/"
const Pixie := {23: "PixieLightRise", 26: "PixieHoverWatch", 27: "PixieBankedHover", 28: "PixieWingAlert"}
const Frost := {12: "FrostTrollOpenPalm", 23: "FrostTrollCrouchedRise", 26: "FrostTrollKnuckleLook",
	27: "FrostTrollStaggerGuard", 28: "FrostTrollWideAlert"}
const PixieLengths := {23: 1.18, 26: 1.22, 27: .95, 28: .76}
const FrostLengths := {12: .92, 23: 1.09, 26: 1.31, 27: 1.0, 28: .76}
const Limbs := ["bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm",
	"bip01 r hand", "bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const Trunk := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head"]
const PixieWings := ["pixie l wing1", "pixie l wing2", "pixie l wing3", "pixie r wing1", "pixie r wing2", "pixie r wing3"]
const FrostHair := ["bip01 ponytail1", "bip01 ponytail11", "bip01 ponytail2", "bip01 ponytail21"]


func run() -> void:
	for body: int in [128, 55]:
		var row := Registry.entry(body)
		for treatment: String in Profile.registered_assets(row):
			bake_treatment(body, treatment, row)
	quit()


func bake_treatment(body: int, treatment: String, row: Dictionary) -> void:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_child("Body", true, false) as MeshInstance3D
	assert(mesh != null)
	var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var pixie := body == 128
	var clips := Pixie if pixie else Frost
	var lengths := PixieLengths if pixie else FrostLengths
	var joints := Trunk + Limbs + (PixieWings if pixie else FrostHair)
	for group: int in clips:
		var action := pose_pixie.bind(group) if pixie else pose_frost.bind(group)
		var motion := fit_grounded(player, rig, skins, lengths[group], "__root", joints, action, .005)
		if pixie:
			bake_pixie_lift(motion, player, rig, group)
		assert(library.add_animation(clips[group], motion) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("PIXIE AND FROST TROLL ", body, "/", treatment, ": ", clips.size(), " fitted motions")


func envelope(phase: float, begin: float, full: float, settle: float, end: float) -> float:
	return smoothstep(begin, full, phase) * (1.0 - smoothstep(settle, end, phase))


func bake_pixie_lift(motion: Animation, player: AnimationPlayer, rig: Skeleton3D, group: int) -> void:
	var root_path := NodePath("%s:__root" % player.get_node(player.root_node).get_path_to(rig))
	var position := motion.find_track(root_path, Animation.TYPE_POSITION_3D)
	assert(position >= 0)
	var up := rig.global_basis.inverse() * Vector3.UP
	for key in motion.track_get_key_count(position):
		var phase := motion.track_get_key_time(position, key) / motion.length
		var lift := .16 + .055 * sin(TAU * phase)
		if group == 23:
			lift = .018 + .36 * smoothstep(.15, .70, phase) - .16 * smoothstep(.75, 1.0, phase)
		elif group == 27:
			lift += .11 * envelope(phase, .12, .48, .62, .95)
		elif group == 28:
			lift += .17 * envelope(phase, .10, .38, .64, 1.0)
		var origin: Vector3 = motion.track_get_key_value(position, key)
		motion.track_set_key_value(position, key, origin + up * lift)


func pose_pixie(rig: Skeleton3D, phase: float, group: int) -> void:
	var hover := sin(TAU * phase)
	var emergence := 1.0 - smoothstep(.12, .72, phase) if group == 23 else 0.0
	var bank := envelope(phase, .08, .34, .63, .98) if group == 27 else 0.0
	var alert := envelope(phase, .12, .38, .55, .94) if group == 28 else 0.0
	var check := envelope(phase, .10, .48, .67, .96) if group == 26 else 0.0
	var beat := sin(TAU * phase * (4.0 if group == 23 else 3.0))
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, .32 * emergence - .23 * alert)
	turn_world(rig, "bip01 spine1", Vector3.BACK, .35 * bank + .046 * hover)
	turn_world(rig, "bip01 spine2", Vector3.UP, -.42 * bank + .21 * check)
	turn_world(rig, "bip01 head", Vector3.UP, .44 * check + .21 * bank)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.23 * emergence + .17 * alert)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var asymmetry := 1.0 + .22 * bank * sign
		var wing_angle := sign * (-.55 * emergence + .52 * alert + .54 * beat * asymmetry)
		turn_world(rig, "pixie %s wing1" % side, Vector3.UP, wing_angle)
		turn_world(rig, "pixie %s wing2" % side, Vector3.BACK, sign * (.23 * beat + .31 * bank))
		turn_world(rig, "pixie %s wing3" % side, Vector3.RIGHT, .24 * beat * asymmetry)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign * (.58 * bank + .74 * alert))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.49 * emergence - .32 * check * asymmetry)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.50 * emergence - .36 * alert * asymmetry)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .68 * emergence + .25 * bank)


func pose_frost(rig: Skeleton3D, phase: float, group: int) -> void:
	var attack := envelope(phase, .19, .54, .70, .98) if group == 12 else 0.0
	var ready := envelope(phase, .02, .23, .32, .56) if group == 12 else 0.0
	var crouch := 1.0 - smoothstep(.06, .78, phase) if group == 23 else 0.0
	var look := envelope(phase, .11, .45, .66, .97) if group == 26 else 0.0
	var stumble := envelope(phase, .02, .21, .39, .80) if group == 27 else 0.0
	var spread := smoothstep(.13, .64, phase) if group == 28 else .63 * stumble
	var yaw := -.60 * ready + .72 * attack + .31 * look - .34 * stumble
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, .42 * crouch + .14 * attack)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .52 * crouch - .32 * stumble + .16 * attack)
	turn_world(rig, "bip01 spine1", Vector3.UP, yaw)
	turn_world(rig, "bip01 spine2", Vector3.BACK, .24 * stumble - .18 * spread)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.31 * crouch + .37 * look - .19 * spread)
	turn_world(rig, "bip01 head", Vector3.UP, .31 * look - .29 * yaw)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var bias := 1.0 if side == "r" else .31
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, (-1.06 * attack + .54 * ready) * bias - .36 * crouch)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign * (.66 * spread + .24 * look))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.72 * crouch - .81 * look * bias - .37 * spread)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign * (.45 * spread + .32 * attack))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.81 * crouch - .47 * stumble * bias)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.22 * crouch + .45 * stumble * bias)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.38 * crouch - .23 * stumble * bias)
	var sway := sin(TAU * phase) * (.17 * attack + .22 * stumble + .12 * spread)
	for bone: String in FrostHair:
		turn_world(rig, bone, Vector3.BACK, sway)
