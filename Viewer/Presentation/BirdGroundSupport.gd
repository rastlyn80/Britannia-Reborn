extends "res://Presentation/SourceMountContact.gd"
## The licensed bird has independent foot-control roots; align its support
## plane without treating wing bones or IK controls as stance limbs.
func configure(mesh: MeshInstance3D,_quadruped: bool) -> void:
	surface=mesh;feet.clear()
func sample(space: PhysicsDirectSpaceState3D,origin: Vector3) -> void:
	origin_y=origin.y;contacts.clear();stance_gaps.clear()
	if not enabled:return
	var from:=origin+Vector3.UP*.65
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*1.3,1))
	if not hit.is_empty() and hit.normal.y>.75 and absf(hit.position.y-origin.y)<.45:contacts[0]=hit
