# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedBovineVisual.gd"

const LivingGround := preload("res://Presentation/BovineLivingGround.gd")
var ground := LivingGround.new()


func _ready() -> void:
	super._ready()
	ground.bind(self)


func _physics_process(delta: float) -> void:
	ground.sample(delta)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2", "BovineGrazeTailFlick", Grazing]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func begin_death_from(source: Node3D) -> float:
	var clip: String = source.current_clip if source.dead else FittedFall
	if clip == "Death":
		select_classic_fall()
	return ground.begin_fall(source, clip)


func settle_collapse() -> void:
	if ground.transferring:
		ground.settle_transferred_fall()
		return
	super.settle_collapse()
	if current_clip == FittedFall:
		fitted_fall.shift = ground.settle_fall(fitted_fall.shift)
	else:
		collapse_shift = ground.settle_fall(collapse_shift)


func corpse_snapshot_floor() -> float:
	return ground.fall.snapshot_floor(self) if ground.transferring else super.corpse_snapshot_floor()
