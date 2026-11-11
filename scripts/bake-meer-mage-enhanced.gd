# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Body := 770
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/meer-mage-enhanced/"
const Clips := {4: "MeerMageCrossingStrike", 5: "MeerMageRaisedStrike", 6: "MeerMageShortThrust",
	10: "MeerMageRecoil", 15: "MeerMageCrossGuard", 25: "MeerMageQuietStand", 26: "MeerMageHipCheck"}
const Lengths := {4: .65, 5: .63, 6: .56, 10: .47, 15: .49, 25: .90, 26: .78}
const MageJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm",
	"bip01 r forearm", "bip01 l hand", "bip01 r hand", "bip01 l thigh", "bip01 r thigh", "bip01 l calf",
	"bip01 r calf", "bip01 l foot", "bip01 r foot", "bip01 ponytail1", "bip01 ponytail2"]
const WalkName := "MeerMageMeasuredWalk"
const WalkJoints := ["bip01 spine1", "bip01 spine2", "bip01 head", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm"]


func run() -> void:
	prepare_body(Body, Clips, Lengths, MageJoints, pose_mage, Destination, set_loop)
	var row := Registry.entry(Body)
	for treatment: String in row.assets:
		var path := Destination + "%d-%s.scn" % [Body, treatment]
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var walk := fitted_walk(player, rig)
		assert(player.get_animation_library("").add_animation(WalkName, walk) == OK)
		verify_base_clips(player, Registry.asset_path(row, treatment))
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("MEER MAGE ", treatment, " ", Clips.size() + 1, " fits / ", FileAccess.get_sha256(path))
	quit()


func set_loop(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		clip.loop_mode = Animation.LOOP_LINEAR


func fitted_walk(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var source := player.get_animation("Walk")
	var motion := source.duplicate(true) as Animation
	var path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for label: String in WalkJoints:
		var bone_path := NodePath("%s:%s" % [path, label])
		var track := motion.find_track(bone_path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, bone_path)
		else:
			for key in range(motion.track_get_key_count(track) - 1, -1, -1):
				motion.track_remove_key(track, key)
		tracks[label] = track
	var previous_loop := source.loop_mode
	source.loop_mode = Animation.LOOP_LINEAR
	motion.loop_mode = Animation.LOOP_LINEAR
	player.play("Walk", 0.0)
	player.advance(0.0)
	for sample in 65:
		var phase := float(sample) / 64.0
		var time := phase * motion.length
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var swing := sin(TAU * phase)
		turn_world(rig, "bip01 spine1", Vector3.UP, -.041 * swing)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, .035 + .027 * cos(2.0 * TAU * phase))
		turn_world(rig, "bip01 head", Vector3.UP, .034 * swing)
		for side: String in ["l", "r"]:
			var sign_x := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * .09)
			turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, sign_x * .12 * swing)
			turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.14 + sign_x * .07 * swing)
		for label: String in tracks:
			motion.rotation_track_insert_key(tracks[label], time, rig.get_bone_pose_rotation(rig.find_bone(label)))
	source.loop_mode = previous_loop
	return motion


