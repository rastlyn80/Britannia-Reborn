# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/ratman-mage-lava-serpent/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const StaffBone := "ratman mage crook"
const StaffPathRate := 24.0
const StaffMaximumTurnRate := 11.0
const ShaftScale := Vector3(.82, .68, .82)
const GripOrigin := Vector3(0, -.14, 0)
const Sections := [
	[Vector3(0, -.99, 0), Vector3(0, -.32, 0)],
	[Vector3(0, .04, 0), Vector3(0, .59, 0)],
	[Vector3(0, .59, 0), Vector3(0, .70, -.13)],
	[Vector3(0, .70, -.13), Vector3(0, .55, -.16)],
]
const Clips := {11: "RatmanMageLowClawBrace", 12: "RatmanMageCrookCast", 15: "RatmanMageGuardRecoil",
	23: "RatmanMageHoodedRise", 26: "RatmanMageCrookWatch", 27: "RatmanMageCrookSweep", 28: "RatmanMageHighAlert"}
const Durations := {11: .91, 12: 1.09, 15: .68, 23: .94, 26: 1.01, 27: .72, 28: .80}
const MageJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4", "jaw_lower"]


class CrookClearance extends "res://../scripts/ophidian-bardiche-clearance.gd":
	func hits(pose: Transform3D, sections: Array, margin: float) -> bool:
		var offsets := [Vector3.ZERO, Vector3.RIGHT * margin, Vector3.LEFT * margin, Vector3.FORWARD * margin, Vector3.BACK * margin]
		for section: Array in sections:
			var a: Vector3 = pose * section[0]
			var b: Vector3 = pose * section[1]
			var region := AABB(a, Vector3.ZERO).expand(b).grow(.0001 + margin * 1.7)
			for triangle in bounds.size():
				if not region.intersects(bounds[triangle]):
					continue
				var first := triangle * 3
				for offset: Vector3 in offsets:
					var shift := pose.basis * offset
					if Geometry3D.segment_intersects_triangle(a + shift, b + shift, deformed[indices[first]],
							deformed[indices[first + 1]], deformed[indices[first + 2]]) != null:
						return true
		return false


func run() -> void:
	var row := Registry.entry(143)
	var mesh := make_crook()
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for treatment: String in Profile.registered_assets(row):
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var skins: Array[Dictionary] = [Ground.skin_points(body, rig)]
		var grip := rig.find_bone("cp_grasp_rhand")
		var staff := attach_crook(model, rig, grip, mesh)
		var fit := CrookClearance.new(body, rig)
		var lib := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", lib)
		for group: int in Clips:
			var name: String = Clips[group]
			var clip := fit_grounded(player, rig, skins, Durations[group], "bip01", MageJoints, pose_mage.bind(group), .007)
			assert(lib.add_animation(name, clip) == OK)
			if not fit_staff(player, rig, name, group, grip, staff, fit, points):
				model.free()
				quit(1)
				return
		verify_base_clips(player, source)
		# The added channel only moves the new prop. Classic Death still uses its
		# original skeleton and sword tracks and never displays the crook.
		if not fit_staff(player, rig, "Death", -1, grip, staff, fit, points):
			model.free()
			quit(1)
			return
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "143-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("RATMAN MAGE ENHANCED ", treatment, ": retained keys and seven fitted motions")
	quit()


