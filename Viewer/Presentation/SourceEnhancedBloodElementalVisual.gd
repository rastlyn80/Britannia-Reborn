# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BloodElementalActionsVisual.gd"

const Rise := "BloodElementalPoolRise"
const Shell := preload("blood-elemental-shell.gd")
const Fluid := preload("res://Presentation/SourceFluidElementalMaterial.gd")
var growth := preload("res://Presentation/CreatureGrowthRecovery.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_pose := Transform3D.IDENTITY
var fitted_supported := false
var pool: MeshInstance3D


func _ready() -> void:
	super._ready()
	var crest := model.find_child("BloodSurgeCrest", true, false) as MeshInstance3D
	assert(crest != null)
	add_crest_skin(Ground.skin_points(crest, skeleton))
	fitted_fall.skin = support_skin
	fall.skin = support_skin
	pool = Shell.pool_mesh()
	add_child(pool)
	contact.modification_processed.connect(refresh_growth_floor)


func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null or treatment != "modern":
		return
	var crest := model.find_child("BloodSurgeCrest", true, false) as MeshInstance3D
	if crest != null:
		var material := crest.get_active_material(0) as ShaderMaterial
		material.set_shader_parameter("use_source_alpha", false)
		material.set_meta("snapshot_uniform_time", true)
	if pool != null:
		var source := pool.mesh.surface_get_material(0) as StandardMaterial3D
		var material := Fluid.build(source, entry, value, fluid_clock)
		material.set_shader_parameter("use_source_alpha", false)
		pool.set_surface_override_material(0, material)
		fluid_materials.append(material)


func add_crest_skin(crest: Dictionary) -> void:
	support_skin = support_skin.duplicate(true)
	var offset: int = support_skin.bones.size()
	support_skin.bones.append_array(crest.bones)
	support_skin.bind_poses.append_array(crest.bind_poses)
	for part: Dictionary in crest.surfaces:
		var surface := part.duplicate()
		var bindings: PackedInt32Array = part.bindings.duplicate()
		for index in bindings.size():
			bindings[index] += offset
		surface.bindings = bindings
		support_skin.surfaces.append(surface)


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_fitted_pose()
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if not growth.active and not is_fitted() and fitted_fall.plane.is_empty():
		restore_fitted_pose()
		super._physics_process(delta)


func support_death_blend() -> void:
	restore_fitted_pose()
	if pool != null:
		pool.visible = false
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
		return
	super.support_death_blend()
	if dead:
		support_retained_collapse()
		return
	if support_skin.is_empty():
		return
	var recovering := growth.apply(self, Rise)
	if is_fitted() or recovering:
		support_fluid_pose()


func support_fluid_pose() -> void:
	var plane := fitted_fall.floor_under(self)
	var normal: Vector3 = plane.normal
	fitted_pose = model.transform
	fitted_supported = true
	var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (slope * source_model_basis).scaled_local(fitted_pose.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, plane.position, normal)
	model.global_position.y += (.003 - gap) / normal.y
	show_pool(plane)
	update_landmarks()


func restore_fitted_pose() -> void:
	if fitted_supported:
		model.transform = fitted_pose
		fitted_supported = false


func refresh_growth_floor() -> void:
	if not dead and growth.active and not is_fitted():
		restore_fitted_pose()
		support_fluid_pose()


func show_pool(plane: Dictionary) -> void:
	if pool == null or current_clip != Rise:
		return
	var phase: float = animator.current_animation_position / animator.current_animation_length
	if phase >= .59:
		return
	var draw := 1.0 - smoothstep(.07, .59, phase)
	var normal: Vector3 = plane.normal
	var frame := Basis(Quaternion(Vector3.UP, normal)).scaled_local(Vector3(draw, draw * .8, draw))
	pool.global_transform = Transform3D(frame, plane.position + normal * .005)
	pool.visible = true


func support_retained_collapse() -> void:
	if not pose_entry.active:
		return
	var normal: Vector3 = pose_entry.plane_normal
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, pose_entry.plane_origin, normal)
	if gap < .002:
		model.global_position.y += (.002 - gap) / normal.y


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted() and not source.growth.active:
		return super.begin_death_from(source)
	fluid_clock = source.fluid_clock
	for material: ShaderMaterial in fluid_materials:
		material.set_shader_parameter("fluid_time", fluid_clock)
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
