# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/EfreetActionsVisual.gd"

const Props := preload("EfreetEnhancedProps.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Arrival := "EfreetLampArrival"
const PropGroups := {Arrival: 23, "EfreetCarpetBalance": 26, "EfreetCarpetSalute": 27, "EfreetCarpetWatch": 28}
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var growth := preload("res://Presentation/CreatureGrowthRecovery.gd").new()
var props: Node3D
var body_mesh: MeshInstance3D
var hover_lift := 0.0


func _ready() -> void:
	super._ready()
	body_mesh = model.find_child("Body", true, false) as MeshInstance3D
	fitted_fall.skin = skin
	props = Props.new()
	add_child(props)


func receive_action(request: Dictionary) -> bool:
	restore_hover()
	return super.receive_action(request)


func settle() -> void:
	restore_hover()
	if dead and not fitted_fall.plane.is_empty():
		clear_props()
		fitted_fall.settle(self)
		return
	super.settle()
	if props == null:
		return
	if dead:
		clear_props()
		return
	growth.apply(self, Arrival)
	var group := int(PropGroups.get(current_clip, 0))
	if group == 0:
		clear_props()
		return
	var phase := clampf(animator.current_animation_position / animator.current_animation_length, 0.0, 1.0)
	skeleton.force_update_all_bone_transforms()
	var bottom := Geometry.deformed_bounds(body_mesh, skeleton).position.y - global_position.y
	props.apply_phase(group, phase, bottom)
	var floor := fitted_fall.floor_under(self)
	var normal: Vector3 = floor.normal
	var gap := Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform, floor.position, normal)
	hover_lift = maxf(0.0, (.003 - gap) / normal.y)
	if props.carpet.visible:
		hover_lift = maxf(hover_lift, carpet_lift(floor.position, normal))
		props.carpet.global_position.y += hover_lift
	model.global_position.y += hover_lift
	if props.lamp.visible:
		var lamp_gap: float = (props.lamp.global_position - floor.position).dot(normal)
		var lamp_lift := maxf(0.0, (.063 - lamp_gap) / normal.y)
		props.lamp.global_position.y += lamp_lift
		for wisp: MeshInstance3D in props.wisps:
			if wisp.visible:
				wisp.global_position.y += lamp_lift


func carpet_lift(point: Vector3, normal: Vector3) -> float:
	var carpet: MeshInstance3D = props.carpet
	var gap := INF
	for x: float in [-.76, .76]:
		for z: float in [-.55, .55]:
			var corner := carpet.to_global(Vector3(x, -.026, z))
			gap = minf(gap, (corner - point).dot(normal))
	return maxf(0.0, (.003 - gap) / normal.y)


func restore_hover() -> void:
	if hover_lift > 0.0:
		model.global_position.y -= hover_lift
		hover_lift = 0.0


func clear_props() -> void:
	if props != null:
		props.apply_phase(0, 0.0, 0.0)


func begin_death_from(source: Node3D) -> float:
	if PropGroups.has(source.current_clip) or source.growth.active or not source.fitted_fall.plane.is_empty():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
