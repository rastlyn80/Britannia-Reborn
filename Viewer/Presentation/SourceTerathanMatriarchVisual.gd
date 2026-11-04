extends "res://Presentation/CreatureVisual.gd"

const Effects := preload("res://Presentation/EffectPresenter.gd")
const HANDS := ["cp_grasp_lhand", "cp_grasp_rhand"]
const HELD_CAST := "TerathanCast"
const OVERHEAD_CAST := "Cast2"
var held_motes: Array[GPUParticles3D] = []
var release_motes: Array[GPUParticles3D] = []
var arc: MeshInstance3D

func _ready() -> void:
	super._ready()
	for name: String in HANDS:
		var hand := BoneAttachment3D.new()
		hand.bone_name = name
		skeleton.add_child(hand)
		held_motes.append(add_motes(hand, Color("82e945"), 18, 0.24))
		release_motes.append(add_motes(hand, Color("fff2a0"), 12, 0.17))
	arc = create_arc()
	add_child(arc)
	arc.hide()

func add_motes(parent: Node3D, tint: Color, amount: int, lifetime: float) -> GPUParticles3D:
	var particles := Effects.sparks(tint, amount, lifetime, 0.10, 1.5)
	particles.emitting = false
	parent.add_child(particles)
	return particles

func create_arc() -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("fff7d0")
	material.emission_enabled = true
	material.emission = Color("ffce68")
	material.emission_energy_multiplier = 2.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for point: Vector3 in [Vector3.ZERO, Vector3(0.15, 0.08, 0.23), Vector3(-0.07, 0.13, 0.40),
			Vector3(0.14, -0.04, 0.58), Vector3(0, 0.02, 0.81)]:
		var width := lerpf(0.034, 0.004, point.z / 0.81)
		mesh.surface_add_vertex(point - Vector3.RIGHT * width)
		mesh.surface_add_vertex(point + Vector3.RIGHT * width)
	mesh.surface_end()
	var bolt := MeshInstance3D.new()
	bolt.mesh = mesh
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bolt

func _process(delta: float) -> void:
	super._process(delta)
	var phase := 0.0
	if action_remaining > 0.0 and not dead and animator.assigned_animation == current_clip:
		phase = animator.current_animation_position / maxf(0.001, animator.current_animation_length)
	var holding := current_clip == HELD_CAST and phase >= 0.20 and phase < 0.80
	var releasing := current_clip == OVERHEAD_CAST and phase >= 0.30 and phase < 0.75
	for particles in held_motes:
		particles.emitting = holding
	for particles in release_motes:
		particles.emitting = releasing
	arc.visible = releasing and phase >= 0.56 and phase < 0.75
	if arc.visible:
		var grip := skeleton.find_bone(HANDS[1])
		arc.position = to_local(skeleton.to_global(skeleton.get_bone_global_pose(grip).origin))
