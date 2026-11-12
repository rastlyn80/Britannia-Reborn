# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceLivingArmedLizardVisual.gd"

const TrollGround := preload("res://Presentation/SourceTrollGround.gd")
const Fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd")
const Props := ["Axe", "EnhancedAxe", "FrostClub"]
const KneeTurns := [-.12, .12, -.24, .24, -.42, .42, -.60, .60]
var prop: MeshInstance3D
var prop_skin: Dictionary
var body_skin: Array[Dictionary] = []
var left_leg: Array[Dictionary] = []
var right_leg: Array[Dictionary] = []
var fitted_fall := Fall.new()
var unarmed_fall := false


func _ready() -> void:
	super._ready()
	var surface: MeshInstance3D = contact.surface
	contact.free()
	contact = TrollGround.new()
	skeleton.add_child(contact)
	contact.include_toe_descendants = true
	contact.align_skinned_soles = true
	contact.iterations = 5
	contact.configure(surface, false)
	contact.support_appendages = correct_step_appendages
	contact.modification_processed.connect(support_living_pose)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		if str(mesh.name) in Props:
			prop = mesh
			prop_skin = Ground.skin_points(mesh, skeleton)
			prop.set_meta("optional_corpse_visual_prop", true)
		else:
			body_skin.append(Ground.skin_points(mesh, skeleton))
	assert(body_skin.size() == 1)
	left_leg.append(weighted_leg_vertices(body_skin[0], joints(["bip01 l thigh", "bip01 l calf"])))
	right_leg.append(weighted_leg_vertices(body_skin[0], joints(["bip01 r thigh", "bip01 r calf"])))
	fitted_fall.skin = body_skin[0]
	animator.mixer_applied.connect(update_displayed_prop)


func unarmed_gesture() -> bool:
	return native_body in [53, 55] and current_clip in entry.get("archive_grounded_gestures", [])


func weighted_leg_vertices(skin: Dictionary, joints_to_measure: Array[int]) -> Dictionary:
	var surfaces: Array[Dictionary] = []
	for surface: Dictionary in skin.surfaces:
		var points := PackedVector3Array()
		var bindings := PackedInt32Array()
		var weights := PackedFloat32Array()
		var stride: int = surface.stride
		for vertex: int in surface.points.size():
			var offset := vertex * stride
			var weight := 0.0
			for influence in stride:
				if skin.bones[surface.bindings[offset + influence]] in joints_to_measure:
					weight += surface.weights[offset + influence]
			if weight < .45:
				continue
			points.append(surface.points[vertex])
			for influence in stride:
				bindings.append(surface.bindings[offset + influence])
				weights.append(surface.weights[offset + influence])
		surfaces.append({"points": points, "bindings": bindings, "weights": weights, "stride": stride})
	return {"bones": skin.bones, "bind_poses": skin.bind_poses, "surfaces": surfaces}


func correct_step_appendages() -> void:
	super.correct_step_appendages()
	var floor_height: float = split_support.position.y
	for index in contact.feet.size():
		var leg_skin := left_leg if index == 0 else right_leg
		var conflict: Dictionary = contact.step_conflict(floor_height, step_query, leg_skin)
		if float(conflict.get("lift", 0.0)) > .018:
			clear_bent_leg(contact.feet[index], leg_skin, floor_height, conflict.lift)


func clear_bent_leg(foot: Dictionary, skins: Array[Dictionary], floor_height: float, lift: float) -> void:
	# Rotate the knee around the planted ankle and hip when a riser catches
	# the calf. Both joint positions and the ankle orientation are preserved.
	var hip := skeleton.get_bone_global_pose(foot.a)
	var knee := skeleton.get_bone_global_pose(foot.b)
	var ankle := skeleton.get_bone_global_pose(foot.c)
	var axis := (ankle.origin - hip.origin).normalized()
	var leg := knee.origin - hip.origin
	if axis.is_zero_approx() or leg.cross(axis).length_squared() < .000001:
		return
	var best := 0.0
	for angle: float in KneeTurns:
		set_knee_turn(foot, hip, knee, ankle, hip.origin + leg.rotated(axis, angle))
		var conflict: Dictionary = contact.step_conflict(floor_height, step_query, skins)
		var remaining := float(conflict.get("lift", 0.0))
		if remaining < lift - .001:
			lift = remaining
			best = angle
		if lift <= .006:
			break
	set_knee_turn(foot, hip, knee, ankle, hip.origin + leg.rotated(axis, best))


func set_knee_turn(foot: Dictionary, hip: Transform3D, knee: Transform3D, ankle: Transform3D, target: Vector3) -> void:
	skeleton.set_bone_global_pose(foot.a, hip)
	skeleton.set_bone_global_pose(foot.b, knee)
	skeleton.set_bone_global_pose(foot.c, ankle)
	contact.aim(foot.a, foot.b, target)
	contact.aim(foot.b, foot.c, ankle.origin)
	skeleton.set_bone_global_pose(foot.c, ankle)


func update_displayed_prop() -> void:
	if is_instance_valid(prop):
		prop.visible = not (unarmed_fall or unarmed_gesture())
		living_skin.assign(body_skin)
		weapon_skin.clear()
		if prop.visible:
			living_skin.append(prop_skin)
			weapon_skin.append(prop_skin)
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)


func _physics_process(delta: float) -> void:
	if fitted_fall.plane.is_empty():
		super._physics_process(delta)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip == "KnuckleCheck":
		action_remaining = 0.0
	super.play_gait(moving, speed)


func begin_death_from(source: Node3D) -> float:
	if not (source.unarmed_gesture() or source.unarmed_fall):
		return super.begin_death_from(source)
	unarmed_fall = true
	update_displayed_prop()
	var displayed := Fall.new()
	displayed.plane = source.support_plane if not source.support_plane.is_empty() else source.split_support
	displayed.shift = source.global_basis.inverse() * (Vector3.UP * source.living_lift)
	return fitted_fall.begin_from_source(self, source, displayed, false)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
