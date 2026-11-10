# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const LichGamanStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/lich-gaman/"
const LichClips := {23: "LichCoilingRise", 28: "LichRaisedWard"}
const LichLengths := {23: 1.16, 28: .60}
const GamanClips := {1: "GamanLowWatch", 4: "GamanShoulderLunge", 11: "GamanNoseDip",
	15: "GamanHornRecoil", 23: "GamanRearAndSettle", 27: "GamanShortShove", 28: "GamanHeadAlert"}
const GamanLengths := {1: .85, 4: .88, 11: .96, 15: .68, 23: 1.13, 27: .83, 28: .70}
const LichJoints := ["__root", "bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2",
	"bip01 neck", "bip01 head", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand",
	"bip01 r upperarm", "bip01 r forearm", "bip01 r hand", "bip01 l thigh", "bip01 l calf",
	"bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const GamanJoints := ["bip01", "bip01 pelvis", "bip01 spine1", "bip01 neck", "bip01 head", "jawbone", "bip01 tail",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	for body: int in [24, 248]:
		var row := Registry.entry(body)
		for treatment: String in row.assets:
			bake_fit(body, treatment, row)
	quit()


func bake_fit(body: int, treatment: String, row: Dictionary) -> void:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
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
	var clips := LichClips if body == 24 else GamanClips
	for group: int in clips:
		var motion: Animation
		if body == 24:
			motion = fit_grounded(player, rig, skins, LichLengths[group], "__root", LichJoints,
				pose_lich.bind(group), .005)
			if group == 23:
				add_rise_scale(motion, player, rig)
		else:
			motion = fit_grounded(player, rig, skins, GamanLengths[group], "bip01", GamanJoints,
				pose_gaman.bind(group), .004)
		assert(library.add_animation(clips[group], motion) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, LichGamanStage + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("LICH AND GAMAN ENHANCED ", body, "/", treatment, ": ", clips.size(), " fitted gestures")


func rise_scale(phase: float) -> float:
	return lerpf(.045, 1.0, smoothstep(.03, .57, phase))


func add_rise_scale(motion: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var path := NodePath("%s:__root" % player.get_node(player.root_node).get_path_to(rig))
	var scale := motion.find_track(path, Animation.TYPE_SCALE_3D)
	if scale < 0:
		scale = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(scale, path)
	else:
		motion.track_remove_key(scale, 0)
	for frame in 81:
		var phase := float(frame) / 80.0
		motion.scale_track_insert_key(scale, phase * motion.length, Vector3.ONE * rise_scale(phase))


func pose_lich(rig: Skeleton3D, phase: float, group: int) -> void:
	var coil := 0.0
	var lift := 0.0
	var ward := 0.0
	if group == 23:
		coil = 1.0 - smoothstep(.10, .72, phase)
		lift = envelope(phase, .13, .37, .52, .82)
		rig.set_bone_pose_scale(rig.find_bone("__root"), Vector3.ONE * rise_scale(phase))
		turn_world(rig, "__root", Vector3.UP, 1.58 * coil)
	else:
		ward = smoothstep(.02, .26, phase) * (1.0 - .26 * smoothstep(.70, 1.0, phase))
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, .39 * coil + .13 * ward)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .34 * coil - .23 * lift)
	turn_world(rig, "bip01 spine1", Vector3.UP, -.58 * coil + .19 * ward)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.36 * lift - .08 * ward)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.32 * coil + .13 * ward)
	turn_world(rig, "bip01 l upperarm", Vector3.BACK, .93 * lift + 1.59 * ward)
	turn_world(rig, "bip01 l forearm", Vector3.BACK, .28 * ward)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -1.42 * lift - .71 * ward)
	turn_world(rig, "bip01 l hand", Vector3.RIGHT, .29 * ward)
	turn_world(rig, "bip01 r upperarm", Vector3.BACK, -.68 * lift - .31 * ward)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -.85 * lift - .32 * ward)
	turn_world(rig, "bip01 r hand", Vector3.UP, .47 * coil)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.57 * coil - .13 * ward)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .92 * coil + .27 * ward)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.57 * coil - .18 * ward)


func pose_gaman(rig: Skeleton3D, phase: float, group: int) -> void:
	var lift := 0.0
	var dip := 0.0
	var look := 0.0
	var bite := 0.0
	var drive := 0.0
	var trail := 0.0
	match group:
		1:
			dip = .12 + .034 * sin(TAU * phase)
			bite = .19 + .046 * sin(TAU * phase)
			trail = .10 * sin(TAU * phase)
		4:
			var coil := envelope(phase, .03, .25, .35, .60)
			dip = .49 * coil
			drive = envelope(phase, .27, .48, .58, .82)
			lift = .28 * drive
			bite = .58 * drive
			trail = -.34 * drive
		11:
			dip = .34 * envelope(phase, .16, .40, .70, 1.0)
			look = .29 * sin(TAU * phase) * sin(PI * phase)
		15:
			var tuck := envelope(phase, .00, .26, .56, .92)
			lift = .18 * (1.0 - smoothstep(.02, .36, phase))
			dip = .51 * tuck
			bite = .23 * tuck
		23:
			var rear := envelope(phase, .13, .48, .64, .97)
			lift = .78 * rear
			dip = .18 * envelope(phase, .0, .15, .20, .39)
			bite = .55 * rear
			trail = -.24 * rear
		27:
			drive = .43 * envelope(phase, .08, .28, .36, .66)
			lift = .19 * drive
			look = -.32 * envelope(phase, .12, .37, .50, .85)
			trail = .30 * sin(TAU * phase) * sin(PI * phase)
		28:
			lift = .18 * envelope(phase, .06, .40, .69, 1.0)
			look = -.17 * sin(PI * phase)
	var anchor := hind_midpoint(rig)
	turn_world(rig, "bip01", Vector3.RIGHT, -.61 * lift + .10 * dip)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.32 * lift + .23 * dip + .13 * drive)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.44 * lift + .43 * dip)
	turn_world(rig, "bip01 neck", Vector3.UP, .57 * look)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.26 * lift + .19 * dip - .32 * drive)
	turn_world(rig, "bip01 head", Vector3.UP, .50 * look)
	turn_world(rig, "jawbone", Vector3.RIGHT, -bite)
	turn_world(rig, "bip01 tail", Vector3.UP, .46 * look + trail)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, .23 * lift)
	for side: String in ["l", "r"]:
		var forward_weight := 1.0 if side == "r" else .52
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.39 * dip - .52 * drive * forward_weight + .43 * lift)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .53 * dip + .29 * drive + .77 * lift)
		turn_world(rig, "bip01 %s hand" % side, Vector3.RIGHT, -.20 * dip + .13 * drive - .31 * lift)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .49 * lift - .14 * dip)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.27 * lift + .29 * dip)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .11 * lift - .15 * dip)
	var root_joint := rig.find_bone("bip01")
	var base := rig.get_bone_global_pose(root_joint)
	base.origin += rig.global_basis.inverse() * (anchor - hind_midpoint(rig)).slide(Vector3.UP)
	rig.set_bone_global_pose(root_joint, base)
