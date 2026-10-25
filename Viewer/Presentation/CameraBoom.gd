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
	var obstruction := get_hit_length()
	if collision_mask != 0 and obstruction > 0.001 and obstruction < spring_length-0.04:
		visual_distance = minf(visual_distance,obstruction)
	visual_distance = lerpf(visual_distance,distance,1.0-exp(-12.0*delta))
	spring_length = visual_distance

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
