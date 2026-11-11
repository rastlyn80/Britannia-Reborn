# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveOccurrenceGestureVisual.gd"

const CombatRest := "OniCombatRest"
const QuietRest := "OniQuietRest"
const PeaceWalk := "OniPeaceWalk"
const Fire := "OniFlameCast"
const Ready := "OniLowReady"
static var coil_mesh: ArrayMesh
var flags := -1
var hand_bone := -1
var fingers := -1
var flame: Node3D
var flame_materials: Array[StandardMaterial3D] = []
var fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	hand_bone = skeleton.find_bone("bip01 r hand")
	fingers = skeleton.find_bone("bip01 r finger0")
	assert(hand_bone >= 0 and fingers >= 0)
	animator.mixer_applied.connect(sync_pose)


func set_native_combat_flags(value: int) -> void:
	var entering := flags >= 0 and (flags & 64) == 0 and (value & 64) != 0
	flags = value
	if not entering or dead or action_remaining > 0.0:
		return
	current_clip = Ready
	contact.enabled = true
	animator.speed_scale = 1.0
	action_remaining = animator.get_animation(Ready).length
	play(Ready, .12)


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0:
		return
	var locomotion: Dictionary = entry.get("locomotion", {})
	var combat := (flags & 64) != 0
	if flags < 0 or moving and (combat or speed > float(locomotion.get("run_threshold_mps", 3.6))):
		super.play_gait(moving, speed)
		return
	var clip := PeaceWalk if moving else CombatRest if combat else QuietRest
	contact.enabled = true
	if current_clip != clip:
		current_clip = clip
		play(clip, .18)
	var reference := maxf(.01, float(locomotion.get("walk_reference_mps", 1.8)))
	animator.speed_scale = clampf(speed / reference, float(locomotion.get("rate_min", .65)),
		float(locomotion.get("rate_max", 1.65))) if moving else 1.0


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip in ["Death", "Death2"]:
		fall.accept_action(self)
	else:
		fall.plane.clear()
	if flame != null and current_clip != Fire:
		flame.hide()
	return true


func begin_death_from(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	return fall.begin_from_source(self, source, source.fall, false)


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else INF


func sync_pose() -> void:
	if current_clip in ["Death", "Death2"]:
		fall.settle(self)
	sync_flame()


func sync_flame() -> void:
	var progress := 0.0
	if not dead and current_clip == Fire and animator.assigned_animation == Fire:
		progress = animator.current_animation_position / maxf(.01, animator.current_animation_length)
	var visible_fire := progress >= .34 and progress <= .82
	if not visible_fire:
		if flame != null:
			flame.hide()
		return
	if flame == null:
		build_flame()
	skeleton.force_update_all_bone_transforms()
	var wrist := skeleton.to_global(skeleton.get_bone_global_pose(hand_bone).origin)
	var palm := skeleton.to_global(skeleton.get_bone_global_pose(fingers).origin)
	var tip := (palm - wrist).normalized() * .12
	var heading := global_basis.orthonormalized().rotated(global_basis.x.normalized(), .10)
	var pulse := smoothstep(.34, .47, progress) * (1.0 - smoothstep(.68, .82, progress))
	var spin := Basis(Vector3.BACK, (progress - .34) * TAU * .70)
	var width := .35 + .27 * pulse
	var length := 1.15 + 2.15 * pulse
	flame.global_transform = Transform3D((heading * spin).scaled_local(Vector3(width, width, length)), wrist + tip)
	for material: StandardMaterial3D in flame_materials:
		material.emission_energy_multiplier = 1.3 + 2.9 * pulse
	flame.show()


func build_flame() -> void:
	if coil_mesh == null:
		coil_mesh = make_coil()
	flame = Node3D.new()
	flame.name = "OniCastFlame"
	add_child(flame)
	for index in 2:
		var coil := MeshInstance3D.new()
		coil.name = "InnerCoil" if index else "OuterCoil"
		coil.mesh = coil_mesh
		coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		coil.rotation.z = PI * index
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("#ffcf62") if index else Color("#f17a20")
		material.emission_enabled = true
		material.emission = material.albedo_color
		coil.material_override = material
		flame_materials.append(material)
		flame.add_child(coil)


static func make_coil() -> ArrayMesh:
	var tube := SurfaceTool.new()
	tube.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 54:
		for side in 5:
			var a := coil_point(float(segment) / 54.0, TAU * side / 5.0)
			var b := coil_point(float(segment) / 54.0, TAU * (side + 1) / 5.0)
			var c := coil_point(float(segment + 1) / 54.0, TAU * side / 5.0)
			var d := coil_point(float(segment + 1) / 54.0, TAU * (side + 1) / 5.0)
			for point: Vector3 in [a, c, b, b, c, d]:
				tube.add_vertex(point)
	tube.generate_normals()
	return tube.commit()


static func coil_point(phase: float, section: float) -> Vector3:
	var angle := phase * TAU * 3.35
	var radius := sin(PI * phase) * (1.0 - phase) * .89
	var direction := Vector3(cos(angle), sin(angle), 0)
	var center := direction * radius + Vector3.BACK * phase
	var thickness := .082 * (1.0 - phase) + .009
	return center + (direction * cos(section) + Vector3.BACK * sin(section)) * thickness
