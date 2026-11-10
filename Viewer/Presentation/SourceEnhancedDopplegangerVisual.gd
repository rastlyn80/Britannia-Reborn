# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePreservingDistinctActionsVisual.gd"

const Rise := "DopplegangerFormRise"
const Emergence := preload("DopplegangerEmergence.gdshader")
var growth := preload("res://Presentation/CreatureGrowthRecovery.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_transform := Transform3D.IDENTITY
var fitted_support := false
var recovering_clip := ""
var veil: MeshInstance3D
var seal: MeshInstance3D


func _ready() -> void:
	super._ready()
	var body := model.find_child("Body", true, false) as MeshInstance3D
	fitted_fall.skin = Ground.skin_points(body, skeleton)
	veil = create_emergence_plane("DopplegangerVeil", Vector2(4.8, 4.1), false)
	seal = create_emergence_plane("DopplegangerSeal", Vector2(2.7, 2.7), true)


func create_emergence_plane(label: String, size: Vector2, ground_plane: bool) -> MeshInstance3D:
	var effect := MeshInstance3D.new()
	effect.name = label
	var quad := QuadMesh.new()
	quad.size = size
	effect.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = Emergence
	material.set_shader_parameter("ground_plane", ground_plane)
	effect.material_override = material
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.set_meta("source_death_flash", true)
	effect.hide()
	add_child(effect)
	return effect


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func is_recovering() -> bool:
	return not recovering_clip.is_empty() and current_clip == recovering_clip and action_remaining > 0.0


func receive_action(request: Dictionary) -> bool:
	var interrupted := growth.active and current_clip == Rise
	if not super.receive_action(request):
		return false
	restore_fitted()
	recovering_clip = current_clip if interrupted and current_clip != Rise else ""
	if is_fitted() or is_recovering():
		contact.enabled = false
	update_emergence()
	return true


func _physics_process(delta: float) -> void:
	if not is_fitted() and not is_recovering() and fitted_fall.plane.is_empty():
		super._physics_process(delta)


func support_control_plane() -> void:
	if not is_fitted() and not is_recovering() and fitted_fall.plane.is_empty():
		super.support_control_plane()


func restore_fitted() -> void:
	if fitted_support:
		model.transform = unposed_transform
		fitted_support = false


func settle_action() -> void:
	restore_fitted()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	else:
		var recovering := not dead and growth.apply(self, Rise)
		if not dead and (is_fitted() or recovering or is_recovering()):
			place_fitted()
		else:
			super.settle_action()
	update_emergence()
	update_landmarks()


func place_fitted() -> void:
	var plane := fitted_fall.floor_under(self)
	var normal: Vector3 = plane.normal
	unposed_transform = model.transform
	fitted_support = true
	var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (slope * source_model_basis).scaled_local(unposed_transform.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, plane.position, normal)
	model.global_position.y += (.003 - gap) / normal.y


func update_emergence() -> void:
	if veil == null or seal == null:
		return
	var showing := not dead and current_clip == Rise and animator.current_animation_length > 0.0
	veil.visible = showing
	seal.visible = showing
	if not showing:
		return
	var phase := animator.current_animation_position / animator.current_animation_length
	var support := fitted_fall.floor_under(self)
	var normal: Vector3 = support.normal
	seal.global_transform = Transform3D(Basis(Quaternion(Vector3.BACK, normal)), Vector3(support.position) + normal * .018)
	veil.global_position = Vector3(support.position) + normal * (1.18 + .28 * smoothstep(.24, .65, phase))
	for effect: MeshInstance3D in [veil, seal]:
		effect.material_override.set_shader_parameter("phase", phase)


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted() or source.growth.active or source.is_recovering():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)

