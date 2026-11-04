extends "res://../scripts/ophidian-bardiche-clearance.gd"

const AXES := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK,
	Vector3(1, 1, 0), Vector3(-1, 1, 0), Vector3(1, -1, 0), Vector3(-1, -1, 0),
	Vector3(0, 1, 1), Vector3(0, -1, 1), Vector3(0, 1, -1), Vector3(0, -1, -1),
	Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]
const SECTIONS := {
	"Scimitar": [[Vector3(0, 0.13, 0.0), Vector3(0, 0.64, 0.03)],
		[Vector3(0, 0.64, 0.03), Vector3(0, 1.10, 0.10)]],
	"WoodenShield": [[Vector3(-0.286, 0.04, 0.267), Vector3(0.286, 0.04, 0.267)],
		[Vector3(0, -0.25, 0.267), Vector3(0, 0.33, 0.267)],
		[Vector3(-0.20, -0.16, 0.267), Vector3(0.20, 0.24, 0.267)],
		[Vector3(0.20, -0.16, 0.267), Vector3(-0.20, 0.24, 0.267)]],
	"CyclopsMallet": [[Vector3(0.02, -0.102, 0), Vector3(0.02, -0.07, 0)],
		[Vector3(0.025, 0.16, 0), Vector3(0.033, 0.66, -0.07)],
		[Vector3(0.033, 0.66, -0.33), Vector3(0.033, 0.66, 0.19)],
		[Vector3(-0.15, 0.66, -0.07), Vector3(0.21, 0.66, -0.07)]],
}

func crosses_prop(pose: Transform3D, label: String, margin := 0.0) -> bool:
	var offsets := [Vector3.ZERO]
	if margin > 0.0:
		offsets.append_array([pose.basis.x * margin, -pose.basis.x * margin, pose.basis.z * margin, -pose.basis.z * margin])
	for section: Array in SECTIONS[label]:
		var from: Vector3 = pose * section[0]
		var to: Vector3 = pose * section[1]
		var box := AABB(from, Vector3.ZERO).expand(to).grow(margin * 1.6 + 0.0001)
		for triangle in bounds.size():
			if not box.intersects(bounds[triangle]):
				continue
			var first := triangle * 3
			for offset: Vector3 in offsets:
				var point: Variant = Geometry3D.segment_intersects_triangle(from + offset, to + offset,
					deformed[indices[first]], deformed[indices[first + 1]], deformed[indices[first + 2]])
				if point == null:
					continue
				var distance: float = point.distance_to(pose.origin)
				if label == "CyclopsMallet" and grip_triangle(first, "r"):
					var local := pose.affine_inverse() * (point as Vector3)
					if absf(local.y) < 0.30:
						continue
				if label == "WoodenShield" and distance < 0.31 and grip_triangle(first, "l"):
					continue
				return true
	return false

func grip_triangle(first: int, side: String) -> bool:
	var prefix := "bip01 %s " % side
	for corner in 3:
		var weight := 0.0
		var vertex := indices[first + corner]
		for slot in stride:
			var offset := vertex * stride + slot
			var bone := rig.get_bone_name(bones[joints[offset]])
			if bone == prefix + "hand" or bone.begins_with(prefix + "finger"):
				weight += weights[offset]
		if weight < 0.60:
			return false
	return true

func fit_prop(socket: Transform3D, label: String, clip: String, phase: float,
		goal: Basis, previous: Basis, corners: PackedVector3Array) -> Dictionary:
	var floor_limit := 0.012
	if clip == "Death":
		floor_limit = -0.26 if label == "CyclopsMallet" else -0.15
		floor_limit = lerpf(floor_limit, -0.020, smoothstep(0.72, 0.98, phase))
	var blended := Basis(previous.get_rotation_quaternion().slerp(goal.get_rotation_quaternion(), 0.28))
	var preferred := measure(socket, label, blended, corners)
	if preferred.floor >= floor_limit and not preferred.crossed and not crosses_prop(preferred.pose, label, 0.025):
		return preferred
	var fallback := preferred
	for degrees: float in [5.0, 10.0, 18.0, 27.0, 40.0, 57.0, 76.0, 95.0]:
		var best := {}
		var error := INF
		for axis: Vector3 in AXES:
			var heading := Basis(Quaternion(axis.normalized(), deg_to_rad(degrees))) * blended
			var measured := measure(socket, label, heading, corners)
			if not measured.crossed and (fallback.crossed or measured.floor > fallback.floor):
				fallback = measured
			if measured.floor < floor_limit or measured.crossed or crosses_prop(measured.pose, label, 0.025):
				continue
			var deviation := heading.get_rotation_quaternion().angle_to(goal.get_rotation_quaternion())
			if deviation < error:
				error = deviation
				best = measured
		if not best.is_empty():
			return best
	if fallback.crossed and label == "CyclopsMallet":
		return search_mallet(socket, goal, blended, corners, fallback, floor_limit)
	return fallback

func search_mallet(socket: Transform3D, goal: Basis, previous: Basis, corners: PackedVector3Array,
		fallback: Dictionary, floor_limit: float) -> Dictionary:
	var best := fallback
	var error := INF
	for elevation in range(-75, 76, 15):
		for yaw in range(0, 360, 20):
			var turn := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(elevation))
			for roll: float in [0.0, 90.0, 180.0, 270.0]:
				var heading := turn * Basis(Vector3.UP, deg_to_rad(roll))
				var candidate := measure(socket, "CyclopsMallet", heading, corners)
				if candidate.crossed or candidate.floor < floor_limit:
					continue
				var rotation := heading.get_rotation_quaternion()
				var distance := rotation.angle_to(previous.get_rotation_quaternion()) + 0.45 * rotation.angle_to(goal.get_rotation_quaternion())
				if distance < error:
					best = candidate
					error = distance
	return best

func measure(socket: Transform3D, label: String, heading: Basis, corners: PackedVector3Array) -> Dictionary:
	var inverse := socket.basis.inverse()
	var x := (inverse * heading.x).normalized()
	var y := (inverse * heading.y).normalized()
	var z := (inverse * heading.z).normalized()
	if label == "WoodenShield":
		x = y.cross(z).normalized()
		y = z.cross(x).normalized()
	else:
		z = x.cross(y).normalized()
		x = y.cross(z).normalized()
	var local := Basis(x, y, z).get_rotation_quaternion()
	var pose := Transform3D(socket.basis * Basis(local), socket.origin)
	var floor := INF
	for point in corners:
		floor = minf(floor, (pose * point).y)
	return {"heading": heading, "rotation": local, "pose": pose, "floor": floor, "crossed": crosses_prop(pose, label)}
