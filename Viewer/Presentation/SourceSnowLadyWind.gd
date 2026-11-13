# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Start := 1070832
const Refresh := 1070831
const End := 1070830
const Name := "SnowLadyFreezingWind"
const Duration := 5.0


class Wind extends GPUParticles3D:
	var remaining := Duration

	func _process(delta: float) -> void:
		remaining -= delta
		if remaining <= 0.0:
			queue_free()


static func present(presenter: Node3D, cliloc: int) -> void:
	var scene: Node3D = presenter.scene
	if scene.game.phase != "world" or cliloc not in [Start, Refresh, End]:
		return
	var target: Node3D = scene.avatars.get(int(scene.game.player.get("serial", 0)))
	if not is_instance_valid(target):
		return
	var current := target.get_node_or_null(Name) as Wind
	if cliloc == End:
		if current != null:
			current.queue_free()
		return
	if current != null and not current.is_queued_for_deletion():
		current.remaining = Duration
		return
	var wind := Wind.new()
	wind.name = Name
	var mist: GPUParticles3D = presenter.sparks(Color(.63, .86, 1.0), 34, .75, .38, .55)
	wind.amount = mist.amount
	wind.lifetime = mist.lifetime
	wind.process_material = mist.process_material
	wind.draw_pass_1 = mist.draw_pass_1
	mist.free()
	wind.position.y = 1.1
	target.add_child(wind)
