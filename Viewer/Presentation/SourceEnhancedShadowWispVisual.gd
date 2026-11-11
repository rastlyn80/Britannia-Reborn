# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ShadowWispVisual.gd"

const Hue := preload("res://Presentation/HumanHue.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const ActionSurface := preload("ShadowWispActionSurface.gdshader")
const Arc := "ShadowWispArc"
const Sparks := 42

var arc_sparks: MultiMeshInstance3D
var arc_material: StandardMaterial3D
var energy_root := -1
var energy_materials: Array[ShaderMaterial] = []
var previous_death_pose: Array[Transform3D] = []
var death_blend_duration := .12


func _ready() -> void:
	super._ready()
	energy_root = skeleton.find_bone("EnergyRoot")
	assert(energy_root >= 0)
	arc_material = Effects._glow(Color("#b69af1"), 2.4)
	var particle := QuadMesh.new()
	particle.size = Vector2(.084, .084)
	particle.material = arc_material
	var cluster := MultiMesh.new()
	cluster.transform_format = MultiMesh.TRANSFORM_3D
	cluster.use_colors = true
	cluster.mesh = particle
	cluster.instance_count = Sparks
	cluster.custom_aabb = AABB(Vector3(-1, -.5, -1), Vector3(2, 3.3, 4.0))
	arc_sparks = MultiMeshInstance3D.new()
	arc_sparks.multimesh = cluster
	arc_sparks.hide()
	add_child(arc_sparks)
	animator.mixer_applied.connect(blend_death_pose)


func set_hue(value: int) -> void:
	super.set_hue(value)
	energy_materials.clear()
	if is_instance_valid(model):
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_surface_override_material(surface) as ShaderMaterial
				if material != null:
					material.shader = ActionSurface
					energy_materials.append(material)
	if arc_material == null:
		return
	var palette := Hue.palette(value)
	var colour := palette.get_image().get_pixel(25, 0) if palette != null else Color("#b69af1")
	arc_material.albedo_color = colour
	arc_material.emission = colour


func play_gait(_moving: bool, _speed: float) -> void:
	# All three archive locomotion entries select the same hovering cycle.
	super.play_gait(false, 0.0)


func update_energy_pose() -> void:
	super.update_energy_pose()
	var phase := animator.current_animation_position / maxf(.001, animator.current_animation_length)
	var pulse := 0.0
	match current_clip:
		Arc:
			pulse = sin(PI * phase) ** 2.0
		"ShadowWispRecoil":
			pulse = .82 * sin(PI * phase) ** 2.0
		"ShadowWispKindle":
			pulse = smoothstep(.15, .83, phase) * (1.0 - smoothstep(.89, 1.0, phase))
	for material: ShaderMaterial in energy_materials:
		material.set_shader_parameter("action_gain", pulse)
	if not is_instance_valid(arc_sparks):
		return
	var active := not dead and current_clip == Arc and animator.assigned_animation == Arc
	arc_sparks.visible = active
	if not active:
		return
	var center := to_local(skeleton.to_global(skeleton.get_bone_global_pose(energy_root).origin))
	var build := smoothstep(.04, .36, phase)
	var release := smoothstep(.39, .78, phase)
	var detach := smoothstep(.73, 1.0, phase)
	var fade := smoothstep(.02, .18, phase) * (1.0 - detach)
	for index in Sparks:
		var fraction := float(index) / (Sparks - 1)
		var curl := -.40 * TAU + fraction * .77 * TAU
		var loop_point := Vector3(.44 * cos(curl), .43 * (1.0 + sin(curl)), .28 * fraction)
		var tail := Vector3(.20 * sin(PI * fraction), .36 * sin(PI * fraction) - .27 * fraction, 1.9 * fraction)
		var offset := loop_point.lerp(tail, release) * build
		offset.z += .45 * detach
		var flicker := .66 + .34 * sin(phase * 53.0 - float(index) * 1.65)
		var jitter := Vector3(sin(float(index) * 1.78), cos(float(index) * 2.33), 0.0) * .035 * flicker
		var size := (.60 + .65 * fraction) * (.45 + .55 * flicker)
		arc_sparks.multimesh.set_instance_transform(index,
			Transform3D(Basis.from_scale(Vector3.ONE * size), center + offset + jitter))
		arc_sparks.multimesh.set_instance_color(index, Color(1, 1, 1, fade * flicker))


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	previous_death_pose.clear()
	for joint in source.skeleton.get_bone_count():
		previous_death_pose.append(source.skeleton.get_bone_pose(joint))
	current_clip = "Death"
	dead = true
	contact.enabled = false
	var duration := animator.get_animation("Death").length
	death_blend_duration = minf(.12, duration)
	animator.speed_scale = 1.0
	animator.play("Death", 0.0)
	animator.advance(0.0)
	return duration


func blend_death_pose() -> void:
	if previous_death_pose.is_empty():
		return
	var weight := smoothstep(0.0, death_blend_duration, animator.current_animation_position)
	if weight >= 1.0:
		previous_death_pose.clear()
		return
	for joint in previous_death_pose.size():
		skeleton.set_bone_pose(joint, previous_death_pose[joint].interpolate_with(skeleton.get_bone_pose(joint), weight))
	skeleton.force_update_all_bone_transforms()


func corpse_snapshot_floor() -> float:
	skeleton.force_update_all_bone_transforms()
	var rig_to_actor := global_transform.affine_inverse() * skeleton.global_transform
	var bottom := INF
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree():
			var skin := Ground.skin_points(mesh, skeleton)
			bottom = minf(bottom, Ground.minimum_plane_gap(skin, skeleton, rig_to_actor, Vector3.ZERO, Vector3.UP))
	return bottom
