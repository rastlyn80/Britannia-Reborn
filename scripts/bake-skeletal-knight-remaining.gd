# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-skeletal-knight-enhanced.gd"

const Output := Destination + "remaining-groups/"
const Sweep := "SkeletalKnightOverheadSweep"
const Brace := "SkeletalKnightLowBrace"
const Flinch := "SkeletalKnightShieldFlinch"
const Check := "SkeletalKnightBladeCheck"
const Stagger := "SkeletalKnightWideStagger"
const Durations := {Sweep: .79, Brace: 1.16, Flinch: .49, Check: 1.19, Stagger: .95}


func run() -> void:
	for treatment: String in Profile.registered_assets(Registry.entry(147)):
		var source := Destination + "147-%s.scn" % treatment
		var actor := (load(source) as PackedScene).instantiate()
		root.add_child(actor)
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var body := actor.find_child("Body", true, false) as MeshInstance3D
		var skin := Ground.skin_points(body, rig)
		var clearance := BladeClearance.new(body, rig)
		var lib := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", lib)
		var props: Array[Dictionary] = [
			held_prop(actor, rig, "Scimitar", "r"), held_prop(actor, rig, "WoodenShield", "l"),
		]
		for clip: String in Durations:
			assert(lib.add_animation(clip, fit_pose(player, rig, skin, clip)) == OK)
			fit_clip(player, rig, clip, props, clearance)
		Exact.check_earlier_keys(player, source)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		assert(packed.pack(actor) == OK)
		assert(ResourceSaver.save(packed, Output + "147-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		actor.free()
		print("SKELETAL KNIGHT REMAINING ", treatment, ": earlier keys intact")
	quit()


func held_prop(actor: Node3D, rig: Skeleton3D, name: String, side: String) -> Dictionary:
	var prop := actor.find_child(name, true, false) as MeshInstance3D
	var points := PackedVector3Array()
	for surface in prop.mesh.get_surface_count():
		points.append_array(prop.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	var joint := rig.find_bone(name.to_lower())
	var grip := rig.find_bone("cp_grasp_%shand" % side)
	assert(joint >= 0 and grip >= 0 and rig.get_bone_parent(joint) == grip)
	return {"label": name, "grip": grip, "bone": joint, "points": points}


func fit_pose(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, label: String) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = Durations[label]
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, 0, -1):
			motion.track_remove_key(track, key)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var root_joint := rig.find_bone("__root")
	var placement := channel(motion, NodePath("%s:__root" % path), Animation.TYPE_POSITION_3D)
	var tracks := {}
	for joint: String in BONES + ["bip01 pelvis", "bip01 neck"]:
		var bone := rig.find_bone(joint)
		assert(bone >= 0)
		tracks[bone] = channel(motion, NodePath("%s:%s" % [path, joint]), Animation.TYPE_ROTATION_3D)
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := frame / 80.0
		var time := phase * motion.length
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		choreograph(rig, label, phase)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var base := rig.get_bone_global_pose(root_joint)
		base.origin += rig.global_basis.inverse() * Vector3.UP * (.011 - gap)
		rig.set_bone_global_pose(root_joint, base)
		motion.position_track_insert_key(placement, time, rig.get_bone_pose_position(root_joint))
		for bone: int in tracks:
			motion.rotation_track_insert_key(tracks[bone], time, rig.get_bone_pose_rotation(bone))
	player.stop()
	return motion


func window(phase: float, start: float, peak: float, hold: float, end: float) -> float:
	return smoothstep(start, peak, phase) * (1.0 - smoothstep(hold, end, phase))


func choreograph(rig: Skeleton3D, label: String, phase: float) -> void:
	var dip := 0.0
	var split := 0.0
	var twist := 0.0
	var sword := 0.0
	var shield := 0.0
	var opening := 0.0
	match label:
		Sweep:
			var lift := 1.0 - smoothstep(.26, .49, phase)
			dip = 1.04 * window(phase, .24, .53, .68, 1.0)
			split = .81 * (1.0 - smoothstep(.60, 1.0, phase))
			twist = -.47 * lift + .72 * dip
			sword = 1.84 * lift + .56 * dip
			shield = .67 * lift + .80 * dip
		Brace:
			dip = .20 + .77 * window(phase, .42, .63, .80, 1.0)
			split = .44 * dip
			twist = .37 * dip
			sword = .94 * dip
			shield = .87 * dip
		Flinch:
			var hold := 1.0 - .27 * smoothstep(.25, 1.0, phase)
			dip = .72 * hold
			split = .82 * hold
			twist = -.56 * hold
			sword = .87 * hold
			shield = 1.15 * hold
		Check:
			var inspect := window(phase, .03, .25, .76, .99)
			dip = .12 * inspect
			twist = -.24 * inspect
			sword = .77 * inspect
			shield = .43 * inspect
		Stagger:
			opening = window(phase, .03, .28, .81, 1.0)
			dip = .23 + .52 * opening
			split = .36 + .55 * opening
			twist = -.59 * opening
			sword = .58 + .43 * opening
			shield = .56 - .34 * opening
	turn(rig, "bip01 pelvis", Vector3.RIGHT, .32 * dip)
	turn(rig, "bip01 spine", Vector3.RIGHT, (.79 if label == Brace else .59) * dip)
	turn(rig, "bip01 spine1", Vector3.UP, twist)
	turn(rig, "bip01 neck", Vector3.RIGHT, (-.15 if label == Brace else -.36) * dip)
	turn(rig, "bip01 r upperarm", Vector3.RIGHT, -sword)
	turn(rig, "bip01 r upperarm", Vector3.BACK, -.28 * sword - .62 * opening)
	turn(rig, "bip01 r forearm", Vector3.RIGHT, -.44 * sword)
	turn(rig, "bip01 l upperarm", Vector3.RIGHT, -.84 * shield)
	turn(rig, "bip01 l upperarm", Vector3.BACK, .31 * shield + .73 * opening)
	turn(rig, "bip01 l forearm", Vector3.RIGHT, -.79 * shield)
	if label != Check:
		plant_stance(rig, label, dip, split)


func plant_stance(rig: Skeleton3D, label: String, dip: float, split: float) -> void:
	var left := rig.find_bone("bip01 l foot")
	var right := rig.find_bone("bip01 r foot")
	var feet := [rig.get_bone_global_pose(left), rig.get_bone_global_pose(right)]
	var to_local := rig.global_basis.inverse()
	var root_joint := rig.find_bone("__root")
	var base := rig.get_bone_global_pose(root_joint)
	base.origin += to_local * Vector3(0.0, -.28 * dip - .10 * split, .15 * dip)
	rig.set_bone_global_pose(root_joint, base)
	for i in 2:
		var side := "l" if i == 0 else "r"
		var direction := 1.0 if i == 0 else -1.0
		var target: Transform3D = feet[i]
		var lift := .14 * split if label == Sweep and i == 1 else 0.0
		var width := .38 if label in [Flinch, Stagger] else .20
		var stride := .31 if label in [Sweep, Stagger] else .15
		target.origin += to_local * Vector3(direction * width * split, lift, direction * stride * split)
		plant(rig, rig.find_bone("bip01 %s thigh" % side), rig.find_bone("bip01 %s calf" % side),
			left if i == 0 else right, target, (to_local * Vector3.BACK).normalized())


func orientation(label: String, clip: String, phase: float) -> Basis:
	if label == "WoodenShield":
		var splay := window(phase, .03, .28, .81, 1.0) if clip == Stagger else 0.0
		return Basis(Vector3.UP, -.30 + .85 * splay).rotated(Vector3.RIGHT, -.15 - .19 * splay)
	var low := Vector3(-.38, .25, .88).normalized()
	var blade := low
	match clip:
		Sweep:
			var high := Vector3(-.49, .84, -.32).normalized()
			var outside := Vector3(-.91, .35, .27).normalized()
			var thrust := Vector3(-.34, -.32, .88).normalized()
			blade = high.slerp(outside, smoothstep(.20, .40, phase))
			blade = blade.slerp(thrust, smoothstep(.39, .57, phase))
			blade = blade.slerp(low, smoothstep(.68, 1.0, phase))
		Brace:
			blade = Vector3(-.32, -.42, .85).normalized().slerp(low, smoothstep(.40, .70, phase))
		Flinch:
			blade = Vector3(-.61, .71, -.35).normalized().slerp(low, .36 * phase)
		Check:
			var across := Vector3(.88, .07, .47).normalized()
			blade = low.slerp(across, window(phase, .03, .25, .76, .99))
		Stagger:
			var high := Vector3(-.61, .59, -.50).normalized()
			blade = low.slerp(high, .29 + .71 * window(phase, .03, .27, .81, 1.0))
	return Basis(Quaternion(Vector3.UP, blade))
