# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/LichActionsVisual.gd"

var gesture_ground := preload("res://Presentation/ArchiveGestureGround.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var staff_entry := Transform3D.IDENTITY
var staff_entry_length := 0.0
var rise_ribbon: MeshInstance3D
var ribbon_material: StandardMaterial3D
var pelvis := -1
static var ribbon_mesh: ArrayMesh

func _ready() -> void:
	super._ready()
	gesture_ground.bind(self)
	pelvis = skeleton.find_bone("bip01 pelvis")
	rise_ribbon = MeshInstance3D.new()
	rise_ribbon.name = "LichRiseRibbon"
	rise_ribbon.set_meta("source_death_flash", true)
	if ribbon_mesh == null:
		ribbon_mesh = make_ribbon()
	rise_ribbon.mesh = ribbon_mesh
	rise_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon_material = StandardMaterial3D.new()
	ribbon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ribbon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon_material.vertex_color_use_as_albedo = true
	rise_ribbon.material_override = ribbon_material
	rise_ribbon.visible = false
	add_child(rise_ribbon)
	contact.modification_processed.connect(update_fitted_grip)
	contact.modification_processed.connect(update_ribbon)
	animator.mixer_applied.connect(update_ribbon)
	animator.mixer_applied.connect(settle_fitted_fall)

func _physics_process(delta: float) -> void:
	gesture_ground.release(self)
	super._physics_process(delta)

func update_fitted_grip() -> void:
	if not dead and staff != null and current_clip in entry.get("archive_grounded_gestures", []):
		update_grip()

static func make_ribbon() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in 2:
		for segment in 28:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var step := float(segment + corner.x) / 28.0
				var taper := sin(PI * step)
				var angle := TAU * (step * .81 + band * .50)
				var radius := .52 + .12 * taper
				mesh.set_color(Color(1.0, .65, .30, .72 * taper))
				mesh.add_vertex(Vector3(cos(angle) * radius, .68 * step - .36 + float(corner.y) * .14 * taper,
					sin(angle) * radius))
	return mesh.commit()

func update_ribbon() -> void:
	var phase := animator.current_animation_position / maxf(animator.current_animation_length, .001)
	rise_ribbon.visible = not dead and animator.assigned_animation == "LichCoilingRise" and phase > .09 and phase < .66
	if not rise_ribbon.visible:
		return
	rise_ribbon.position = to_local(skeleton.to_global(skeleton.get_bone_global_pose(pelvis).origin))
	rise_ribbon.position.y += .34 * smoothstep(.22, .52, phase)
	rise_ribbon.rotation.y = 4.5 * phase
	rise_ribbon.scale = Vector3.ONE * lerpf(.30, 1.20, smoothstep(.10, .54, phase))
	var strength := smoothstep(.09, .25, phase) * (1.0 - smoothstep(.44, .66, phase))
	ribbon_material.albedo_color = Color(1.0, 1.0, 1.0, strength)

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		return super.begin_death_from(source)
	if staff != null and source.staff != null:
		staff_entry = source.staff.global_transform
		staff_entry_length = minf(.16, animator.get_animation("Death").length)
	var duration := fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	collapse_skin = fitted_fall.skin
	settle_fitted_fall()
	return duration

func support_normal() -> Vector3:
	return fitted_fall.plane.normal if not fitted_fall.plane.is_empty() else super.support_normal()

func settle_fitted_fall() -> void:
	if fitted_fall.plane.is_empty():
		return
	fitted_fall.settle(self)
	if staff == null:
		return
	update_grip()
	var elapsed := animator.current_animation_position
	if staff_entry_length > 0.0 and elapsed < staff_entry_length:
		staff.global_transform = staff_entry.interpolate_with(staff.global_transform,
			smoothstep(0.0, staff_entry_length, elapsed))
	var normal: Vector3 = fitted_fall.plane.normal
	var floor_gap := staff_gap(staff.global_transform, normal)
	floor_gap += (model.global_position - fitted_fall.plane.position).dot(normal)
	if floor_gap < .003 and elapsed > .001:
		staff.global_position += normal * (.003 - floor_gap)
	update_landmarks()
