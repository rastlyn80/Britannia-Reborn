extends "res://../scripts/bake-skeleton-axe-trial.gd"

const PRIVATE := "res://../work/creatures/mul-motion-review/ophidian-staff/"
const ART_DIR := "res://local-art/creatures/"
const STAFF_BONE := "ophidian mage staff"
const OPHIDIANS := {85: "ophidians_ophidian_mage", 87: "ophidians_ophidian_queen"}
const BODY_MOTIONS := ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", "Death"]
const STAFF_MOTIONS := ["StaffDip", "StaffCast", "Cast2"]
const StaffClearance := preload("res://../scripts/ophidian-staff-clearance.gd")
const TILT_AXES := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK,
	Vector3.UP, Vector3.DOWN, Vector3(1, 0, 1), Vector3(-1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, -1)]
const BODY_JOINTS := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 head",
	"bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4"]
const ARM_JOINTS := ["bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand"]

func run() -> void:
	var points := PackedVector3Array()
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(PRIVATE + "atlas.png"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.12
	material.roughness = 0.82
	var data: Array = JSON.parse_string(FileAccess.get_file_as_string(PRIVATE + "corners.json"))
	assert(data.size() == 186)
	for row: Array in data:
		var point := Vector3(row[0], row[1], row[2])
		points.append(point)
		vertex(builder, point, Vector3(row[3], row[4], row[5]), Vector2(row[6], row[7]))
	var mesh := builder.commit()
	var outputs := {}
	for body: int in OPHIDIANS:
		var forms := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := ART_DIR + str(OPHIDIANS[body]) + "-" + treatment + ".gltf"
			var model := (load(source) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			if body == 85:
				var grip := rig.find_bone("cp_grasp_rhand")
				var staff := attach_staff(model, rig, grip, mesh, material)
				for label: String in STAFF_MOTIONS:
					add_gesture(player, rig, label)
				var skin := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
				var clearance := StaffClearance.new(skin, rig)
				for label: String in BODY_MOTIONS + STAFF_MOTIONS:
					bake_staff(player, rig, grip, staff, points, clearance, label)
			else:
				add_gesture(player, rig, "OphidianQueenDip")
			player.stop()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			var output := ART_DIR + "ophidian-%d-staff-classic-%s.scn" % [body, treatment]
			assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
			forms[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
			model.free()
		outputs[str(body)] = forms
	var receipt := FileAccess.open(PRIVATE + "bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({
		"recipe": FileAccess.get_sha256(get_script().resource_path),
		"arm": FileAccess.get_sha256("res://../scripts/bake-skeleton-axe-trial.gd"),
		"weapon": FileAccess.get_sha256("res://../scripts/bake-troll-weapons-trial.gd"),
		"clearance": FileAccess.get_sha256("res://../scripts/ophidian-staff-clearance.gd"),
		"skin_solver": FileAccess.get_sha256("res://../scripts/ophidian-bardiche-clearance.gd"),
		"corners": FileAccess.get_sha256(PRIVATE + "corners.json"),
		"atlas": FileAccess.get_sha256(PRIVATE + "atlas.png"),
		"forms": outputs,
	}))
	receipt.close()
	quit()

func attach_staff(model: Node3D, rig: Skeleton3D, grip: int, mesh: ArrayMesh, material: Material) -> int:
	assert(grip >= 0)
	var joint := rig.add_bone(STAFF_BONE)
	rig.set_bone_parent(joint, grip)
	var prop := MeshInstance3D.new()
	prop.name = "OphidianMageStaff"
	prop.mesh = mesh
	prop.material_override = material
	prop.skin = Skin.new()
	prop.skin.add_bind(joint, Transform3D.IDENTITY)
	prop.skeleton = NodePath("..")
	rig.add_child(prop)
	prop.owner = model
	return joint

func add_gesture(player: AnimationPlayer, rig: Skeleton3D, label: String) -> void:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = 0.88
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var basis := rig.global_basis.inverse()
	var joints: Array[int] = []
	var tracks: Array[int] = []
	var starting: Array[Quaternion] = []
	for name: String in BODY_JOINTS + ARM_JOINTS:
		var joint := rig.find_bone(name)
		assert(joint >= 0)
		var path := NodePath("%s:%s" % [rig_path, name])
		var track := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, path)
		joints.append(joint)
		tracks.append(track)
		starting.append(rig.get_bone_pose_rotation(joint))
	var right: Array[int] = [joints[8], joints[9], joints[10]]
	var left: Array[int] = [joints[11], joints[12], joints[13]]
	var right_origin := rig.get_bone_global_pose(right[2]).origin
	var left_origin := rig.get_bone_global_pose(left[2]).origin
	for sample in 121:
		var phase := float(sample) / 120.0
		var amount := gesture_strength(phase)
		var dip := label in ["StaffDip", "OphidianQueenDip"]
		for i in joints.size():
			rig.set_bone_pose_rotation(joints[i], starting[i])
		var torso := [0.15, 0.17, 0.12, -0.10] if dip else [0.05, 0.06, 0.04, -0.10]
		if label == "OphidianQueenDip":
			torso = [0.30, 0.29, 0.22, -0.16]
		for i in 4:
			var bend: float = torso[i]
			rotate_joint(rig, joints[i], Quaternion((basis * Vector3.RIGHT).normalized(), bend * amount))
		for i in range(4, 8):
			var sway := 0.18 * sin(phase * PI + float(i - 4) * 0.65) * amount
			rotate_joint(rig, joints[i], Quaternion((basis * Vector3.UP).normalized(), sway))
		if amount > 0.0:
			var right_offset := Vector3(-0.10, 0.68, 0.17)
			var left_offset := Vector3(-0.16, -0.13, 0.22)
			if label == "StaffCast":
				right_offset = Vector3(-0.06, 0.62, 0.64)
				left_offset = Vector3(-0.60, -0.03, 0.58)
			elif label == "Cast2":
				right_offset = Vector3(-0.22, 0.44, 0.86)
				left_offset = Vector3(-0.24, 0.04, 0.26)
			elif label == "OphidianQueenDip":
				right_offset = Vector3(0.02, 0.40, 0.50)
				left_offset = Vector3(-0.04, 0.33, 0.41)
			aim_arm(rig, right, right_origin + basis * right_offset * amount)
			aim_arm(rig, left, left_origin + basis * left_offset * amount)
		for i in joints.size():
			motion.rotation_track_insert_key(tracks[i], phase * motion.length, rig.get_bone_pose_rotation(joints[i]))
	assert(player.get_animation_library("").add_animation(label, motion) == OK)

