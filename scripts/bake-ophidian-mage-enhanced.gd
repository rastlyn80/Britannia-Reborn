# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-ophidian-mage-distinct-actions.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/orc-shaman-ophidian-mage/"
const EnhancedClips := {23: "OphidianMageCoilUnwind", 26: "OphidianMageStaffWatch",
	27: "OphidianMageHighWard", 28: "OphidianMageTailSignal"}
const TimingSlots := {23: 3, 26: 5, 27: 6, 28: 18}


func run() -> void:
	var row := Registry.entry(85)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var seed := Stage + "85-seed-%s.scn" % treatment
		var repaired := Stage + "85-repaired-%s.scn" % treatment
		var target := Stage + "85-%s.scn" % treatment
		build_stage(source, seed, treatment, "body")
		build_stage(seed, repaired, treatment, "staff")
		build_stage(repaired, target, treatment, "smooth")
	quit()


func build_stage(source: String, target: String, treatment: String, stage: String) -> void:
	var scene := ResourceLoader.load(source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var model := scene.instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var body := model.find_child("Body", true, false) as MeshInstance3D
	var staff := model.find_child("OphidianMageStaff", true, false) as MeshInstance3D
	assert(body != null and staff != null)
	var grip := rig.find_bone("cp_grasp_rhand")
	var staff_bone := rig.find_bone(STAFF_BONE)
	assert(grip >= 0 and rig.get_bone_parent(staff_bone) == grip)
	var points := PackedVector3Array()
	for surface in staff.mesh.get_surface_count():
		points.append_array(staff.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	var skin := Ground.skin_points(body, rig)
	var clearance := StaffClearance.new(body, rig)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for group: int in EnhancedClips:
		var clip: String = EnhancedClips[group]
		match stage:
			"body":
				assert(library.add_animation(clip, fit_motion(player, rig, skin, TimingSlots[group])) == OK)
				bake_staff(player, rig, grip, staff_bone, points, clearance, clip)
				player.stop()
				player.clear_caches()
			"staff":
				repair(player, rig, grip, staff_bone, points, clearance, clip, treatment)
			"smooth":
				smooth(player, rig, grip, points, clearance, clip)
	if stage == "body":
		Earlier.check_earlier_keys(player, source)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()


func choreograph(rig: Skeleton3D, slot: int, phase: float) -> void:
	var uncoil := slot == 3
	var coil := 1.0 - smoothstep(.12, .70, phase) if uncoil else 0.0
	var pulse := smoothstep(.08, .43, phase) * (1.0 - smoothstep(.69, .98, phase))
	var gesture := smoothstep(.13, .63, phase) if slot == 18 else pulse
	var lift := .70 * pulse if slot == 6 else .52 * pulse if slot == 18 else .21 * pulse
	var watch := -.39 * (1.0 - smoothstep(.72, 1.0, phase)) if slot == 5 else .18 * pulse
	var ripple := sin(TAU * (phase - .13)) * sin(PI * phase) if uncoil else .48 * sin(TAU * phase) * gesture
	turn(rig, "bip01 spine", Vector3.RIGHT, .43 * coil - .19 * lift)
	turn(rig, "bip01 spine1", Vector3.RIGHT, .68 * coil + .17 * gesture)
	turn(rig, "bip01 spine2", Vector3.UP, watch)
	turn(rig, "bip01 neck", Vector3.RIGHT, -.36 * coil - .25 * lift)
	turn(rig, "bip01 head", Vector3.UP, -.42 * watch)
	turn(rig, "bip01 r upperarm", Vector3.RIGHT, -.95 * lift - .35 * coil)
	turn(rig, "bip01 r upperarm", Vector3.BACK, -.58 * lift - .52 * coil - .28 * absf(watch))
	turn(rig, "bip01 r forearm", Vector3.RIGHT, -.62 * lift - .13 * coil)
	turn(rig, "bip01 r hand", Vector3.UP, .27 * watch)
	turn(rig, "bip01 l upperarm", Vector3.BACK, .62 * lift - .17 * coil)
	turn(rig, "bip01 l forearm", Vector3.RIGHT, -.46 * lift - .68 * coil)
	for i in 4:
		var tail := "bip01 tail%d" % (i + 1)
		var offset := float(i) / 3.0
		turn(rig, tail, Vector3.UP, (.88 - .12 * offset) * coil + (.24 + .19 * offset) * ripple)
		turn(rig, tail, Vector3.RIGHT, (-.31 + .14 * offset) * coil + (.28 + .34 * offset) * gesture)


func staff_direction(_rig: Skeleton3D, socket: Transform3D, label: String, phase: float) -> Vector3:
	var upright := Vector3(-.24, 1.0, .36).normalized()
	var side := Vector3(-.79, .26, .53).normalized()
	var pulse := smoothstep(.12, .43, phase) * (1.0 - smoothstep(.66, .99, phase))
	var aim := upright
	match label:
		"OphidianMageCoilUnwind":
			aim = side.slerp(upright, smoothstep(.10, .67, phase))
		"OphidianMageStaffWatch":
			aim = side.slerp(upright, smoothstep(.73, 1.0, phase))
		"OphidianMageHighWard":
			aim = upright.slerp(Vector3(-.20, .98, .08).normalized(), pulse)
		"OphidianMageTailSignal":
			aim = side.slerp(upright, smoothstep(.13, .67, phase))
	var scale := socket.basis.get_scale()
	var radius := .074 * scale.length() / sqrt(3.0)
	var high := clampf((socket.origin.y - radius - .014) / (.5021 * scale.y), 0.0, 1.0)
	var low := -clampf((socket.origin.y - radius - .014) / (.723 * scale.y), 0.0, 1.0)
	var height := clampf(aim.y, low, high)
	var horizontal := Vector3(aim.x, 0.0, aim.z).normalized()
	return horizontal * sqrt(maxf(0.0, 1.0 - height * height)) + Vector3.UP * height


func turn(rig: Skeleton3D, label: String, axis: Vector3, amount: float) -> void:
	var joint := rig.find_bone(label)
	assert(joint >= 0)
	var parent := rig.get_bone_parent(joint)
	var local_axis := (rig.global_basis.inverse() * axis).normalized()
	if parent >= 0:
		local_axis = rig.get_bone_global_pose(parent).basis.orthonormalized().inverse() * local_axis
	var rotation := Quaternion(local_axis.normalized(), amount) * rig.get_bone_pose_rotation(joint)
	rig.set_bone_pose_rotation(joint, rotation.normalized())
	rig.force_update_all_bone_transforms()

