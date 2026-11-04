extends "res://../scripts/ophidian-bardiche-clearance.gd"

## The staff is a thinner, shorter prop. Only test the shaft outside the grasp.
func crosses_staff(pose: Transform3D, margin := 0.0, brace: Variant = null) -> bool:
	var offsets := [Vector3.ZERO]
	if margin > 0.0:
		for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			offsets.append(pose.basis * axis * margin)
	for section: Vector2 in [Vector2(-0.502, -0.16), Vector2(0.16, 0.723)]:
		var from := pose * Vector3(0, section.x, 0)
		var to := pose * Vector3(0, section.y, 0)
		var range_box := AABB(from, Vector3.ZERO).expand(to).grow(margin * 1.5 + 0.0001)
		for triangle in bounds.size():
			if not range_box.intersects(bounds[triangle]):
				continue
			var first := triangle * 3
			for offset: Vector3 in offsets:
				var point: Variant = Geometry3D.segment_intersects_triangle(from + offset, to + offset,
					deformed[indices[first]], deformed[indices[first + 1]], deformed[indices[first + 2]])
				if point != null and (brace == null or point.distance_to(brace) > 0.09):
					return true
	return false
