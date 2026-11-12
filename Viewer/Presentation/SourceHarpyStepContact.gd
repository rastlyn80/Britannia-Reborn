# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePorcineStepGround.gd"


func bind_harpy(actor: Node3D, mesh: MeshInstance3D) -> void:
	visual = actor
	include_toe_descendants = true
	align_skinned_soles = true
	configure(mesh, false)
	assert(feet.size() == 2)
	surfaces[mesh] = actor.terrain.skin


func _process_modification_with_delta(delta: float) -> void:
	if enabled and use_local_planes and visual.current_clip not in ["Walk", "Run"]:
		prepare_hooves_for_tread()
	super._process_modification_with_delta(delta)
