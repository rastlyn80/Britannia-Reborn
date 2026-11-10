# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/golem-sand-vortex/raptor-slith-source/"
const Raptor := {4: "RaptorRearAndSnap", 15: "RaptorDuckAndRecover", 23: "RaptorUncoil",
	25: "RaptorQuietWatch", 26: "RaptorHighSurvey", 27: "RaptorForwardStalk", 28: "RaptorClawAlert"}
const Slith := {4: "SlithHeadFeint", 15: "SlithCurlRecoil", 23: "SlithTailUncoil", 25: "SlithQuietCoast",
	26: "SlithNoseSweep", 27: "SlithCrestWarning", 28: "SlithGroundAlert"}
const Breath := "SlithFireBreath"
const NativeBreath := 100
const Durations := {4: .91, 15: .85, 23: 1.16, 25: .98, 26: 1.04, 27: .96, 28: .81}
const RaptorJoints := ["Body", "Torso", "Shoulders", "Neck", "Head", "Tail1", "Tail2", "Tail3", "Tail4",
	"Tail5", "FrontUpLeg.L", "FrontLowLeg.L", "FrontUpLeg.R", "FrontLowLeg.R"]
const SlithJoints := ["bip01 spine", "bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 head",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 l clavicle", "bip01 r clavicle",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf"]


func run() -> void:
	prepare_raptor()
	prepare_body(734, Slith.merged({NativeBreath: Breath}), Durations.merged({NativeBreath: 1.64}),
		SlithJoints + ["bip01 ponytail1"], pose_slith, Destination)
	quit()


func prepare_raptor() -> void:
	var row := Registry.entry(730)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skin := Ground.skin_points(model.find_child("Velociraptor", true, false), rig)
		for group: int in Raptor:
			var clip := fit_grounded(player, rig, [skin], Durations[group], "Body", RaptorJoints, pose_raptor.bind(group), .004)
			assert(library.add_animation(Raptor[group], clip) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, Destination + "730-%s.scn" % treatment,
			ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("RAPTOR ENHANCED ", treatment, ": seven source-fitted gestures on the retained CC0 rig")


func pose_raptor(rig: Skeleton3D, phase: float, group: int) -> void:
	var rear := 0.0
	var dip := 0.0
	var curl := 0.0
	var reach := 0.0
	match group:
		4:
			rear = envelope(phase, .0, .20, .28, .46)
			dip = envelope(phase, .23, .52, .68, .93)
			reach = .84 * dip
		15:
			dip = .82 * (1.0 - smoothstep(.16, .83, phase))
			curl = .35 * sin(PI * phase)
		23:
			rear = .97 * (1.0 - smoothstep(.19, .84, phase))
			curl = .91 * (1.0 - smoothstep(.32, .87, phase))
			reach = .25 * rear
		25:
			dip = .045 * sin(TAU * phase)
			curl = .06 * sin(TAU * phase)
		26:
			rear = .86 * envelope(phase, .08, .31, .46, .76)
			dip = .21 * envelope(phase, .59, .81, .90, .99)
		27:
			dip = .47 * envelope(phase, .15, .47, .69, .98)
			reach = .60 * dip
		28:
			reach = .60 * smoothstep(.08, .65, phase)
			dip = .29 * reach
	turn_world(rig, "Body", Vector3.RIGHT, -.22 * rear + .15 * dip)
	turn_world(rig, "Torso", Vector3.RIGHT, -.25 * rear + .15 * dip)
	turn_world(rig, "Shoulders", Vector3.RIGHT, -.23 * rear + .18 * dip)
	turn_world(rig, "Neck", Vector3.RIGHT, -.46 * rear + .30 * dip)
	turn_world(rig, "Head", Vector3.RIGHT, .19 * rear + .21 * dip)
	turn_world(rig, "Tail1", Vector3.RIGHT, -.15 + .28 * rear - .18 * dip)
	turn_world(rig, "Tail2", Vector3.RIGHT, -.16 + .22 * curl)
	turn_world(rig, "Tail3", Vector3.UP, -.42 * curl)
	turn_world(rig, "Tail4", Vector3.UP, -.46 * curl)
	turn_world(rig, "Tail5", Vector3.RIGHT, .21 * curl)
	for side: String in ["L", "R"]:
		turn_world(rig, "FrontUpLeg." + side, Vector3.RIGHT, -.61 * reach - .27 * rear)
		turn_world(rig, "FrontLowLeg." + side, Vector3.RIGHT, .43 * reach + .23 * dip)


func pose_slith(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var raise := 0.0
	var yaw := 0.0
	var curl := 0.0
	var step := 0.0
	match group:
		4:
			raise = .54 * envelope(phase, .05, .31, .48, .67)
			dip = .68 * envelope(phase, .38, .60, .76, .98)
			step = .58 * dip
		15:
			dip = .65 * (1.0 - smoothstep(.18, .87, phase))
			curl = .69 * envelope(phase, .03, .43, .60, .99)
		23:
			curl = .91 * (1.0 - smoothstep(.15, .80, phase))
			dip = .25 * curl
		25:
			dip = .042 * sin(TAU * phase)
			curl = .045 * sin(TAU * phase)
		26:
			yaw = .29 * envelope(phase, .0, .23, .44, .64)
			raise = .41 * envelope(phase, .02, .28, .49, .67)
			dip = .51 * envelope(phase, .42, .70, .82, .99)
		27:
			raise = .81 * envelope(phase, .07, .39, .60, .96)
			curl = .31 * sin(TAU * phase)
		28:
			dip = .26 * smoothstep(.13, .80, phase)
			yaw = -.29 * envelope(phase, .12, .42, .65, .98)
		NativeBreath:
			raise = .54 * envelope(phase, .08, .47, .58, .81)
			dip = .34 * envelope(phase, .55, .75, .85, .99)
			var jaw := envelope(phase, .38, .71, .87, 1.0)
			turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, .29 * jaw)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .20 * dip - .27 * raise)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .35 * dip - .37 * raise)
	turn_world(rig, "bip01 neck1", Vector3.UP, .67 * yaw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .22 * dip - .17 * raise)
	turn_world(rig, "bip01 head", Vector3.UP, .39 * yaw)
	turn_world(rig, "bip01 tail", Vector3.UP, .54 * curl)
	turn_world(rig, "bip01 tail1", Vector3.UP, .76 * curl)
	turn_world(rig, "bip01 tail2", Vector3.UP, .62 * curl)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .17 * dip - .13 * raise)
	for side: String in ["l", "r"]:
		var swing := step * (1.0 if side == "l" else -.61)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.38 * raise - .62 * swing)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .28 * raise + .26 * swing)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .24 * swing)