func make_crook() -> ArrayMesh:
	var folder := Destination + "staff-reference/"
	var corners: Array = JSON.parse_string(FileAccess.get_file_as_string(folder + "crook.json"))
	assert(corners.size() == 92 * 3)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(folder + "weapons_512.png"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = .12
	material.roughness = .85
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for v: Array in corners:
		surface.set_normal((Vector3(v[3], v[4], v[5]) / ShaftScale).normalized())
		surface.set_uv(Vector2(v[6], v[7]))
		surface.set_bones(PackedInt32Array([0, 0, 0, 0]))
		surface.set_weights(PackedFloat32Array([1, 0, 0, 0]))
		surface.add_vertex((Vector3(v[0], v[1], v[2]) - GripOrigin) * ShaftScale)
	return surface.commit()


func attach_crook(model: Node3D, rig: Skeleton3D, grip: int, mesh: ArrayMesh) -> int:
	assert(grip >= 0)
	var joint := rig.add_bone(StaffBone)
	rig.set_bone_parent(joint, grip)
	var prop := MeshInstance3D.new()
	prop.name = "RatmanCrook"
	prop.mesh = mesh
	prop.skin = Skin.new()
	prop.skin.add_bind(joint, Transform3D.IDENTITY)
	prop.skeleton = NodePath("..")
	prop.hide()
	rig.add_child(prop)
	prop.owner = model
	return joint


func pulse(phase: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, phase) * (1.0 - smoothstep(c, d, phase))


func pose_mage(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var raise := 0.0
	var reach := 0.0
	var twist := 0.0
	match group:
		11:
			dip = .86 * pulse(phase, .22, .58, .70, 1.0)
			reach = .80 * dip
		12:
			raise = pulse(phase, .07, .49, .57, .80)
			reach = pulse(phase, .47, .76, .86, 1.0)
			twist = .22 * (raise - reach)
		15:
			dip = .24 * pulse(phase, .02, .19, .37, .95)
			twist = -.54 * pulse(phase, .01, .21, .55, 1.0)
			raise = .30 * pulse(phase, .05, .32, .53, 1.0)
		23:
			dip = .65 * (1.0 - smoothstep(.02, .59, phase))
			raise = .20 * pulse(phase, .22, .55, .71, .98)
		26:
			dip = .37 * pulse(phase, .06, .31, .71, .99)
			twist = .16 * sin(TAU * phase) * sin(PI * phase)
		27:
			raise = .66 * pulse(phase, .06, .56, .77, .99)
			reach = .80 * pulse(phase, .04, .29, .65, 1.0)
			twist = .45 * reach
		28:
			raise = .57 * smoothstep(.13, .71, phase)
			reach = .35 * smoothstep(.06, .53, phase)
			twist = -.31 * raise
	var hips := rig.find_bone("bip01")
	var frame := rig.get_bone_global_pose(hips)
	var feet := [rig.get_bone_global_pose(rig.find_bone("bip01 l foot")), rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))]
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	frame.origin += rig.global_basis.inverse() * Vector3(-.06 * twist, -.26 * dip, .22 * reach)
	rig.set_bone_global_pose(hips, frame)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .43 * dip - .19 * raise)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .48 * dip)
	turn_world(rig, "bip01 spine2", Vector3.UP, twist)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.20 * dip)
	turn_world(rig, "bip01 head", Vector3.UP, .24 * twist)
	turn_world(rig, "jaw_lower", Vector3.RIGHT, .18 * reach - .12 * raise)
	var chest := joint_world(rig, "bip01 spine2")
	right = right.lerp(chest + Vector3(-.54, -.36, .26), dip)
	right = right.lerp(chest + Vector3(-.55, .26, .51), reach)
	if group == 11:
		right = right.lerp(chest + Vector3(-.40, -.18, .12), dip)
	right = right.lerp(chest + Vector3(-.48, .51, .14), raise)
	left = left.lerp(chest + Vector3(.34, -.40, .61), dip)
	left = left.lerp(chest + Vector3(.53, -.16, .43), reach)
	fit_arm(rig, "r", right + Vector3.LEFT * .115)
	fit_arm(rig, "l", left)
	fit_foot(rig, "l", feet[0])
	fit_foot(rig, "r", feet[1])
	for index in range(1, 5):
		turn_world(rig, "bip01 tail%d" % index, Vector3.UP, .16 * twist - .11 * sin(TAU * phase - .42 * index))


