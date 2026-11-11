# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceBeetleRestVisual.gd"

const GiantBeetleMount := 0x3ebc
const MountedGaits := ["BeetleMountedIdle", "BeetleMountedWalk", "BeetleMountedRun"]
const PeaceGaits := ["Idle", "BeetleQuietWalk", "Run"]
const CombatGaits := ["BeetleWingedIdle", "BeetleWingedWalk", "Run"]
const Raise := "BeetleRaiseWings"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var combat_flags := -1
var alternate_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var body := meshes[0] as MeshInstance3D
	alternate_fall.skin = Ground.skin_points(body, skeleton).duplicate()
	alternate_fall.skin.surfaces = alternate_fall.skin.surfaces.duplicate()
	for label: String in ["UnderCarapace", "HindwingMembranes"]:
		var mesh := model.find_child(label, true, false) as MeshInstance3D
		assert(mesh.skin == body.skin and mesh.transform == body.transform)
		alternate_fall.skin.surfaces.append_array(Ground.skin_points(mesh, skeleton).surfaces)
	animator.mixer_applied.connect(settle_alternate_fall)


func apply_identity(body: int, value: int, item: int = 0) -> void:
	super.apply_identity(body, value, item)
	reins.visible = item == GiantBeetleMount and not dead


func set_native_combat_flags(flags: int) -> void:
	var entering := combat_flags >= 0 and (combat_flags & 0x40) == 0 and (flags & 0x40) != 0
	combat_flags = flags
	if entering and native_mount_item != GiantBeetleMount and not dead and action_remaining <= 0.0 and current_clip == "Idle":
		current_clip = Raise
		animator.speed_scale = 1.0
		action_remaining = animator.get_animation(Raise).length
		play(Raise, .10)


func play_gait(moving: bool, speed: float) -> void:
	var mounted := native_mount_item == GiantBeetleMount
	if not mounted and combat_flags < 0:
		super.play_gait(moving, speed)
		return
	if moving and current_clip == "LieDown":
		action_remaining = 0.0
	if dead or action_remaining > 0.0 or not moving and current_clip == "LieDown":
		return
	var locomotion: Dictionary = entry.get("locomotion", {})
	var running := moving and speed > float(locomotion.get("run_threshold_mps", 3.6))
	var gaits := MountedGaits if mounted else CombatGaits if (combat_flags & 0x40) != 0 else PeaceGaits
	var clip: String = gaits[2 if running else 1 if moving else 0]
	contact.enabled = true
	if current_clip != clip:
		current_clip = clip
		play(clip, .18)
	var reference := float(locomotion.get("run_reference_mps", 5.5)) if running else float(locomotion.get("walk_reference_mps", 1.8))
	animator.speed_scale = clampf(speed / maxf(.01, reference), float(locomotion.get("rate_min", .65)),
		float(locomotion.get("rate_max", 1.65))) if moving else 1.0


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		reins.hide()
		alternate_fall.accept_action(self)
	return true


func settle_alternate_fall() -> void:
	if current_clip in ["Death", "Death2"] and not pose_entry.active:
		alternate_fall.settle(self)


func begin_death_from(source: Node3D) -> float:
	reins.hide()
	if source.dead and source.current_clip in ["Death", "Death2"]:
		dead = true
		contact.enabled = false
		return alternate_fall.begin_from_source(self, source, source.alternate_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	return alternate_fall.snapshot_floor(self) if not alternate_fall.plane.is_empty() else INF
