# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceHeldPropsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var gesture_skin := {"bones": PackedInt32Array(), "bind_poses": [], "surfaces": []}
var gesture_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		var skin := Ground.skin_points(mesh, skeleton)
		var offset: int = gesture_skin.bones.size()
		gesture_skin.bones.append_array(skin.bones)
		gesture_skin.bind_poses.append_array(skin.bind_poses)
		for surface: Dictionary in skin.surfaces:
			var local := surface.duplicate()
			var bindings: PackedInt32Array = surface.bindings.duplicate()
			for index in bindings.size():
				bindings[index] += offset
			local.bindings = bindings
			gesture_skin.surfaces.append(local)
	assert(not gesture_skin.surfaces.is_empty())
	animator.mixer_applied.connect(release_gesture)
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))
	contact.modification_processed.connect(support_gesture)

func _physics_process(delta: float) -> void:
	release_gesture()
	super._physics_process(delta)

func release_gesture() -> void:
	model.position -= gesture_shift
	gesture_shift = Vector3.ZERO

func support_gesture() -> void:
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		return
	release_gesture()
	var plane := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(gesture_skin, skeleton, skeleton.global_transform, plane.position, plane.normal)
	if gap >= .002:
		return
	var before := model.position
	model.global_position.y += (.002 - gap) / float(plane.normal.y)
	gesture_shift = model.position - before

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		return super.begin_death_from(source)
	fitted_fall.skin = gesture_skin
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)

func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
