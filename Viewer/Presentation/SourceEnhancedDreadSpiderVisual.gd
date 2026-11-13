# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/DreadSpiderActionsVisual.gd"

const SilkShader := preload("DreadSilkOpening.gdshader")
const ChitinShader := preload("DreadChitin.gdshader")
const Hue := preload("res://Presentation/HumanHue.gd")
const Emergence := "DreadSpiderSilkEmergence"
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var silk: MeshInstance3D
var silk_material: ShaderMaterial


func set_hue(value: int) -> void:
	if treatment != "modern" or model == null or not entry.has("enhanced_source_action_groups"):
		super.set_hue(value)
		return
	hue = value
	var body := model.find_child("Body", true, false) as MeshInstance3D
	var palette := Hue.palette(value)
	for surface in body.mesh.get_surface_count():
		var original := body.mesh.surface_get_material(surface) as StandardMaterial3D
		assert(original != null and original.albedo_texture != null)
		var material := ShaderMaterial.new()
		material.shader = ChitinShader
		material.set_shader_parameter("albedo_texture", original.albedo_texture)
		material.set_shader_parameter("hue_palette", palette)
		material.set_shader_parameter("use_hue", palette != null)
		material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
		body.set_surface_override_material(surface, material)


func _ready() -> void:
	super._ready()
	fitted_fall.skin = gesture_skin
	if not entry.has("enhanced_source_action_groups"):
		return
	silk = MeshInstance3D.new()
	silk.name = "DreadSilkOpening"
	var web := QuadMesh.new()
	web.size = Vector2(2.55, 1.48)
	silk.mesh = web
	silk_material = ShaderMaterial.new()
	silk_material.shader = SilkShader
	silk.material_override = silk_material
	silk.rotation.x = -.78
	silk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	silk.set_meta("source_death_flash", true)
	silk.hide()
	add_child(silk)
	animator.mixer_applied.connect(update_silk)
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func support_gesture() -> void:
	if not is_fitted():
		super.support_gesture()
		return
	restore_gesture_model()
	if dead:
		return
	var plane := fitted_fall.floor_under(self)
	gesture_model = model.transform
	gesture_adjusted = true
	var normal: Vector3 = plane.normal
	var local_normal := (global_basis.inverse() * normal).normalized()
	model.basis = Basis(Quaternion(Vector3.UP, local_normal)) * gesture_model.basis
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(gesture_skin, skeleton, skeleton.global_transform, plane.position, normal)
	model.global_position.y += (.003 - gap) / normal.y


func update_silk() -> void:
	silk.visible = not dead and current_clip == Emergence
	if silk.visible:
		var phase := animator.current_animation_position / animator.current_animation_length
		var opening := smoothstep(.09, .89, phase)
		silk.position = Vector3(0, .61 - .23 * opening, -.28 - .85 * opening)
		silk_material.set_shader_parameter("opening", opening)


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted():
		return super.begin_death_from(source)
	# The visible rig already matches the slope. Its basis must carry into the fall.
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