func aim_arm(rig: Skeleton3D, arm: Array[int], target: Vector3) -> void:
	var shoulder := rig.get_bone_global_pose(arm[0]).origin
	var elbow := rig.get_bone_global_pose(arm[1]).origin
	var hand := rig.get_bone_global_pose(arm[2])
	var upper := shoulder.distance_to(elbow)
	var lower := elbow.distance_to(hand.origin)
	var direction := (target - shoulder).normalized()
	var reach := clampf(shoulder.distance_to(target), absf(upper - lower) + 0.0001, upper + lower - 0.0001)
	var along := (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
	var bend := elbow - shoulder - direction * direction.dot(elbow - shoulder)
	var flex := sqrt(maxf(0.0, upper * upper - along * along))
	aim_joint(rig, arm[0], arm[1], shoulder + direction * along + bend.normalized() * flex)
	aim_joint(rig, arm[1], arm[2], target)
	var pose := rig.get_bone_global_pose(arm[2])
	pose.basis = hand.basis
	rig.set_bone_global_pose(arm[2], pose)
	rig.force_update_all_bone_transforms()

func bake_staff(player: AnimationPlayer, rig: Skeleton3D, grip: int, staff: int, points: PackedVector3Array,
		clearance: RefCounted, label: String) -> void:
	var motion := player.get_animation(label)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var track := motion.add_track(Animation.TYPE_ROTATION_3D)
	motion.track_set_path(track, NodePath("%s:%s" % [rig_path, STAFF_BONE]))
	player.stop()
	player.play(label, 0.0)
	player.advance(0.0)
	var sample_rate := 240.0 if label in ["StaffCast", "Death"] else 120.0
	var intervals := ceili(motion.length * sample_rate)
	var floor := INF
	var crossings := 0
	var previous := Basis.IDENTITY
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		var time := phase * motion.length
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var aim := staff_direction(rig, socket, label, phase)
		var pose := Transform3D(Basis(Quaternion(Vector3.UP, aim)).scaled_local(socket.basis.get_scale()), socket.origin)
		var brace: Variant = null
		if label == "StaffCast" and gesture_strength(phase) > 0.93:
			brace = rig.to_global(rig.get_bone_global_pose(rig.find_bone("cp_grasp_lhand")).origin)
		clearance.update_pose()
		var ground := -0.09 if label == "Death" else 0.012
		pose = fit_staff(pose, socket, previous if sample > 0 else pose.basis, points, clearance, brace, ground)
		previous = pose.basis
		var local := staff_local_rotation(socket, pose.basis)
		var actual := Transform3D(socket.basis * Basis(local), socket.origin)
		if clearance.crosses_staff(actual, 0.0, brace):
			crossings += 1
		floor = minf(floor, floor_gap(actual, points))
		motion.rotation_track_insert_key(track, time, local)
	print(label, " staff floor / shaft crossings ", [floor, crossings], " / parent ", rig.get_bone_name(rig.get_bone_parent(staff)))

func fit_staff(desired: Transform3D, socket: Transform3D, previous: Basis, points: PackedVector3Array,
		clearance: RefCounted, brace: Variant, floor: float) -> Transform3D:
	var wanted := desired.basis.orthonormalized().get_rotation_quaternion()
	var preceding := previous.orthonormalized().get_rotation_quaternion()
	var blended := desired
	blended.basis = Basis(preceding.slerp(wanted, 0.34)).scaled_local(desired.basis.get_scale())
	if staff_fits(blended, socket, points, clearance, brace, floor):
		return blended
	for degrees: float in [4.0, 8.0, 13.0, 20.0, 30.0, 45.0, 65.0, 90.0]:
		var best := desired
		var score := INF
		for axis: Vector3 in TILT_AXES:
			var option := blended
			option.basis = Basis(Quaternion(axis.normalized(), deg_to_rad(degrees))) * blended.basis
			if not staff_fits(option, socket, points, clearance, brace, floor):
				continue
			var difference := option.basis.orthonormalized().get_rotation_quaternion().angle_to(wanted)
			if difference < score:
				best = option
				score = difference
		if is_finite(score):
			return best
	return desired

func staff_fits(target: Transform3D, socket: Transform3D, points: PackedVector3Array,
		clearance: RefCounted, brace: Variant, floor: float) -> bool:
	var rotation := staff_local_rotation(socket, target.basis)
	var actual := Transform3D(socket.basis * Basis(rotation), socket.origin)
	return floor_gap(actual, points) >= floor and not clearance.crosses_staff(actual, 0.023, brace)

func staff_local_rotation(socket: Transform3D, world: Basis) -> Quaternion:
	# The source grasp has nonuniform inherited scale. Preserve the shaft axis
	# explicitly and evaluate the affine transform the saved bone can produce.
	var inverse := socket.basis.inverse()
	var shaft := (inverse * world.y).normalized()
	var across := (inverse * world.x).normalized()
	var normal := across.cross(shaft).normalized()
	return Basis(shaft.cross(normal).normalized(), shaft, normal).get_rotation_quaternion()

func staff_direction(rig: Skeleton3D, socket: Transform3D, label: String, phase: float) -> Vector3:
	var upright := Vector3(-0.24, 1.0, 0.36).normalized()
	var aim := upright
	var amount := gesture_strength(phase)
	if label == "StaffCast":
		var left := rig.find_bone("cp_grasp_lhand")
		var direction := rig.to_global(rig.get_bone_global_pose(left).origin) - socket.origin
		var brace := smoothstep(0.14, 0.40, phase) * (1.0 - smoothstep(0.60, 0.84, phase))
		aim = upright.slerp(direction.normalized(), brace)
	elif label == "Cast2":
		aim = upright.slerp(Vector3(-0.25, 0.02, 1.0).normalized(), amount)
	elif label == "Death":
		aim = upright.slerp(Vector3(-0.7, 0.1, 0.7).normalized(), smoothstep(0.08, 0.71, phase))
	var scale := socket.basis.get_scale()
	var radius := 0.074 * scale.length() / sqrt(3.0)
	var high := clampf((socket.origin.y - radius - 0.014) / (0.5021 * scale.y), 0.0, 1.0)
	var low := -clampf((socket.origin.y - radius - 0.014) / (0.723 * scale.y), 0.0, 1.0)
	var height := clampf(aim.y, low, high)
	var horizontal := Vector3(aim.x, 0.0, aim.z).normalized()
	return horizontal * sqrt(maxf(0.0, 1.0 - height * height)) + Vector3.UP * height

func gesture_strength(phase: float) -> float:
	return smoothstep(0.02, 0.35, phase) * (1.0 - smoothstep(0.61, 0.98, phase))
