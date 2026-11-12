# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/WispActionsVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Fall := preload("res://Presentation/CougarTerrainFall.gd")
var terrain := Terrain.new()
var fall := Fall.new()
var beginning_fall := false
var entry_phase := NAN


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(.62, .62))
	var combined := terrain.skin.duplicate()
	combined.surfaces = combined.surfaces.duplicate()
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for index in range(1, meshes.size()):
		var part := Terrain.Ground.skin_points(meshes[index], skeleton)
		assert(part.bones == combined.bones and part.bind_poses == combined.bind_poses)
		combined.surfaces.append_array(part.surfaces)
	terrain.skin = combined
	fall.skin = terrain.skin


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)


func update_energy_pose() -> void:
	if not beginning_fall:
		if dead:
			fall.settle(self)
		else:
			terrain.settle_live()
	super.update_energy_pose()
	if beginning_fall or not is_finite(entry_phase):
		return
	var progress := clampf((animator.current_animation_position - fall.blend_start) / maxf(.001, fall.blend_length), 0., 1.)
	if progress >= 1.0:
		entry_phase = NAN
		return
	energy_phase = lerp_angle(entry_phase, energy_phase, smoothstep(0.0, 1.0, progress))
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material != null:
				material.set_shader_parameter("phase", energy_phase)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2", "RayDrift"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		fall.split = terrain.split
		fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else fall.floor_under(self))
		terrain.live_lift = 0.0
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.global_transform = source.model.global_transform
	dead = true
	contact.enabled = false
	var previous: RefCounted = source.fall if source.dead else source.terrain
	fall.split = previous.split
	beginning_fall = true
	var duration := fall.begin_from_display(self, source, previous, source.animator.assigned_animation, false)
	beginning_fall = false
	if not source.dead:
		fall.blend_length = minf(.16, duration)
		for bone in source.skeleton.get_bone_count():
			fall.blend_pose.append(source.skeleton.get_bone_pose(bone))
		entry_phase = source.energy_phase
	update_energy_pose()
	return duration


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self)
