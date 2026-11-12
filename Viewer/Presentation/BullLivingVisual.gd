# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BovineActionsVisual.gd"

const LivingGround := preload("res://Presentation/BovineLivingGround.gd")
var ground := LivingGround.new()


func _ready() -> void:
	super._ready()
	ground.bind(self)


func _physics_process(delta: float) -> void:
	ground.sample(delta)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func begin_death_from(source: Node3D) -> float:
	return ground.begin_fall(source, source.current_clip if source.dead else "Death")


func settle_collapse() -> void:
	if ground.transferring:
		ground.settle_transferred_fall()
		return
	super.settle_collapse()
	collapse_shift = ground.settle_fall(collapse_shift)


func corpse_snapshot_floor() -> float:
	return ground.fall.snapshot_floor(self) if ground.transferring else super.corpse_snapshot_floor()
