# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/AlternateCollapseVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd")
const Fitted := ["HeadlessGatherRise", "HeadlessCrookedAlert"]
const Vertebrae := 13
var gesture_support := preload("res://Presentation/ArchiveGestureGround.gd").new()
var fitted_fall := Fall.new()
var chain: MultiMeshInstance3D
var neck_joint := -1
var hand_joint := -1

func _ready() -> void:
	super._ready()
	gesture_support.bind(self)
	neck_joint = skeleton.find_bone("bip01 neck")
	hand_joint = skeleton.find_bone("bip01 l hand")
	assert(neck_joint >= 0 and hand_joint >= 0)
	chain = make_vertebrae()
	model.add_child(chain)
	animator.mixer_applied.connect(update_chain)
	contact.modification_processed.connect(update_chain)
	animator.mixer_applied.connect(func(): fitted_fall.settle(self))

func _physics_process(delta: float) -> void:
	gesture_support.release(self)
	super._physics_process(delta)

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in Fitted:
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)

static func make_vertebrae() -> MultiMeshInstance3D:
	var bone := SphereMesh.new()
	bone.radial_segments = 8
	bone.rings = 4
	bone.radius = .035
	bone.height = .067
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.72, .68, .55)
	material.roughness = .86
	bone.material = material
	var links := MultiMesh.new()
	links.transform_format = MultiMesh.TRANSFORM_3D
	links.mesh = bone
	links.instance_count = Vertebrae
	var result := MultiMeshInstance3D.new()
	result.multimesh = links
	result.visible = false
	return result

func update_chain() -> void:
	var clip := animator.assigned_animation
	var phase := animator.current_animation_position / maxf(animator.current_animation_length, .001)
	chain.visible = not dead and clip in Fitted and (clip == Fitted[1] or phase > .07)
	if not chain.visible:
		return
	skeleton.force_update_all_bone_transforms()
	var neck := model.to_local(skeleton.to_global(skeleton.get_bone_global_pose(neck_joint).origin))
	var hand := model.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hand_joint).origin))
	var rise := smoothstep(.07, .27, phase) if clip == Fitted[0] else 1.0
	var curl := .34 * rise + .14 * sin(phase * TAU) if clip == Fitted[0] else .23
	var control := neck.lerp(hand, .42) + Vector3(.18 * rise, curl, -.14 * rise)
	for link in Vertebrae:
		var phase_along := float(link) / float(Vertebrae - 1)
		var from := neck.lerp(control, phase_along)
		var to := control.lerp(hand, phase_along)
		var point := from.lerp(to, phase_along)
		var direction := (to - from).normalized()
		var basis := Basis(Quaternion(Vector3.UP, direction))
		var thickness := lerpf(.7, 1.0, sin(PI * phase_along))
		chain.multimesh.set_instance_transform(link, Transform3D(basis.scaled_local(Vector3(thickness, 1, thickness)), point))
