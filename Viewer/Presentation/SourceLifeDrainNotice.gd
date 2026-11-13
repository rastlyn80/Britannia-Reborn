# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Start := 1070848
const Refresh := 1070847
const End := 1070849
const Marker := "NativeLifeDrain"
const Duration := 5.5


static func present(presenter: Node3D, cliloc: int) -> void:
	var scene: Node3D = presenter.scene
	if scene.game.phase != "world" or cliloc not in [Start, Refresh, End]:
		return
	var avatar: Node3D = scene.avatars.get(int(scene.game.player.get("serial", 0)))
	if not is_instance_valid(avatar):
		return
	var current := avatar.get_node_or_null(Marker) as GPUParticles3D
	if cliloc == End:
		if current != null:
			clear(current)
		return
	if current == null:
		current = presenter.sparks(Color(.74, .23, .54), 34, .8, .29, .55)
		current.name = Marker
		current.position.y = 1.05
		avatar.add_child(current)
		var timer := Timer.new()
		timer.name = "DrainDuration"
		timer.one_shot = true
		current.add_child(timer)
		timer.timeout.connect(clear.bind(current))
	var expiry := current.get_node("DrainDuration") as Timer
	expiry.start(Duration)


static func clear(particles: GPUParticles3D) -> void:
	particles.get_parent().remove_child(particles)
	particles.queue_free()
