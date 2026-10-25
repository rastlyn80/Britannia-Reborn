extends SpringArm3D

var requested_distance := 7.0
var visual_distance := 7.0

func _ready() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.24
	shape = sphere
	margin = 0.12
	collision_mask = 1
	spring_length = requested_distance

func set_distance(distance: float, delta: float) -> void:
	# SpringArm performs a shape sweep, catches corners with a real radius and
	# places its camera child before the hit surface. Zoom changes are smoothed.
	requested_distance = distance
	# Sweep the requested full range every physics frame. Smoothing the arm's
	# length fed the shortened hit back into the next sweep and caused pumping.
	spring_length = distance
	var obstruction := get_hit_length() if collision_mask != 0 else distance
	var target := minf(distance,maxf(0.0,obstruction))
	visual_distance = target if target < visual_distance else lerpf(visual_distance,target,1.0-exp(-5.0*delta))
	for child in get_children():
		if child is Camera3D:
			# SpringArm owns child position during physics; this extra inward offset
			# only delays outward recovery, never moves through the sweep result.
			child.position.z = minf(target,visual_distance)

func headroom(space: PhysicsDirectSpaceState3D, ground: Vector3, maximum: float = 1.0) -> float:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,ground+Vector3(0,0.95,0))
	query.collision_mask = 1
	query.margin = 0.025
	query.motion = Vector3.UP*maximum
	if not space.intersect_shape(query,1).is_empty(): return 0.0
	var travel := space.cast_motion(query)
	return maxf(0.0,maximum*travel[0]-0.05) if travel.size() == 2 else 0.0
