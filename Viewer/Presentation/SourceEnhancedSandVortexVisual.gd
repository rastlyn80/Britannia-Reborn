# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/WispVisual.gd"

const Sand := preload("SandVortexCarrier.gdshader")
const Hues := preload("res://Presentation/HumanHue.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Rise := "SandVortexDustRise"
const Quiet := "SandVortexQuietSpiral"
var fall := preload("res://Presentation/DisplayedCreatureFallPlayback.gd").new()
var unposed := Transform3D.IDENTITY
var supported := false
var forming := false
var last_scale := Vector3.ONE
var native_flags := 0


func _ready() -> void:
	super._ready()
	fall.skin = Ground.skin_points(model.find_child("CloudBody", true, false), skeleton)
	animator.get_animation(Quiet).loop_mode = Animation.LOOP_LINEAR


func set_native_combat_flags(value: int) -> void:
	native_flags = value


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0 or moving or (native_flags & 0x40) != 0:
		super.play_gait(moving, speed)
		return
	if current_clip != Quiet:
		current_clip = Quiet
		play(Quiet, .16)
		animator.speed_scale = 1.0


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_support()
	fall.accept_action(self)
	if is_fitted():
		contact.enabled = false
	return true


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func restore_support() -> void:
	if supported:
		model.transform = unposed
		supported = false


func _physics_process(delta: float) -> void:
	if is_fitted() or forming:
		update_energy_pose()
	elif fall.plane.is_empty():
		super._physics_process(delta)


func set_hue(value: int) -> void:
	hue = value
	if model == null:
		return
	var palette := Hues.palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as ShaderMaterial
			if material == null or material.shader != Sand:
				material = ShaderMaterial.new()
				material.shader = Sand
				material.set_meta("snapshot_uniform_time", true)
				material.set_shader_parameter("dust", mesh.name == "Dust")
				mesh.set_surface_override_material(surface, material)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
			material.set_shader_parameter("phase", energy_phase)


func update_energy_pose() -> void:
	restore_support()
	var duration := maxf(.001, animator.current_animation_length)
	var fraction := animator.current_animation_position / duration
	if not fall.plane.is_empty():
		fall.settle(self)
	elif not dead and not fall.skin.is_empty():
		var root_joint := skeleton.find_bone("root")
		if current_clip == Rise:
			forming = true
			last_scale = skeleton.get_bone_pose_scale(root_joint)
		elif forming:
			var blend := smoothstep(0.0, .22, animator.current_animation_position / maxf(.001, absf(animator.get_playing_speed())))
			skeleton.set_bone_pose_scale(root_joint, last_scale.lerp(Vector3.ONE, blend))
			skeleton.force_update_all_bone_transforms()
			forming = blend < 1.0
		if is_fitted() or forming:
			var plane := fall.floor_under(self)
			var normal: Vector3 = plane.normal
			unposed = model.transform
			supported = true
			var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
			model.basis = (slope * source_model_basis).scaled_local(unposed.basis.get_scale())
			var gap := Ground.minimum_plane_gap(fall.skin, skeleton, skeleton.global_transform, plane.position, normal)
			model.global_position.y += (.003 - gap) / normal.y
	super.update_energy_pose()
	var embodiment := smoothstep(.08, .51, fraction) if current_clip == Rise else 1.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Dust" and not dead:
			mesh.show()
		var material := mesh.get_active_material(0) as ShaderMaterial
		if material != null:
			material.set_shader_parameter("embodiment", embodiment)
	var head := skeleton.find_bone("Head")
	if head >= 0:
		set_meta("nameplate_height", to_local(skeleton.to_global(skeleton.get_bone_global_pose(head).origin)).y + .24)


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	var duration := fall.begin_from_display(self, source, source.fall, source.current_clip, false)
	if not source.dead and duration > 0.0:
		fall.blend_length = minf(.16, duration)
		for bone in source.skeleton.get_bone_count():
			fall.blend_pose.append(source.skeleton.get_bone_pose(bone))
		fall.settle(self)
	return duration


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self)
