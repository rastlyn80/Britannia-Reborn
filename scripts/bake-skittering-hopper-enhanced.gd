# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/skittering-hopper-fan-dancer/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Wings := preload("hopper-wing-shell.gd")
const Clips := {12: "HopperWingSignal", 23: "HopperUnfurl", 26: "HopperSettledWingWatch",
	27: "HopperRaisedWingBrace", 28: "HopperWingAlert"}
const Lengths := {12: 1.15, 23: 1.08, 26: 1.13, 27: 1.09, 28: .76}
const HopperJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3",
	"bip01 neck", "bip01 head", "bone01", "bip01 ponytail1", "bip01 ponytail11", "bip01 ponytail12",
	"bip01 ponytail2", "bip01 ponytail21", "bip01 ponytail22", "bip01 l upperarm", "bip01 l forearm",
	"bip01 r upperarm", "bip01 r forearm", "bip01 l thigh", "bip01 r thigh"]


func run() -> void:
	var row := Registry.entry(302)
	for treatment: String in Profile.registered_assets(row):
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.play("Idle", 0.0)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		var wings := Wings.new().build(model, rig)
		var skins: Array[Dictionary] = [Ground.skin_points(model.find_child("Body", true, false), rig), Ground.skin_points(wings, rig)]
		var joints := HopperJoints + Wings.Joints
		for group: int in Clips:
			var clip := fit_grounded(player, rig, skins, Lengths[group], "bip01", joints, pose_hopper.bind(group), .005)
			assert(library.add_animation(Clips[group], clip) == OK)
		verify_base_clips(player, source)
		add_folded_wings(player, rig)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "302-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("SKITTERING HOPPER ", treatment, ": five fitted motions on the retained rig with authored wing pairs")
	quit()


func add_folded_wings(player: AnimationPlayer, rig: Skeleton3D) -> void:
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: StringName in player.get_animation_list():
		if name in Clips.values():
			continue
		var animation := player.get_animation(name)
		for joint: String in Wings.Joints:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath("%s:%s" % [rig_path, joint]))
			var folded := rig.get_bone_rest(rig.find_bone(joint)).basis.get_rotation_quaternion()
			animation.rotation_track_insert_key(track, 0.0, folded)


func pulse(phase: float, start: float, peak: float, hold: float, end: float) -> float:
	return smoothstep(start, peak, phase) * (1.0 - smoothstep(hold, end, phase))


func pose_hopper(rig: Skeleton3D, phase: float, group: int) -> void:
	var opening := 0.0
	var lift := 0.0
	var crouch := 0.0
	var scan := 0.0
	var flick := 0.0
	match group:
		12:
			opening = .48 + .23 * pulse(phase, .17, .34, .72, 1.0)
			lift = .84 + .12 * sin(TAU * phase)
			flick = .48 * pulse(phase, .22, .44, .74, .99)
			crouch = .33 + .34 * flick
		23:
			var unroll := smoothstep(.12, .73, phase)
			opening = .09 + .62 * unroll
			lift = .31 + .39 * pulse(phase, .20, .53, .72, .99)
			crouch = .87 * (1.0 - unroll)
			scan = -.17 * pulse(phase, .16, .52, .64, 1.0)
		26:
			opening = .17 + .23 * pulse(phase, .17, .50, .68, .96)
			lift = .17 + .31 * sin(PI * phase)
			scan = .19 * sin(TAU * phase)
		27:
			opening = .37 + .23 * pulse(phase, .12, .41, .71, .99)
			lift = .65 + .13 * sin(TAU * phase)
			crouch = .22 * pulse(phase, .13, .49, .66, .96)
			scan = -.23 * smoothstep(.10, .66, phase)
		28:
			var alert := smoothstep(.09, .65, phase)
			opening = .12 + .63 * alert
			lift = .22 + .67 * alert
			crouch = .54 * pulse(phase, .06, .29, .45, .76)
			flick = .22 * alert
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .20 * crouch - .16 * lift)
	turn_world(rig, "bip01 spine2", Vector3.UP, .38 * scan)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, .22 * crouch - .14 * lift)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.23 * crouch + .16 * lift)
	turn_world(rig, "bip01 head", Vector3.UP, .62 * scan)
	turn_world(rig, "bone01", Vector3.RIGHT, .28 * flick)
	for side in 2:
		var name := "l" if side == 0 else "r"
		var sign_x := 1.0 if side == 0 else -1.0
		var antenna := "bip01 ponytail%d" % (side + 1)
		turn_world(rig, antenna, Vector3.RIGHT, -.41 * flick + .14 * lift)
		turn_world(rig, antenna, Vector3.UP, sign_x * (.33 * flick + .11 * opening) + .25 * scan)
		turn_world(rig, antenna + "1", Vector3.RIGHT, -.34 * flick * sin(2.0 * PI * phase + side))
		turn_world(rig, antenna + "2", Vector3.RIGHT, -.31 * flick)
		turn_world(rig, "bip01 %s upperarm" % name, Vector3.RIGHT, .25 * crouch - .15 * lift)
		turn_world(rig, "bip01 %s forearm" % name, Vector3.RIGHT, -.24 * crouch + .18 * lift)
		turn_world(rig, "bip01 %s thigh" % name, Vector3.RIGHT, -.15 * crouch)
		var lateral := opening + sign_x * .18 * scan
		turn_world(rig, Wings.Joints[side], Vector3.RIGHT, lift)
		turn_world(rig, Wings.Joints[side], Vector3.UP, -sign_x * lateral)
		turn_world(rig, Wings.Joints[side + 2], Vector3.RIGHT, .76 * lift + .09 * flick)
		turn_world(rig, Wings.Joints[side + 2], Vector3.UP, -sign_x * (lateral + .15 * opening))
