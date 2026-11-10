# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const AuraShader := preload("PixieEmergence.gdshader")
const Rise := "PixieLightRise"
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var hover_shift := Vector3.ZERO
var aura: MeshInstance3D
var aura_material: ShaderMaterial
var aura_joint := -1


func _ready() -> void:
	super._ready()
	fitted_fall.skin = Ground.skin_points(model.find_child("Body", true, false), skeleton)
	aura_joint = skeleton.find_bone("bip01 spine1")
	aura_material = ShaderMaterial.new()
	aura_material.shader = AuraShader
	aura = MeshInstance3D.new()
	aura.name = "PixieEmergence"
	aura.mesh = QuadMesh.new()
	aura.material_override = aura_material
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.extra_cull_margin = 3.0
	aura.hide()
	add_child(aura)
	animator.mixer_applied.connect(update_fitted_pose)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if is_fitted():
		contact.enabled = false
	return true


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func update_fitted_pose() -> void:
	model.position -= hover_shift
	hover_shift = Vector3.ZERO
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	elif not dead and is_fitted():
		var floor := fitted_fall.floor_under(self)
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
		if gap < .003:
			var before := model.position
			model.global_position.y += (.003 - gap) / float(floor.normal.y)
			hover_shift = model.position - before
	aura.visible = not dead and current_clip == Rise
	if aura.visible:
		var phase := animator.current_animation_position / animator.current_animation_length
		var bloom := smoothstep(.06, .47, phase)
		aura.global_position = skeleton.to_global(skeleton.get_bone_global_pose(aura_joint).origin)
		aura_material.set_shader_parameter("diameter", lerpf(.16, 2.75, bloom))
		aura_material.set_shader_parameter("strength", .67 * bloom * (1.0 - smoothstep(.53, .94, phase)))


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted():
		play("Death", .08)
		return animator.get_animation("Death").length
	model.position -= source.hover_shift
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, true)


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
