extends "res://Presentation/SourceArmedLizardmanVisual.gd"

const Effects := preload("res://Presentation/EffectPresenter.gd")
const BONE := "ophidian mage staff"
var cast_sparks: GPUParticles3D
var release_sparks: GPUParticles3D

func _ready() -> void:
	super._ready()
	assert(skeleton.find_bone(BONE) >= 0)
	var socket := BoneAttachment3D.new()
	socket.bone_name = BONE
	skeleton.add_child(socket)
	cast_sparks = add_sparks(socket, Color("ff744d"), 16, 0.25, 0.13, 1.2)
	release_sparks = add_sparks(socket, Color("ffac6d"), 20, 0.16, 0.08, 2.2)

func add_sparks(socket: BoneAttachment3D, tint: Color, amount: int, lifetime: float,
		spread: float, speed: float) -> GPUParticles3D:
	var particles := Effects.sparks(tint, amount, lifetime, spread, speed)
	particles.position = Vector3(0, 0.67, 0)
	particles.emitting = false
	socket.add_child(particles)
	return particles

func _process(delta: float) -> void:
	super._process(delta)
	var phase := 0.0
	if action_remaining > 0.0 and not dead and animator.assigned_animation == current_clip:
		phase = animator.current_animation_position / maxf(0.001, animator.current_animation_length)
	cast_sparks.emitting = current_clip == "StaffCast" and phase >= 0.27 and phase < 0.73
	release_sparks.emitting = current_clip == "Cast2" and phase >= 0.37 and phase < 0.68
