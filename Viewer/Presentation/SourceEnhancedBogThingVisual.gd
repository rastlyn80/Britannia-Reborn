# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BogThingActionsVisual.gd"

const Sprout := "BogThingSprout"
const Taste := "BogThingMawTaste"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var growth := preload("res://Presentation/CreatureGrowthRecovery.gd").new()
var fall_skin: Dictionary
var fall_plane: Dictionary
var fall_lift := 0.0
var tongue: MeshInstance3D


func _ready() -> void:
	super._ready()
	fall_skin = Ground.skin_points(base_mesh, skeleton)
	tongue = make_tongue()
	add_child(tongue)
	animator.mixer_applied.connect(update_fitted_pose)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not dead and model.transform.is_equal_approx(neutral_model) and (
			growth.active or current_clip in entry.get("archive_grounded_gestures", [])):
		plant_fitted_footprint()
	update_tongue()


func plant_fitted_footprint() -> void:
	# The actor's server height remains a usable support plane when the local
	# collision patch has no ray hit under the original footprint.
	if footprint.is_empty():
		return
	var plane := fitted_ground()
	var point: Vector3 = plane.position
	var normal: Vector3 = plane.normal
	var arrays := base_mesh.mesh.surface_get_arrays(0)
	var transforms := skin_transforms(base_mesh, skeleton.global_transform)
	var gap := INF
	for vertex: int in footprint:
		gap = minf(gap, (weighted_point(arrays, transforms, vertex) - point).dot(normal))
	model.global_position.y -= gap / normal.y


func fitted_ground() -> Dictionary:
	var hit := ground_hit(global_position)
	if hit.is_empty() or hit.normal.y < .8:
		return {"position": global_position, "normal": Vector3.UP}
	return hit


func update_fitted_pose() -> void:
	if dead:
		settle_fall()
	elif current_clip == Sprout or current_clip not in entry.get("archive_grounded_gestures", []):
		growth.apply(self, Sprout)
	else:
		growth.active = false
	update_tongue()


func update_tongue() -> void:
	if tongue == null:
		return
	tongue.visible = false
	if dead or current_clip != Taste or animator.current_animation_length <= 0.0:
		return
	var phase := animator.current_animation_position / animator.current_animation_length
	var reach := smoothstep(.29, .47, phase) * (1.0 - smoothstep(.68, .89, phase))
	if reach <= .025:
		return
	skeleton.force_update_all_bone_transforms()
	var jaw := joint_position("lower jaw bone")
	var lip := joint_position("box13")
	var direction := (lip - jaw).normalized()
	tongue.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP, true),
		jaw.lerp(lip, .70) + Vector3.UP * .042)
	tongue.scale = Vector3(.75 + .25 * reach, .80 + .20 * reach, .34 + .66 * reach)
	tongue.visible = true


func joint_position(label: String) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(label)).origin)


func make_tongue() -> MeshInstance3D:
	const Bands := 16
	const Sides := 20
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in Bands + 1:
		var phase := float(band) / Bands
		var taper := sqrt(maxf(.0001, 1.0 - pow(phase, 5.0)))
		for edge in Sides:
			var angle := TAU * edge / Sides
			var point := Vector3(.192 * taper * cos(angle), .065 * taper * sin(angle) - .06 * phase * phase, .48 * phase)
			surface.add_vertex(point)
	for band in Bands:
		for edge in Sides:
			var a := band * Sides + edge
			var b := band * Sides + (edge + 1) % Sides
			for index: int in [a, a + Sides, b, b, a + Sides, b + Sides]:
				surface.add_index(index)
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#79403f")
	material.roughness = .39
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = "BogThingTongue"
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.visible = false
	return instance


func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in source.entry.get("archive_grounded_gestures", []) and not source.growth.active:
		return super.begin_death_from(source)
	global_transform = source.global_transform
	model.transform = source.model.transform
	current_clip = "Death"
	var duration := super.begin_death_from(source)
	fall_plane = source.fitted_ground()
	settle_fall()
	return duration


func settle_fall() -> void:
	if fall_plane.is_empty():
		return
	model.global_position.y -= fall_lift
	skeleton.force_update_all_bone_transforms()
	var normal: Vector3 = fall_plane.normal
	var gap := Ground.minimum_plane_gap(fall_skin, skeleton, skeleton.global_transform, fall_plane.position, normal)
	var entering := animator.assigned_animation != "Death"
	var clearance := .002 * smoothstep(0.0, .04, animator.current_animation_position) if entering else .002
	var displacement := clearance - gap
	if displacement < 0.0:
		var phase := 0.0 if entering else animator.current_animation_position / animator.current_animation_length
		displacement *= smoothstep(.74, 1.0, phase)
	fall_lift = displacement / normal.y
	model.global_position.y += fall_lift
