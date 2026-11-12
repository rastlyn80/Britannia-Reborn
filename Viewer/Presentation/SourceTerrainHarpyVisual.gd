# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedHarpyVisual.gd"

const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Wings := preload("res://Presentation/SourceWingSlopeClearance.gd")
const Footing := preload("res://Presentation/SourceHarpyStepContact.gd")
const IdleClips := ["Idle", "Fidget", "FeatherFlick", "HarpyFoldedGlance"]
const WingClips := ["Wingbeat", "WingRush", "Fly", "Land", "RaisedWingKick", "Attack", "WideWingRecoil",
	"HarpyDoubleWingbeat", "HarpyGlideSettle", "HarpyBank"]
var terrain := Terrain.new()
var wings := Wings.new()
var moving_for_gait := false


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.25, 1.7))
	var mesh: MeshInstance3D = contact.surface
	contact.free()
	contact = Footing.new()
	skeleton.add_child(contact)
	contact.bind_harpy(self, mesh)
	skeleton.add_child(wings)
	wings.active = false
	wings.bind(terrain.skin)
	contact.modification_processed.connect(terrain.settle_live)
	contact.modification_processed.connect(contact.remember_display)


func play_gait(moving: bool, speed: float) -> void:
	moving_for_gait = moving
	if moving and not dead and current_clip in IdleClips:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not dead and moving_for_gait and request.get("protocol") == "classic" and request.get("action") in [1, 17, 18]:
		return true
	var accepted := super.receive_action(request)
	if accepted and dead:
		contact.prepare_death()
	return accepted


func _physics_process(_delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	contact.sample(get_world_3d().direct_space_state, global_position)
	if terrain.plane.is_empty():
		contact.contacts.clear()
	terrain.split = terrain.split or contact.use_local_planes


func settle_collapse() -> void:
	if dead:
		contact.death.settle(self)
		return
	terrain.release_live()
	if not terrain.plane.is_empty() and animator.assigned_animation in WingClips:
		if terrain.split:
			wings.clear_treads(float(terrain.plane.position.y))
		elif float(terrain.plane.normal.y) < .998:
			wings.clear_slope(terrain.plane)


func begin_death_from(source: Node3D) -> float:
	var airborne: bool = source.current_clip in AIRBORNE
	if source.current_clip in Loft:
		var pelvis: int = source.skeleton.find_bone("bip01 pelvis")
		var hip: Vector3 = source.skeleton.to_global(source.skeleton.get_bone_global_pose(pelvis).origin)
		airborne = (hip - source.global_position).dot(source.global_basis.y.normalized()) > 1.26
	return contact.death.enter(self, source, airborne)


func corpse_snapshot_floor() -> float:
	return contact.death.snapshot_floor(self)