func pose_mage(rig: Skeleton3D, phase: float, group: int) -> void:
	var wind := 0.0
	var strike := 0.0
	var lift := 0.0
	var guard := 0.0
	var turn := 0.0
	var hips := 0.0
	var recoil := 0.0
	var lead := 1.0
	match group:
		4:
			wind = envelope(phase, .02, .25, .36, .66)
			strike = .90 * envelope(phase, .27, .53, .68, .98)
			turn = .38 * wind - .53 * strike
		5:
			wind = .64 * envelope(phase, .01, .23, .39, .68)
			strike = .75 * envelope(phase, .29, .55, .67, .96)
			lift = .98 * envelope(phase, .02, .31, .41, .66)
			turn = -.26 * wind + .41 * strike
			lead = -1.0
		6:
			wind = .32 * envelope(phase, .01, .20, .38, .56)
			strike = .71 * envelope(phase, .19, .46, .54, .97)
			turn = .19 * wind - .23 * strike
		10:
			recoil = envelope(phase, .0, .23, .35, .88)
			turn = -.28 * recoil
			guard = .43 * recoil
		15:
			guard = envelope(phase, .0, .40, .61, .97)
			turn = .23 * guard
		26:
			hips = envelope(phase, .04, .32, .69, .98)
			turn = .29 * sin(TAU * phase) * hips
		25:
			turn = .024 * sin(TAU * phase)
			hips = .021 * (1.0 - cos(TAU * phase))
	var feet := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.UP, .22 * turn)
	turn_world(rig, RootJoint, Vector3.RIGHT, .04 * strike + .10 * guard - .11 * recoil)
	turn_world(rig, "bip01 spine2", Vector3.UP, turn)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .15 * strike + .10 * guard - .20 * recoil - .10 * lift)
	turn_world(rig, "bip01 head", Vector3.UP, -.38 * turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.11 * strike + .13 * recoil + .10 * guard)
	turn_world(rig, "bip01 ponytail1", Vector3.BACK, .13 * turn - .08 * recoil)
	turn_world(rig, "bip01 ponytail2", Vector3.BACK, .13 * turn + .08 * recoil)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var leading := 1.0 if sign_x == lead else .36
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (.26 * wind + .26 * guard + .35 * hips + .44 * leading * lift))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, leading * (.47 * wind - .95 * strike - .86 * lift) - .49 * guard + .16 * recoil + .28 * hips)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, leading * (.22 * strike - .50 * wind - .52 * lift) - .61 * guard - .46 * hips)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * (.22 * guard + .16 * hips + .23 * leading * strike))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.17 * guard + .10 * sign_x * lead * strike)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .19 * guard + .05 * strike)
	match group:
		4:
			place_hand(rig, "l", Vector3(.17, .24, .39), wind)
			place_hand(rig, "l", Vector3(-.23, -.03, .65), strike)
			place_hand(rig, "r", Vector3(-.12, -.07, .35), .58 * maxf(wind, strike))
		5:
			place_hand(rig, "r", Vector3(-.21, .59, .22), lift)
			place_hand(rig, "r", Vector3(-.31, .17, .61), strike)
			place_hand(rig, "l", Vector3(.11, -.04, .39), .58 * maxf(lift, strike))
		6:
			place_hand(rig, "l", Vector3(.09, -.03, .69), minf(1.0, 1.35 * strike))
			place_hand(rig, "r", Vector3(-.09, -.21, .32), .73 * strike)
		15:
			place_hand(rig, "l", Vector3(-.09, .15, .39), guard)
			place_hand(rig, "r", Vector3(.11, -.18, .41), .76 * guard)
	anchor_hind_paws(rig, feet)


func place_hand(rig: Skeleton3D, side: String, offset: Vector3, strength: float) -> void:
	if strength <= .001:
		return
	var upper := rig.find_bone("bip01 %s upperarm" % side)
	var elbow := rig.find_bone("bip01 %s forearm" % side)
	var hand := rig.find_bone("bip01 %s hand" % side)
	var shoulder := rig.get_bone_global_pose(upper).origin
	var middle := rig.get_bone_global_pose(elbow).origin
	var wrist := rig.get_bone_global_pose(hand).origin
	var goal := wrist.lerp(shoulder + rig.global_basis.inverse() * offset, strength)
	var direction := (goal - shoulder).normalized()
	var first := shoulder.distance_to(middle)
	var second := middle.distance_to(wrist)
	var reach := clampf(shoulder.distance_to(goal), absf(first - second) + .002, first + second - .002)
	var along := (first * first - second * second + reach * reach) / (2.0 * reach)
	var outward := Vector3(.8 if side == "l" else -.8, -.62, -.15)
	var pole := (rig.global_basis.inverse() * outward).slide(direction).normalized()
	var bend := sqrt(maxf(0.0, first * first - along * along))
	Arms.aim(rig, upper, elbow, shoulder + direction * along + pole * bend)
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, elbow, hand, shoulder + direction * reach)
	rig.force_update_all_bone_transforms()