func fit_staff(player: AnimationPlayer, rig: Skeleton3D, clip: String, group: int, grip: int, staff: int,
		clearance: CrookClearance, points: PackedVector3Array) -> bool:
	var motion := player.get_animation(clip)
	var intervals := ceili(motion.length * StaffPathRate)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var channel := motion.add_track(Animation.TYPE_ROTATION_3D)
	motion.track_set_path(channel, NodePath("%s:%s" % [rig_path, rig.get_bone_name(staff)]))
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var parts := crook_sections()
	var frames: Array[Array] = []
	var fixed := staff_orientation_bank()
	for frame in intervals + 1:
		var phase := float(frame) / intervals
		player.seek(phase * motion.length, true)
		rig.force_update_all_bone_transforms()
		clearance.update_pose()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var goal := desired_staff(group, phase)
		var candidates := staff_candidates(socket, goal, fixed, points, clearance, parts)
		if candidates.is_empty():
			push_error("Ratman Mage %s has no safe crook heading at phase %.4f" % [clip, phase])
			return false
		frames.append(candidates)
	var rejected := {}
	var checked := {}
	var turn_limit := StaffMaximumTurnRate * motion.length / intervals
	for attempt in 80:
		var path := continuous_staff_path(frames, turn_limit, rejected)
		if path.is_empty():
			break
		var new_rejections := check_staff_edges(player, rig, motion.length, grip, clearance, points, parts,
			frames, path, rejected, checked)
		if new_rejections > 0:
			continue
		player.stop()
		for frame in path.size():
			motion.rotation_track_insert_key(channel, motion.length * frame / intervals, frames[frame][path[frame]].local)
		print("RATMAN MAGE ", clip, ": ", path.size(), " connected crook headings, ", rejected.size(), " unsafe edges rejected")
		return true
	push_error("Ratman Mage %s has no continuous safe crook path (%d edges rejected)" % [clip, rejected.size()])
	return false


func staff_orientation_bank() -> Array[Basis]:
	var bank: Array[Basis] = []
	for pitch: float in [-65.0, -43.0, -21.0, 0.0, 21.0, 43.0, 65.0, 86.0]:
		for azimuth in range(0, 360, 24):
			var direction := Vector3(0.0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))).rotated(Vector3.UP, deg_to_rad(azimuth))
			bank.append(staff_heading(direction))
	return bank


func staff_heading(direction: Vector3) -> Basis:
	return Basis(Quaternion(Vector3.UP, direction.normalized())) * Basis(Vector3.UP, .5)


func staff_candidates(socket: Transform3D, goal: Basis, fixed: Array[Basis], points: PackedVector3Array,
		clearance: CrookClearance, parts: Array) -> Array:
	var headings: Array[Basis] = [goal]
	for degrees: float in [9.0, -9.0, 18.0, -18.0, 30.0, -30.0]:
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			headings.append(Basis(axis, deg_to_rad(degrees)) * goal)
	headings.append_array(fixed)
	var inverse := socket.basis.orthonormalized().inverse()
	var target := goal.get_rotation_quaternion()
	var choices: Array = []
	for heading: Basis in headings:
		var world := heading.get_rotation_quaternion()
		var local := (inverse * heading).get_rotation_quaternion()
		var pose := Transform3D(socket.basis * Basis(local), socket.origin)
		if staff_clears(pose, points, clearance, parts, .018):
			choices.append({"world": world, "local": local, "error": world.angle_to(target)})
	return choices


