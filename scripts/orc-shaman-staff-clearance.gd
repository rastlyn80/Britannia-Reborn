# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/ophidian-bardiche-clearance.gd"

const Shape := Vector3(.70, .83, .70)
const Shafts := [Vector2(-.713, -.18) * Shape.y, Vector2(.18, 1.649) * Shape.y]


func crosses_staff(pose: Transform3D, margin: float) -> bool:
	var offsets := [Vector3.ZERO, Vector3.RIGHT * margin, Vector3.LEFT * margin,
		Vector3.BACK * margin, Vector3.FORWARD * margin]
	for shaft: Vector2 in Shafts:
		var from := pose * Vector3(0, shaft.x, 0)
		var to := pose * Vector3(0, shaft.y, 0)
		var range_box := AABB(from, Vector3.ZERO).expand(to).grow(margin * 1.5 + .0001)
		for triangle in bounds.size():
			if not range_box.intersects(bounds[triangle]):
				continue
			var first := triangle * 3
			for offset: Vector3 in offsets:
				var shift := pose.basis * offset
				if Geometry3D.segment_intersects_triangle(from + shift, to + shift, deformed[indices[first]],
						deformed[indices[first + 1]], deformed[indices[first + 2]]) != null:
					return true
	return false

