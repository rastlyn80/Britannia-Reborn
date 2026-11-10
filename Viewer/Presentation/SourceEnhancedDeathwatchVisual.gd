# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/DeathwatchActionsVisual.gd"

class BeetleGestureGround extends "res://Presentation/ArchiveGestureGround.gd":
	func support(actor: Node3D) -> void:
		super.support(actor)
		if actor.dead or actor.current_clip not in actor.entry.get("archive_grounded_gestures", []):
			return
		# The two stance contacts can land on different facets. Also clear
		# the centre plane that will support an interrupted fall.
		var hit: Dictionary = actor.fitted_fall.floor_under(actor)
		var gap := Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform,
			hit.position, hit.normal)
		if gap >= .002:
			return
		if not applied:
			restore_pose = actor.model.transform
			applied = true
		actor.model.global_position.y += (.002 - gap) / float(hit.normal.y)

var gesture_ground := BeetleGestureGround.new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	gesture_ground.bind(self)
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))

func _physics_process(delta: float) -> void:
	gesture_ground.release(self)
	super._physics_process(delta)

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in entry.get("archive_grounded_gestures", []):
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
