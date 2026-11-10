# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/JukaLordActionsVisual.gd"

const Hue := preload("res://Presentation/HumanHue.gd")

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_transform := Transform3D.IDENTITY
var fitted_support := false
var bow_hue := 0


func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin


func set_equipment(worn: Array) -> void:
	super.set_equipment(worn)
	if not is_instance_valid(bow_holder) or not bow_holder.visible:
		return
	for item: Dictionary in worn:
		if int(item.get("id", 0)) in [0x13b1, 0x13b2] and int(item.get("layer", 2)) == 2:
			bow_hue = int(item.get("hue", 0))
			apply_bow_hue()
			break


func load_bow() -> void:
	super.load_bow()
	if is_instance_valid(bow_holder):
		bow_mesh.name = "JukaBow"
		bow_mesh.set_meta("corpse_prop_keeps_material", true)


func set_hue(value: int) -> void:
	super.set_hue(value)
	if is_instance_valid(bow_mesh):
		apply_bow_hue()


func apply_bow_hue() -> void:
	var source := rest_mesh.surface_get_material(0) as StandardMaterial3D
	if source != null:
		bow_mesh.set_surface_override_material(0, Hue.material(source, bow_hue) if bow_hue != 0 else source)


func update_bow() -> void:
	super.update_bow()
	if not dead or not is_instance_valid(bow_holder) or not bow_holder.visible:
		return
	var plane := fitted_fall.plane
	if plane.is_empty():
		plane = fitted_fall.floor_under(self)
	var normal: Vector3 = plane.normal
	var grip := bow_holder.global_position
	var at_grip := normal.dot(grip - Vector3(plane.position))
	var bow_basis := bow_holder.global_basis
	var relative_mesh := bow_holder.global_transform.affine_inverse() * bow_mesh.global_transform
	var vertices: PackedVector3Array = rest_arrays[Mesh.ARRAY_VERTEX]
	const Clearance := .003
	if bow_floor_gap(vertices, relative_mesh, bow_basis.inverse() * normal, at_grip) >= Clearance:
		return
	# Rotate about the retained grasp. The source bow's thinnest axis is X.
	var thin := bow_mesh.global_basis.x.normalized()
	var up := normal if thin.dot(normal) >= 0.0 else -normal
	var flatten := Quaternion(thin, up)
	if bow_floor_gap(vertices, relative_mesh, bow_basis.inverse() * (flatten.inverse() * normal), at_grip) < Clearance:
		flatten = Quaternion(thin, -up)
	var lower := 0.0
	var upper := 1.0
	for iteration in 12:
		var weight := (lower + upper) * .5
		var turn := Quaternion.IDENTITY.slerp(flatten, weight)
		var test_normal := bow_basis.inverse() * (turn.inverse() * normal)
		if bow_floor_gap(vertices, relative_mesh, test_normal, at_grip) < Clearance:
			lower = weight
		else:
			upper = weight
	bow_holder.global_basis = Basis(Quaternion.IDENTITY.slerp(flatten, upper)) * bow_basis


func bow_floor_gap(vertices: PackedVector3Array, relative_mesh: Transform3D,
		normal: Vector3, grip_height: float) -> float:
	var direction := relative_mesh.basis.transposed() * normal
	var minimum := INF
	for point: Vector3 in vertices:
		minimum = minf(minimum, direction.dot(point))
	return minimum + normal.dot(relative_mesh.origin) + grip_height


func bow_release_available() -> bool:
	return not dead and is_instance_valid(bow_holder) and bow_holder.is_visible_in_tree()


func begin_bow_release() -> float:
	if not bow_release_available():
		return -1.0
	const DrawStart := .27
	const Release := .49
	var duration := animator.get_animation("AttackBow").length
	if (current_clip != "AttackBow" or animator.assigned_animation != "AttackBow"
			or action_remaining <= 0.0 or not animator.is_playing()):
		release_fitted()
		current_clip = "AttackBow"
		contact.enabled = true
		animator.speed_scale = 1.0
		animator.play(current_clip, .08)
		animator.seek(duration * DrawStart, false)
		action_remaining = duration * (1.0 - DrawStart)
		return duration * (Release - DrawStart)
	return maxf(0.0, duration * Release - animator.current_animation_position)


func bow_arrow_origin() -> Vector3:
	return bow_mesh.to_global(string_center + applied_draw + Vector3(0.0, .025, 0.0))


func is_fitted() -> bool:
	return not dead and current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_fitted()
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if is_fitted():
		apply_blend_ground()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func apply_blend_ground() -> void:
	release_fitted()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	elif is_fitted() and not support_skin.is_empty():
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		unposed_transform = model.transform
		fitted_support = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
		contact.base_model_y = model.position.y
	else:
		super.apply_blend_ground()
		return
	update_bow()
	update_landmarks()


func release_fitted() -> void:
	if fitted_support:
		model.transform = unposed_transform
		fitted_support = false


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	play("Death", .08)
	return animator.get_animation("Death").length


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
