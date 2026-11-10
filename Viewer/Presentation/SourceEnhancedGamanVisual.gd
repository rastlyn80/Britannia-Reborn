# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var fitted_entry := false

func begin_death_from(source: Node3D) -> float:
	fitted_entry = source.current_clip in entry.get("archive_grounded_gestures", [])
	if fitted_entry:
		global_transform = source.global_transform
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	if not fitted_entry:
		return NAN
	skeleton.force_update_all_bone_transforms()
	var relative := global_transform.affine_inverse() * skeleton.global_transform
	return Ground.minimum_plane_gap(pose_entry.skin, skeleton, relative, Vector3.ZERO, Vector3.UP)