func continuous_staff_path(frames: Array[Array], turn_limit: float, rejected: Dictionary) -> PackedInt32Array:
	var cost := PackedFloat64Array()
	var links: Array[PackedInt32Array] = []
	for frame in frames.size():
		var next_cost := PackedFloat64Array()
		next_cost.resize(frames[frame].size())
		next_cost.fill(INF)
		var from := PackedInt32Array()
		from.resize(next_cost.size())
		from.fill(-1)
		for right in frames[frame].size():
			var candidate: Dictionary = frames[frame][right]
			var fit_cost: float = candidate.error * candidate.error
			if frame == 0:
				next_cost[right] = fit_cost
				continue
			for left in cost.size():
				if is_inf(cost[left]) or rejected.has(Vector3i(frame, left, right)):
					continue
				var turn: float = candidate.world.angle_to(frames[frame - 1][left].world)
				var total := cost[left] + fit_cost + 55.0 * turn * turn
				if turn <= turn_limit and total < next_cost[right]:
					next_cost[right] = total
					from[right] = left
		links.append(from)
		cost = next_cost
		if next_cost.count(INF) == next_cost.size():
			print("Crook heading search closed at phase ", float(frame) / (frames.size() - 1))
			return PackedInt32Array()
	var index := -1
	var best := INF
	for candidate in cost.size():
		if cost[candidate] < best:
			index = candidate
			best = cost[candidate]
	if index < 0:
		return PackedInt32Array()
	var path := PackedInt32Array()
	path.resize(frames.size())
	for frame in range(path.size() - 1, -1, -1):
		path[frame] = index
		index = links[frame][index]
	return path


func check_staff_edges(player: AnimationPlayer, rig: Skeleton3D, duration: float, grip: int, clearance: CrookClearance,
		points: PackedVector3Array, parts: Array, frames: Array[Array], path: PackedInt32Array, rejected: Dictionary,
		checked: Dictionary) -> int:
	var new_rejections := 0
	var intervals := path.size() - 1
	for frame in range(1, path.size()):
		var edge := Vector3i(frame, path[frame - 1], path[frame])
		if checked.has(edge):
			continue
		checked[edge] = true
		var first: Quaternion = frames[frame - 1][path[frame - 1]].local
		var last: Quaternion = frames[frame][path[frame]].local
		for step in range(1, 20):
			var weight := step / 20.0
			player.seek(duration * (frame - 1 + weight) / intervals, true)
			rig.force_update_all_bone_transforms()
			clearance.update_pose()
			var socket := rig.global_transform * rig.get_bone_global_pose(grip)
			var pose := Transform3D(socket.basis * Basis(first.slerp(last, weight)), socket.origin)
			if not staff_clears(pose, points, clearance, parts, .010):
				rejected[edge] = true
				new_rejections += 1
				break
	return new_rejections


func desired_staff(group: int, phase: float) -> Basis:
	var forward := Vector3(-.52, .28, .80).normalized()
	var up := Vector3(-.34, .91, .26).normalized()
	var high := Vector3(-.77, .45, -.46).normalized()
	var reach := Vector3(-.25, -.11, .96).normalized()
	var direction := forward
	match group:
		11:
			var guard := Vector3(-.24, -.25, .94).normalized()
			direction = forward.slerp(guard, .80 + .20 * pulse(phase, .20, .59, .72, 1.0))
		12:
			direction = forward.slerp(high, pulse(phase, .07, .46, .59, .79)).slerp(reach, pulse(phase, .58, .75, .86, 1.0))
		15:
			direction = forward.slerp(up, .71 * pulse(phase, .05, .27, .55, 1.0))
		23:
			direction = reach.slerp(up, .56 * pulse(phase, .05, .53, .72, .99))
		26:
			direction = forward.slerp(reach, .62 * pulse(phase, .05, .32, .73, .98))
		27:
			direction = forward.slerp(high, .69 * pulse(phase, .09, .54, .75, .99))
		28:
			direction = forward.slerp(up, .86 * smoothstep(.12, .78, phase))
		-1:
			direction = forward.slerp(Vector3(-.88, .02, .47).normalized(), smoothstep(.06, .72, phase))
	return staff_heading(direction)


static func crook_sections() -> Array:
	var parts := Sections.duplicate(true)
	for section: Array in parts:
		for i in 2:
			section[i] = (section[i] - GripOrigin) * ShaftScale
	return parts


func staff_clears(pose: Transform3D, points: PackedVector3Array, clearance: CrookClearance, parts: Array, margin: float) -> bool:
	for point: Vector3 in points:
		if (pose * point).y < .014:
			return false
	return not clearance.hits(pose, parts, margin)
