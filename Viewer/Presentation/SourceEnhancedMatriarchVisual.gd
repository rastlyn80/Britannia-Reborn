# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/TerathanActionsVisual.gd"

const Clearance := preload("matriarch-sceptre-clearance.gd")
const GripBone := "cp_grasp_rhand"
const StaffBone := "matriarch ceremonial staff"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var sceptre: MeshInstance3D
var sceptre_skin: Dictionary
var body_clearance: RefCounted
var held_in_fall := false
var starting_fall := false
var fall_axis := Vector3.ZERO


func _ready() -> void:
	super._ready()
	sceptre = model.find_child("MatriarchSceptre", true, false)
	assert(sceptre != null)
	sceptre.set_meta("optional_corpse_visual_prop", true)
	sceptre.set_meta("corpse_prop_keeps_material", true)
	sceptre.visible = false
	sceptre_skin = Ground.skin_points(sceptre, skeleton)
	fitted_fall.skin = skin
	entry = entry.merged({"grounded_gestures": entry.grounded_gestures + entry.get("archive_grounded_gestures", [])}, true)


func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null:
		return
	var prop := model.find_child("MatriarchSceptre", true, false) as MeshInstance3D
	if prop != null:
		prop.set_surface_override_material(0, null)


func is_sceptre_action(clip: String) -> bool:
	return clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	var was_holding := is_sceptre_action(current_clip)
	if not super.receive_action(request):
		return false
	if dead and was_holding:
		held_in_fall = true
		fall_axis = displayed_sceptre_axis()
		fitted_fall.remember_floor(self, fall.plane)
		fall.plane = {}
	sceptre.visible = held_in_fall or is_sceptre_action(current_clip)
	return true


func begin_death_from(source: Node3D) -> float:
	if not source.sceptre.visible:
		return super.begin_death_from(source)
	held_in_fall = true
	fall_axis = source.displayed_sceptre_axis()
	sceptre.visible = true
	starting_fall = true
	var duration := fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	starting_fall = false
	settle_falling_sceptre()
	return duration


func settle() -> void:
	if sceptre == null:
		super.settle()
		return
	sceptre.visible = held_in_fall or is_sceptre_action(current_clip)
	if dead and not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		if not starting_fall:
			settle_falling_sceptre()
		return
	super.settle()
	if sceptre.visible and gesture_supported:
		support_sceptre(fall.floor_under(self))


func support_sceptre(floor: Dictionary) -> Vector3:
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(sceptre_skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
	var before := model.position
	model.global_position.y += maxf(0.0, .002 - gap) / float(floor.normal.y)
	return model.position - before


func displayed_sceptre_axis() -> Vector3:
	var joint := skeleton.find_bone(StaffBone)
	skeleton.force_update_all_bone_transforms()
	return (skeleton.global_basis * skeleton.get_bone_global_pose(joint).basis).y.normalized()


func settle_falling_sceptre() -> void:
	if body_clearance == null:
		var body := model.find_child("Body", true, false) as MeshInstance3D
		body_clearance = Clearance.new(body, skeleton)
		var bounds := sceptre.mesh.get_aabb()
		body_clearance.shaft = Vector2(bounds.position.y, bounds.end.y)
	var floor := fitted_fall.plane
	var grip := skeleton.find_bone(GripBone)
	var joint := skeleton.find_bone(StaffBone)
	skeleton.force_update_all_bone_transforms()
	var frame := skeleton.global_transform * skeleton.get_bone_global_pose(grip)
	body_clearance.update_pose()
	var chosen := Quaternion(Vector3.UP, (frame.basis.inverse() * fall_axis).normalized())
	if animator.current_animation_position > .000001:
		chosen = fall_sceptre_pose(frame, floor)
	skeleton.set_bone_pose_rotation(joint, chosen)
	fall_axis = (frame.basis * Basis(chosen)).y.normalized()
	fitted_fall.shift += support_sceptre(floor)


func fall_sceptre_pose(frame: Transform3D, floor: Dictionary) -> Quaternion:
	var normal: Vector3 = floor.normal
	var wanted := fall_axis
	var options: Array[Vector3] = [wanted, wanted.slide(normal).normalized(), normal, global_basis.z.normalized(),
		-global_basis.x.normalized(), global_basis.x.normalized(), -global_basis.z.normalized()]
	for angle: float in [.12, .24, .42, .67, .98]:
		for around: Vector3 in [normal, Vector3.RIGHT, Vector3.FORWARD]:
			options.append(wanted.rotated(around, angle))
			options.append(wanted.rotated(around, -angle))
	var best := Quaternion(Vector3.UP, (frame.basis.inverse() * wanted).normalized())
	var best_cost := INF
	var bounds := sceptre.mesh.get_aabb()
	for direction: Vector3 in options:
		if direction.is_zero_approx():
			continue
		var pose := Quaternion(Vector3.UP, (frame.basis.inverse() * direction).normalized())
		var staff := Transform3D(frame.basis * Basis(pose), frame.origin)
		var bottom := minf(normal.dot(staff * Vector3.UP * bounds.position.y - floor.position),
			normal.dot(staff * Vector3.UP * bounds.end.y - floor.position))
		var cost := .5 * direction.angle_to(wanted) + 9.0 * maxf(0.0, .01 - bottom)
		if cost < best_cost and clear_sceptre(staff):
			best = pose
			best_cost = cost
			if is_zero_approx(cost):
				break
	if not is_finite(best_cost):
		# The original collapse can turn the grip almost completely over.
		# Search around the full grip only when the nearby directions fail.
		for sample in 64:
			var y := 1.0 - 2.0 * (sample + .5) / 64.0
			var radius := sqrt(1.0 - y * y)
			var heading := sample * 2.3999632297
			var direction := Vector3(cos(heading) * radius, y, sin(heading) * radius)
			var pose := Quaternion(Vector3.UP, (frame.basis.inverse() * direction).normalized())
			var staff := Transform3D(frame.basis * Basis(pose), frame.origin)
			var bottom := minf(normal.dot(staff * Vector3.UP * bounds.position.y - floor.position),
				normal.dot(staff * Vector3.UP * bounds.end.y - floor.position))
			var cost := .5 * direction.angle_to(wanted) + 9.0 * maxf(0.0, .01 - bottom)
			if cost < best_cost and clear_sceptre(staff):
				best = pose
				best_cost = cost
	set_meta("sceptre_fall_clear", is_finite(best_cost))
	return best


func clear_sceptre(pose: Transform3D) -> bool:
	return not body_clearance.crosses_sceptre(pose, .008) and not body_clearance.crosses_sceptre(pose, .014)


func corpse_snapshot_floor() -> float:
	if fitted_fall.plane.is_empty():
		return super.corpse_snapshot_floor()
	return minf(fitted_fall.snapshot_floor(self), Ground.minimum_plane_gap(sceptre_skin, skeleton,
		global_transform.affine_inverse() * skeleton.global_transform, Vector3.ZERO, Vector3.UP))
