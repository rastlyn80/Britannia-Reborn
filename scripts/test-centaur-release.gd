# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const BowVisual := preload("res://Presentation/CentaurBowVisual.gd")
const BowRelease := preload("res://Presentation/CentaurBowRelease.gd")
const Effects := preload("res://Presentation/CreatureProjectilePresenter.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Decode := preload("res://Network/Packets/Effects.gd")
const Login := preload("res://Network/LoginProtocol.gd")

class Arena extends Node3D:
	var game := {"phase": "world"}
	var avatars := {}
	var world_items := {"nodes": {}}
	func entity_point(x: int, y: int, z: int) -> Vector3:
		return Vector3(x, z, y)

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func packet(graphic := 0x0f42, effect_kind := 0) -> Dictionary:
	var wire := PackedByteArray([0x70, effect_kind])
	wire.append_array(Login.uint_be(3, 4))
	wire.append_array(Login.uint_be(1, 4))
	wire.append_array(Login.uint_be(graphic, 2))
	wire.append_array(PackedByteArray([5,247,6,186,20,5,242,6,186,20,18,1,0,0,0,0]))
	return Decode.parse(wire)

func run() -> void:
	Registry.load_index()
	var cases := 0
	for gait: String in ["Idle", "Walk", "Run"]:
		for yaw: float in [-.65, 0.0, .65]:
			var arena := Arena.new()
			root.add_child(arena)
			var target := Node3D.new()
			arena.add_child(target)
			target.position = Vector3(0.0, .15, 6.0).rotated(Vector3.UP, yaw)
			arena.avatars[1] = target
			var actor := Avatar.new()
			actor.initial_body = 101
			arena.add_child(actor)
			actor.apply_server_appearance({"body": 101, "hue": 0}, [{"id": 0x13b2, "layer": 2, "hue": 0}])
			arena.avatars[3] = actor
			var archer := actor.horse_visual as BowVisual
			assert(archer != null and archer.bow != null)
			actor.set_process(false)
			actor.set_physics_process(false)
			archer.set_process(false)
			archer.set_physics_process(false)
			archer.contact.active = false
			archer.play(gait, 0.0)
			archer.animator.advance(0.0)
			var rig := archer.skeleton
			var presenter := Effects.new()
			presenter.scene = arena
			arena.add_child(presenter)
			var observed: Array[Vector3] = []
			var transform := archer.global_transform
			presenter.present(packet())
			var release := rig.get_node("NativeBowRelease") as BowRelease
			assert(release != null)
			release.modification_processed.connect(func():
				if release.elapsed >= .085 and release.elapsed < .145:
					assert(archer.bow.to_global(BowVisual.BOW_GRIP).distance_to(archer.left_palm()) < .001)
					assert(archer.bow.global_basis.z.dot(Vector3.UP) > .80)
					assert(archer.global_transform == transform and archer.animator.assigned_animation == gait)
					observed.append(release.arrow_rest()))
			await create_timer(.135).timeout
			var arrow := presenter.get_node_or_null("NativeCentaurArrow") as Node3D
			assert(arrow != null, str([gait, yaw, release.elapsed, presenter.get_child_count()]))
			assert(arrow.global_position.is_finite() and observed.size() > 1)
			var path := target.global_position + Vector3.UP * 1.2 - observed[0]
			assert(arrow.global_basis.z.dot(path.normalized()) < -.99)
			assert((arrow.global_position - observed[0]).cross(path.normalized()).length() < .10)
			await create_timer(.38).timeout
			assert(release.elapsed >= BowRelease.RECOVER_TIME and presenter.get_child_count() == 0)
			assert(archer.bow.visible and archer.animator.assigned_animation == gait)
			assert(archer.bow.to_global(BowVisual.BOW_GRIP).distance_to(archer.left_palm()) < .001)
			if gait == "Idle" and yaw == 0.0:
				await check_other_effects(arena, archer, presenter, release)
			cases += 1
			arena.queue_free()
			await process_frame
	print("CENTAUR RELEASE: ", cases, " decoded gait and direction cases; unrelated effects and interrupted release")
	quit()

func check_other_effects(arena: Arena, archer: BowVisual, presenter: Effects, release: BowRelease) -> void:
	var end := release.elapsed
	presenter.present(packet(0x0f42, 2))
	assert(release.elapsed == end and not presenter.has_node("NativeCentaurArrow"))
	presenter.present(packet(0x36d4))
	assert(release.elapsed == end and not presenter.has_node("NativeCentaurArrow"))
	var actor: Node3D = arena.avatars[3]
	arena.avatars.erase(3)
	presenter.present(packet())
	assert(release.elapsed == end and not presenter.has_node("NativeCentaurArrow"))
	arena.avatars[3] = actor
	archer.set_equipment([])
	presenter.present(packet())
	assert(release.elapsed == end and not archer.bow.visible and not presenter.has_node("NativeCentaurArrow"))
	archer.set_equipment([{"id": 0x13b2, "layer": 2, "hue": 0}])
	presenter.present(packet())
	assert(release.elapsed == 0.0)
	assert(archer.receive_action({"protocol": "classic", "action": 2}))
	await create_timer(.135).timeout
	assert(archer.dead and not archer.bow.visible and release.elapsed == end)
	assert(presenter.has_node("NativeCentaurArrow"), "A native shot survives an interrupted pose")
	await create_timer(1.65).timeout
	archer.dead = false
	archer.sync_bow()
	presenter.present(packet())
	arena.avatars.erase(3)
	actor.queue_free()
	await create_timer(.135).timeout
	assert(presenter.has_node("NativeCentaurArrow"), "A native shot survives source removal")
	await create_timer(.35).timeout
