extends "res://Presentation/SmallSnakeVisual.gd"
## Retained Lich skin with measured biped support and authored staff body art.
const Grip=preload("res://Presentation/LichGrip.gd")
signal landmarks_changed
var staff: Node3D
var body_mesh: MeshInstance3D
var finger_fit: Dictionary={}
var staff_grip_transform:=Transform3D.IDENTITY
var staff_local_bounds:=AABB()
func staff_meshes() -> Array:
	if staff==null:return []
	var result: Array=staff.find_children("*","MeshInstance3D",true,false)
	if staff is MeshInstance3D:result.push_front(staff)
	return result
func _ready() -> void:
	super._ready()
	body_mesh=model.find_children("*","MeshInstance3D",true,false)[0]
	contact.free();contact=preload("res://Presentation/MeasuredCreatureSupport.gd").new();skeleton.add_child(contact);contact.include_toe_descendants=true;contact.model_root=model;contact.flat_basis=source_model_basis.scaled_local(default_model_scale);contact.configure(body_mesh,false)
	if treatment=="modern":
		animator.advance(0.);skeleton.force_update_all_bone_transforms()
		var socket:=skeleton.find_bone("cp_grasp_rhand");assert(socket>=0)
		var attachment:=BoneAttachment3D.new();attachment.bone_name="cp_grasp_rhand";skeleton.add_child(attachment);staff=load(str(entry.staff_asset)).instantiate() as Node3D;attachment.add_child(staff)
		staff.basis=(skeleton.global_basis*skeleton.get_bone_global_pose(socket).basis).orthonormalized().inverse()*global_basis.orthonormalized()*Basis(Vector3.UP,PI/2.)
		staff.scale*=float(entry.staff.relative_scale);staff_grip_transform=staff.transform
		# BoneAttachment updates can be deferred until after the animation mixer.
		# Evaluate the actual socket explicitly so support uses this pose's pole.
		staff.top_level=true;staff.global_transform=staff_socket_transform()
		for mesh: MeshInstance3D in staff_meshes():mesh.set_meta("source_lich_staff",true)
		var first:=true
		for mesh: MeshInstance3D in staff_meshes():
			var box: AABB=(staff.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb();staff_local_bounds=box if first else staff_local_bounds.merge(box);first=false
		finger_fit=Grip.calibrate(body_mesh,skeleton,staff)
		animator.mixer_applied.connect(update_grip);contact.modification_processed.connect(update_grip);update_grip();set_hue(native_hue)
	update_landmarks()
func update_grip() -> void:
	if not finger_fit.is_empty():
		var dying:=animator.assigned_animation in ["Death","Death2","LieDown"]
		staff.global_transform=staff_socket_transform()
		if dying:
			for bone: int in finger_fit.source_rotations:skeleton.set_bone_pose_rotation(bone,finger_fit.source_rotations[bone])
			skeleton.force_update_all_bone_transforms();rest_staff()
		else:
			fit_held_staff();Grip.apply(skeleton,finger_fit)
	update_landmarks()
func staff_socket_transform() -> Transform3D:
	return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("cp_grasp_rhand"))*staff_grip_transform
func fit_held_staff() -> void:
	var normal:=support_normal();var lift:=.003-staff_gap(staff.global_transform,normal)
	if lift<=0.:return
	var upper:=skeleton.find_bone("bip01 r upperarm");var elbow:=skeleton.find_bone("bip01 r forearm");var hand:=skeleton.find_bone("bip01 r hand")
	var a:=skeleton.get_bone_global_pose(upper).origin;var b:=skeleton.get_bone_global_pose(elbow).origin;var pose:=skeleton.get_bone_global_pose(hand);var c:=pose.origin;var target:=skeleton.to_local(skeleton.to_global(c)+normal*lift);var first:=a.distance_to(b);var second:=b.distance_to(c);var axis: Vector3=(target-a).normalized();var distance:=clampf(a.distance_to(target),absf(first-second)+.0001,first+second-.0001);target=a+axis*distance
	# Choose the elbow on its measured circle nearest the original forearm
	# direction, avoiding an unnecessary wrist bend while raising the pole.
	var ideal:=target-(c-b).normalized()*second;var pole: Vector3=(ideal-a).slide(axis)
	if pole.length_squared()<.00000001:pole=(b-a).slide(axis)
	var along: float=(first*first-second*second+distance*distance)/(2.*distance);var joint:=a+axis*along+pole.normalized()*sqrt(maxf(0.,first*first-along*along))
	Grip.aim(skeleton,upper,b,joint);Grip.aim(skeleton,elbow,skeleton.get_bone_global_pose(hand).origin,target)
	var adjusted:=skeleton.get_bone_global_pose(hand);adjusted.basis=pose.basis;skeleton.set_bone_global_pose(hand,adjusted);skeleton.force_update_all_bone_transforms()
	staff.global_transform=staff_socket_transform()
func support_normal() -> Vector3:
	# The imported source floor track is measured relative to this model root.
	# Its basis already follows terrain; no full body skin is evaluated here.
	return (model.global_basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized()
func staff_gap(transform: Transform3D,normal: Vector3) -> float:
	var lowest:=INF
	for i in 8:lowest=minf(lowest,normal.dot(transform*staff_local_bounds.get_endpoint(i)-model.global_position))
	return lowest
func rest_staff() -> void:
	var phase:=animator.current_animation_position/maxf(.001,animator.current_animation_length);var blend:=smoothstep(.05,.75,phase);var grip:=staff_socket_transform()
	var normal:=support_normal();var head:=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("bip01 head")).origin);var direction: Vector3=(head-grip.origin).slide(normal)
	if direction.length_squared()<.01:direction=global_basis.z.slide(normal)
	direction=direction.normalized();var rest:=Basis(normal,direction,normal.cross(direction)).scaled_local(grip.basis.get_scale());var resting_origin:=grip.origin+normal*(.003-staff_gap(Transform3D(rest,grip.origin),normal))
	var orientation:=grip.basis.orthonormalized().slerp(rest.orthonormalized(),blend).scaled_local(grip.basis.get_scale());var placed:=Transform3D(orientation,grip.origin.lerp(resting_origin,blend));var lowest:=staff_gap(placed,normal)
	if lowest<.003:placed.origin+=normal*(.003-lowest)
	staff.global_transform=placed
func update_landmarks() -> void:
	super.update_landmarks()
	if staff==null or not has_meta("pick_bounds"):return
	var box: AABB=get_meta("pick_bounds")
	for mesh: MeshInstance3D in staff_meshes():box=box.merge((global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb())
	set_meta("pick_bounds",box.grow(.01));set_meta("nameplate_height",box.end.y+.08)
	landmarks_changed.emit()
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source==null:continue
			if mesh.has_meta("source_lich_staff"):mesh.set_surface_override_material(surface,source)
			elif mesh.skin!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/LichMaterial.gd").build(source,entry,value))
