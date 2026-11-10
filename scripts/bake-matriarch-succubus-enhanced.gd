# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/matriarch-succubus/"
const Matriarch := {12: "MatriarchSceptreArc", 23: "MatriarchCoiledRise", 26: "MatriarchTailWatch",
	27: "MatriarchRaisedWard", 28: "MatriarchSceptreAlert"}
const Succubus := {23: "SuccubusWingCocoonRise", 26: "SuccubusWingWatch", 27: "SuccubusAsymmetricSpread",
	28: "SuccubusWingThreat"}
const MatriarchLengths := {12: 1.22, 23: 1.18, 26: 1.12, 27: .92, 28: 1.02}
const SuccubusLengths := {23: 1.20, 26: 1.06, 27: 1.04, 28: .93}
const Staff := "matriarch ceremonial staff"
const Upper := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 neck", "bip01 head",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand"]
const Tail := ["bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4"]
const Wing := {"l": ["box01", "box03", "box04"], "r": ["box07", "box05", "box06"]}
const Legs := ["bip01 r thigh", "bip01 r calf", "bip01 r foot", "bip01 l thigh", "bip01 l calf", "bip01 l foot"]
const Clearance := preload("res://Presentation/matriarch-sceptre-clearance.gd")
var sceptre_clearance: RefCounted
var last_axis := Vector3.ZERO


func run() -> void:
	var donor := Registry.entry(85)
	for body: int in [87, 149]:
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
			var body_mesh := model.find_child("Body", true, false) as MeshInstance3D
			var skins: Array[Dictionary] = [Ground.skin_points(body_mesh, rig)]
			if body == 87:
				var prop := attach_staff(model, rig, donor, treatment)
				skins.append(Ground.skin_points(prop, rig))
				sceptre_clearance = Clearance.new(body_mesh, rig)
				var prop_bounds := prop.mesh.get_aabb()
				sceptre_clearance.shaft = Vector2(prop_bounds.position.y, prop_bounds.end.y)
				for group: int in Matriarch:
					var motion := fit_grounded(player, rig, skins, MatriarchLengths[group], "bip01",
						Upper + Tail + [Staff], pose_matriarch.bind(group), .005)
					assert(library.add_animation(Matriarch[group], motion) == OK)
					steer_between_keys(player, rig, Matriarch[group], motion)
			else:
				for group: int in Succubus:
					var motion := fit_grounded(player, rig, skins, SuccubusLengths[group], "bip01",
						Upper + Legs + Wing.l + Wing.r, pose_succubus.bind(group), .006)
					assert(library.add_animation(Succubus[group], motion) == OK)
			verify_base_clips(player, source)
			player.stop()
			rig.reset_bone_poses()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			assert(ResourceSaver.save(scene, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
			model.free()
			print("MATRIARCH AND SUCCUBUS ", body, "/", treatment, ": retained keys plus fitted motions")
	quit()


func attach_staff(model: Node3D, rig: Skeleton3D, donor: Dictionary, treatment: String) -> MeshInstance3D:
	var path := Registry.asset_path(donor, treatment)
	assert(FileAccess.get_sha256(path) == donor.asset_sha256[treatment])
	var donor_model := (load(path) as PackedScene).instantiate()
	var original := donor_model.find_child("OphidianMageStaff", true, false) as MeshInstance3D
	assert(original != null and original.mesh.surface_get_array_len(0) == 186)
	var prop := MeshInstance3D.new()
	prop.name = "MatriarchSceptre"
	var arrays := original.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var scale := Vector3(.87, .72, .87)
	for index in vertices.size():
		# The short ceremonial grip sits near the butt in the Matriarch reference.
		vertices[index] = (vertices[index] + Vector3.UP * .27) * scale
		normals[index] = (normals[index] / scale).normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	prop.mesh = mesh
	prop.material_override = original.material_override
	var socket := rig.find_bone("cp_grasp_rhand")
	assert(socket >= 0)
	var joint := rig.add_bone(Staff)
	rig.set_bone_parent(joint, socket)
	prop.skin = Skin.new()
	prop.skin.add_bind(joint, Transform3D.IDENTITY)
	prop.skeleton = NodePath("..")
	rig.add_child(prop)
	prop.owner = model
	donor_model.free()
	return prop


func pose_matriarch(rig: Skeleton3D, phase: float, group: int) -> void:
	if phase == 0.0:
		last_axis = Vector3.ZERO
	var curl := 0.0
	var lift := 0.0
	var lean := 0.0
	var turn := 0.0
	match group:
		12:
			lift = envelope(phase, .03, .28, .49, .69)
			lean = envelope(phase, .54, .73, .80, 1.0)
			turn = .45 * lift - .58 * lean
		23:
			curl = 1.0 - smoothstep(.11, .73, phase)
			lean = .38 * curl
			turn = -.38 * sin(PI * phase)
		26:
			turn = .40 * sin(TAU * phase) * sin(PI * phase)
			lean = .17 * envelope(phase, .04, .35, .72, 1.0)
		27:
			lift = envelope(phase, .02, .20, .79, 1.0)
			turn = -.22 * lift
		28:
			lift = .77 * smoothstep(.24, .78, phase)
			lean = .25 * envelope(phase, .03, .26, .45, .78)
			turn = .24 * lift
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .52 * curl + .22 * lean)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .68 * curl + .34 * lean - .22 * lift)
	turn_world(rig, "bip01 spine2", Vector3.UP, turn)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.33 * curl)
	turn_world(rig, "bip01 head", Vector3.UP, .40 * turn)
	for index in Tail.size():
		var ripple := sin(TAU * phase - float(index) * .67) * sin(PI * phase)
		turn_world(rig, Tail[index], Vector3.UP, (-.82 + .07 * index) * curl + (.13 + .09 * index) * ripple)
		turn_world(rig, Tail[index], Vector3.RIGHT, -.13 * curl - .27 * lift + .12 * ripple)
	var chest := joint_world(rig, "bip01 spine2")
	var right := joint_world(rig, "bip01 r hand").lerp(chest + Vector3(-.36, -.19, .46), curl)
	right = right.lerp(chest + Vector3(-.55, 1.0, .21), lift)
	right = right.lerp(chest + Vector3(-.38, -.17, 1.08), lean)
	# Open the elbow as the sceptre passes the shoulder on the upswing and release.
	if group == 27:
		right += Vector3(-.20, -.02, .11) * envelope(phase, .01, .10, .21, .37)
	elif group == 12:
		right += Vector3(-.18, -.03, .10) * envelope(phase, .46, .55, .67, .81)
	fit_arm(rig, "r", right)
	var left := joint_world(rig, "bip01 l hand").lerp(chest + Vector3(.35, -.24, .55), curl)
	left = left.lerp(chest + Vector3(.71, .29, .26), .68 * lift + .27 * lean)
	fit_arm(rig, "l", left)
	aim_sceptre(rig, Vector3(-.83, .18, .53).normalized().slerp(Vector3(-.20, .97, .14).normalized(), lift)
		.slerp(Vector3(-.17, .14, .97).normalized(), lean))


