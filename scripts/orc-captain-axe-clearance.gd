extends "res://../scripts/bone-knight-cyclops-clearance.gd"

const AXE_SEGMENTS := [
	[Vector3(0, -0.211, 0.0), Vector3(0, -0.105, 0.0)],
	[Vector3(0, 0.105, 0.0), Vector3(0, 0.847, 0.0)],
	[Vector3(0, 0.70, -0.137), Vector3(0, 0.70, 0.137)],
	[Vector3(0, 0.63, -0.099), Vector3(0, 0.63, 0.10)],
]


func crosses_prop(pose: Transform3D, _label: String, margin := 0.0) -> bool:
	var shifts: Array[Vector3] = [Vector3.ZERO]
	if margin > 0.0:
		shifts.append_array([pose.basis.x * margin, -pose.basis.x * margin, pose.basis.z * margin, -pose.basis.z * margin])
	for section: Array in AXE_SEGMENTS:
		var first: Vector3 = pose * section[0]
		var last: Vector3 = pose * section[1]
		var line := AABB(first, Vector3.ZERO).expand(last).grow(margin * 1.6 + 0.0001)
		for triangle: int in bounds.size():
			if not line.intersects(bounds[triangle]):
				continue
			var start := triangle * 3
			for shift in shifts:
				var hit: Variant = Geometry3D.segment_intersects_triangle(first + shift, last + shift,
					deformed[indices[start]], deformed[indices[start + 1]], deformed[indices[start + 2]])
				if hit != null and not grip_triangle(start, "r"):
					return true
	return false

func solve(socket: Transform3D, desired: Basis, previous: Basis, corners: PackedVector3Array, floor: float) -> Dictionary:
	const LABEL := "OrcCaptainAxe"
	var target := desired.get_rotation_quaternion()
	var last := previous.get_rotation_quaternion()
	var start := Basis(last.slerp(target, 0.35))
	var selected := measure(socket, LABEL, start, corners)
	if is_safe(selected, floor):
		return selected
	var best := selected
	for angle: float in [3.0, 6.0, 10.0, 16.0, 24.0, 38.0, 58.0, 80.0, 115.0, 155.0]:
		var error := INF
		for axis: Vector3 in AXES:
			var heading := Basis(Quaternion(axis.normalized(), deg_to_rad(angle))) * start
			var found := measure(socket, LABEL, heading, corners)
			if not found.crossed and (best.crossed or found.floor > best.floor):
				best = found
			if not is_safe(found, floor):
				continue
			var rotation := heading.get_rotation_quaternion()
			var cost := rotation.angle_to(target) + 0.55 * rotation.angle_to(last)
			if cost < error:
				error = cost
				selected = found
		if error < INF:
			return selected
	return best

func is_safe(result: Dictionary, floor: float) -> bool:
	return not result.crossed and result.floor >= floor and not crosses_prop(result.pose, "OrcCaptainAxe", 0.015)

func solve_continuous(socket: Transform3D, desired: Basis, previous: Basis,
		corners: PackedVector3Array, floor: float) -> Dictionary:
	const LABEL := "OrcCaptainAxe"
	var target := desired.get_rotation_quaternion()
	var last := previous.get_rotation_quaternion()
	var max_turn := deg_to_rad(3.0)
	var requested_turn := last.angle_to(target)
	var change := minf(max_turn, requested_turn * 0.18)
	var proposal := Basis(last.slerp(target, change / maxf(requested_turn, 0.00001)))
	var preferred := measure(socket, LABEL, proposal, corners)
	if is_safe(preferred, floor):
		return preferred
	for degrees: float in [0.0, 1.0, 2.0, 3.0, 4.0, 6.0, 9.0, 15.0, 24.0, 38.0, 58.0, 85.0]:
		var best := {}
		var error := INF
		for axis: Vector3 in AXES:
			var heading := Basis(Quaternion(axis.normalized(), deg_to_rad(degrees))) * previous
			var rotation := heading.get_rotation_quaternion()
			var cost := rotation.angle_to(target)
			if cost < error:
				var candidate := measure(socket, LABEL, heading, corners)
				if is_safe(candidate, floor):
					best = candidate
					error = cost
			if degrees == 0.0:
				break
		if not best.is_empty():
			return best
	return solve(socket, desired, previous, corners, floor)
