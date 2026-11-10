# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Folder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/hound-black-bear/"
const HoundClips := {4: "HoundBowSnap", 15: "HoundRearBark", 25: "HoundQuietStand",
	26: "HoundScentCheck", 27: "HoundTailCheck", 28: "HoundAlert"}
const HoundLengths := {4: .60, 15: .60, 25: .90, 26: 1.0, 27: .60, 28: .50}
const BearClips := {4: "BlackBearHighSwipe", 15: "BlackBearUprightWarning", 23: "BlackBearWakeAndRise",
	25: "BlackBearQuietStand", 26: "BlackBearScentTurn", 27: "BlackBearRaisedGuard", 28: "BlackBearRearAlert"}
const BearLengths := {4: .70, 15: .50, 23: .90, 25: .90, 26: 1.0, 27: .70, 28: .70}
const RootJoint := "bip01 pelvis"
const CommonJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot",
	"bip01 ponytail1", "bip01 ponytail2", "bip01 tail"]

func run() -> void:
	prepare_body(217, HoundClips, HoundLengths, CommonJoints + ["bip01 neck1", "bip01 jaw", "bip01 tail1", "bip01 tail2"],
		pose_hound)
	prepare_body(211, BearClips, BearLengths, CommonJoints + ["bip01 spine2", "box01"], pose_bear)
	quit()

func prepare_body(body: int, clips: Dictionary, lengths: Dictionary, joints: Array, pose: Callable, destination: String = Folder, finish := Callable()) -> void:
	var row := Registry.entry(body)
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
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			skins.append(Ground.skin_points(mesh, rig))
		for group: int in clips:
			var motion := fit_grounded(player, rig, skins, lengths[group], RootJoint, joints, pose.bind(group), .004)
			if finish.is_valid():
				finish.call(motion, rig, group)
			assert(library.add_animation(clips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("HOUND AND BEAR ENHANCED ", body, "/", treatment, ": ", clips.size(), " fitted source gestures")

func anchor_hind_paws(rig: Skeleton3D, prior: Vector3) -> void:
	var root_joint := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(root_joint)
	hips.origin += rig.global_basis.inverse() * (prior - hind_midpoint(rig)).slide(Vector3.UP)
	rig.set_bone_global_pose(root_joint, hips)

func envelope(phase: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, phase) * (1.0 - smoothstep(c, d, phase))

func pose_hound(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := sin(PI * phase)
	var rear := 0.0
	var crouch := 0.0
	var look := 0.0
	var yaw := 0.0
	var wag := 0.0
	var bark := 0.0
	match group:
		4:
			crouch = .80 - .51 * envelope(phase, .10, .41, .48, .78)
			look = -.34 * pulse
			bark = .35 * envelope(phase, .23, .44, .54, .74)
		15:
			rear = envelope(phase, .07, .40, .51, .93)
			crouch = .74 * (1.0 - rear)
			look = -.27 * rear
			bark = .72 * rear
			wag = .27 * pulse
		25:
			look = .032 * sin(TAU * phase)
		26:
			var scent := envelope(phase, .01, .25, .70, .98)
			crouch = .18 * scent
			look = .55 * scent - .12 * sin(TAU * phase)
			yaw = .17 * sin(TAU * phase) * pulse
		27:
			crouch = .48
			look = .25 + .19 * sin(TAU * phase)
			wag = .36 * sin(TAU * phase)
		28:
			crouch = .55 * smoothstep(.09, .83, phase)
			look = .28 * smoothstep(.14, .91, phase)
			yaw = -.15 * pulse
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, -.56 * rear + .10 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.31 * rear + .56 * crouch)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, look + .20 * rear + .16 * crouch)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .27 * look)
	turn_world(rig, "bip01 head", Vector3.UP, yaw)
	turn_world(rig, "bip01 jaw", Vector3.RIGHT, bark)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.21 * rear - .24 * crouch)
	turn_world(rig, "bip01 tail1", Vector3.UP, wag)
	turn_world(rig, "bip01 tail2", Vector3.UP, wag * .52)
	turn_world(rig, "bip01 ponytail1", Vector3.BACK, .36 * rear + .08 * pulse)
	turn_world(rig, "bip01 ponytail2", Vector3.BACK, -.36 * rear - .08 * pulse)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.53 * crouch - .44 * rear)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .20 * crouch + .78 * rear)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .43 * rear)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.18 * rear)
	anchor_hind_paws(rig, anchor)

func pose_bear(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := sin(PI * phase)
	var rear := 0.0
	var crouch := 0.0
	var turn_head := 0.0
	var threat := 0.0
	var swipe := 0.0
	match group:
		4:
			rear = .84 + .12 * pulse
			swipe = envelope(phase, .01, .30, .40, .80)
			threat = .38 + .33 * pulse
		15:
			rear = .83 + .06 * pulse
			threat = .46 + .32 * pulse
			turn_head = -.20 * pulse
		23:
			crouch = 1.0 - smoothstep(.26, .96, phase)
			turn_head = .13 * pulse
		25:
			turn_world(rig, "bip01 spine2", Vector3.RIGHT, .024 * sin(TAU * phase))
		26:
			turn_head = .46 * sin(TAU * phase) * pulse
			crouch = .19 * (1.0 - smoothstep(.46, .72, phase))
		27:
			rear = .90 + .08 * pulse
			threat = .67 + .32 * pulse
			turn_head = .27 * pulse
		28:
			rear = .77 * smoothstep(.64, .98, phase)
			crouch = .39 * envelope(phase, .02, .39, .58, .74)
			threat = .37 * smoothstep(.71, .98, phase)
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, -1.24 * rear + .22 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .11 * rear + .30 * crouch)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .14 * rear + .26 * crouch)
	turn_world(rig, "bip01 neck", Vector3.UP, turn_head * .48)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .18 * rear - .17 * crouch)
	turn_world(rig, "bip01 head", Vector3.UP, turn_head * .62)
	turn_world(rig, "box01", Vector3.RIGHT, .17 * threat)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var striking := swipe if side == "r" else 0.0
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .92 * rear - .36 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .16 * rear + .48 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .18 * rear - .20 * crouch)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, .26 * rear - .60 * striking - .58 * crouch)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (.24 * rear + .74 * threat + .43 * striking))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.62 * rear - .32 * striking + .82 * crouch)
		turn_world(rig, "bip01 %s hand" % side, Vector3.RIGHT, .15 * rear - .38 * crouch)
	anchor_hind_paws(rig, anchor)