func aim_sceptre(rig: Skeleton3D, direction: Vector3) -> void:
	var grip := rig.find_bone("cp_grasp_rhand")
	var frame := rig.global_transform * rig.get_bone_global_pose(grip)
	var upper := clampf((frame.origin.y - .065) / (.19 * frame.basis.get_scale().y), 0.0, 1.0)
	var y := minf(direction.y, upper)
	var horizontal := Vector3(direction.x, 0.0, direction.z).normalized()
	var wanted := horizontal * sqrt(maxf(0.0, 1.0 - y * y)) + Vector3.UP * y
	sceptre_clearance.update_pose()
	var axis := steer_sceptre(frame, wanted)
	last_axis = axis
	rig.set_bone_pose_rotation(rig.find_bone(Staff), staff_rotation(frame, axis))
	rig.force_update_all_bone_transforms()


func steer_sceptre(frame: Transform3D, wanted: Vector3) -> Vector3:
	var candidate := wanted if last_axis.is_zero_approx() else last_axis.slerp(wanted, .47)
	var prior_clear := not last_axis.is_zero_approx() and clear_sceptre(frame, last_axis)
	if clear_arc(frame, candidate, prior_clear):
		return candidate
	for degrees: float in [7.0, 14.0, 23.0, 35.0, 52.0, 76.0, 105.0]:
		var best := Vector3.ZERO
		var cost := INF
		for rotation_axis: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var direction := candidate.rotated(rotation_axis, deg_to_rad(degrees))
			if not clear_arc(frame, direction, prior_clear):
				continue
			var score := direction.angle_to(wanted) + .43 * direction.angle_to(candidate)
			if score < cost:
				best = direction
				cost = score
		if not best.is_zero_approx():
			return best
	return last_axis if prior_clear else wanted


func clear_arc(frame: Transform3D, direction: Vector3, prior_clear: bool) -> bool:
	return clear_sceptre(frame, direction) and (not prior_clear or clear_sceptre(frame, last_axis.slerp(direction, .5)))


func clear_sceptre(frame: Transform3D, direction: Vector3) -> bool:
	var pose := Transform3D(frame.basis * Basis(staff_rotation(frame, direction)), frame.origin)
	return not sceptre_clearance.crosses_sceptre(pose, .008) and not sceptre_clearance.crosses_sceptre(pose, .017)


func staff_rotation(frame: Transform3D, direction: Vector3) -> Quaternion:
	return Quaternion(Vector3.UP, (frame.basis.inverse() * direction).normalized())


func steer_between_keys(player: AnimationPlayer, rig: Skeleton3D, clip: String, motion: Animation) -> void:
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var track := motion.find_track(NodePath("%s:%s" % [rig_path, Staff]), Animation.TYPE_ROTATION_3D)
	assert(track >= 0)
	var joint := rig.find_bone(Staff)
	var grip := rig.get_bone_parent(joint)
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	last_axis = Vector3.ZERO
	var intervals := ceili(motion.length * 360.0)
	var keys: Array[Quaternion] = []
	for step in intervals + 1:
		player.seek(motion.length * step / intervals, true)
		rig.force_update_all_bone_transforms()
		var frame := rig.global_transform * rig.get_bone_global_pose(grip)
		var current := (rig.global_basis * rig.get_bone_global_pose(joint).basis).y.normalized()
		sceptre_clearance.update_pose()
		last_axis = steer_sceptre(frame, current)
		keys.append(staff_rotation(frame, last_axis))
	for index in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, index)
	for step in keys.size():
		motion.rotation_track_insert_key(track, motion.length * step / intervals, keys[step])


func pose_succubus(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var open := 0.0
	var bank := 0.0
	var crouch := 0.0
	match group:
		23:
			fold = 1.0 - smoothstep(.14, .53, phase)
			open = envelope(phase, .20, .47, .68, 1.0)
			crouch = .83 * fold
			bank = .16 * open
		26:
			open = .19 * sin(PI * phase)
			bank = .22 * sin(TAU * phase)
		27:
			open = .92 * envelope(phase, .06, .35, .78, 1.0)
			bank = .57 * open
			crouch = .40 * open
		28:
			open = .91 * smoothstep(.04, .59, phase)
			bank = -.24 * open
			crouch = .49 * open
	var ankles: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		if side == "r":
			foot.origin += rig.global_basis.inverse() * Vector3(-.03, .31, -.13) * (open + .38 * fold)
		ankles.append(foot)
	var hips := rig.find_bone("bip01")
	var pose := rig.get_bone_global_pose(hips)
	pose.origin += rig.global_basis.inverse() * Vector3(.13 * bank, -.56 * crouch, -.15 * crouch)
	rig.set_bone_global_pose(hips, pose)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .41 * fold + .26 * open)
	turn_world(rig, "bip01 spine2", Vector3.BACK, .33 * bank)
	turn_world(rig, "bip01 head", Vector3.UP, -.51 * bank)
	var chest := joint_world(rig, "bip01 spine2")
	for index in 2:
		var side := "l" if index == 0 else "r"
		var sign_x := 1.0 if index == 0 else -1.0
		var chain: Array = Wing[side]
		fit_foot(rig, side, ankles[index])
		var hand := joint_world(rig, "bip01 %s hand" % side).lerp(chest + Vector3(sign_x * .17, -.23, .32), fold)
		hand = hand.lerp(chest + Vector3(sign_x * .64, -.12 + .17 * sign_x * bank, .21), open)
		fit_arm(rig, side, hand)
		turn_world(rig, chain[0], Vector3.UP, -sign_x * (.66 * fold + 1.14 * open))
		turn_world(rig, chain[0], Vector3.BACK, sign_x * .26 * open + .76 * bank)
		turn_world(rig, chain[1], Vector3.UP, -sign_x * (1.05 * fold + .22 * open))
		turn_world(rig, chain[1], Vector3.RIGHT, -.36 * fold + .20 * open)
		turn_world(rig, chain[2], Vector3.UP, -sign_x * (.47 * fold - .14 * open))
		turn_world(rig, chain[2], Vector3.RIGHT, .39 * fold - .19 * open)
