# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Breath := preload("res://Presentation/LeviathanBreath.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Source := 0x4790
const Kraken := 0x4791
const Target := 0x4792


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	for child in world.get_children():
		if child.get_script() == preload("res://Network/MobileNames.gd"):
			child.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var tile := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var mobile := mobile_packet(tile, Source, Breath.Body, 0)
	var wire_hue := Wire.uint_be(Breath.BodyHue, 2)
	mobile[13] = wire_hue[0]
	mobile[14] = wire_hue[1]
	world.game._handle(mobile)
	world.game._handle(mobile_packet(tile, Kraken, Breath.Body, 0))
	world.game._handle(mobile_packet(tile + Vector2i(3, 0), Target, 211, 0))
	world.game.phase = "world"
	var leviathan: Node3D = world.avatars[Source].horse_visual
	var kraken: Node3D = world.avatars[Kraken].horse_visual
	var presenter: Node3D
	for child in world.get_children():
		if child is Effects:
			presenter = child
			break
	if not expect(presenter != null and leviathan.native_hue == Breath.BodyHue and kraken.native_hue == 0,
			"Living native Leviathan and shared-body Kraken"):
		return
	leviathan.set_process(false)
	leviathan.set_physics_process(false)
	leviathan.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	world.game._handle(gesture(Kraken, 12, 5))
	if not expect(kraken.current_clip == "Cast" and Breath.origin(kraken) == null, "Kraken retains its casting action"):
		return
	world.game._handle(gesture(Source, 12, 6))
	if not expect(leviathan.current_clip == "Cast", "Other Leviathan cast sizes stay generic"):
		return
	world.game._handle(gesture(Source, 12, 5))
	if not expect(leviathan.current_clip == Breath.Clip and not leviathan.dead and leviathan.action_remaining > 1.55,
			"Native Leviathan breath windup"):
		return
	leviathan.animator.advance(0.0)
	world.game._handle(gesture(Source, 5, 5))
	world.game._handle(action_packet(Source, 0, 1))
	leviathan.play_gait(true, 4.0)
	for frame in 78:
		leviathan.animator.advance(1.0 / 60.0)
		leviathan._process(1.0 / 60.0)
	var muzzle: Variant = Breath.origin(leviathan)
	var before: int = presenter.get_child_count()
	world.game._handle(projectile(tile, Breath.ProjectileHue))
	var launch := presenter.get_child(before) as Node3D
	if not expect(muzzle is Vector3 and launch != null and launch.global_position.distance_to(muzzle) < 0.00001,
			"Native effect launches from the animated Leviathan"):
		return
	var light := launch.get_child(1) as OmniLight3D
	if not expect(light != null and light.light_color.is_equal_approx(Effects.colour({"graphic": 0x36d4, "hue": Breath.ProjectileHue})),
			"Water projectile keeps its native effect hue"):
		return
	world.game._handle(gesture(Source, 2, 5))
	if not expect(leviathan.dead and Breath.origin(leviathan) == null, "Native fall interrupts the breath"):
		return
	var corpse := 0x40000000 + Source
	world.game._handle(corpse_packet(tile, corpse, Breath.Body, Breath.BodyHue))
	world.game._handle(death_packet(Source, corpse))
	world.creature_deaths.finish(Source)
	var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	if not expect(frozen != null and frozen.get_meta("corpse_body") == Breath.Body and frozen.get_meta("native_hue") == Breath.BodyHue
			and frozen.find_children("*", "Skeleton3D", true, false).is_empty(), "Static Leviathan corpse with native hue"):
		return
	world.game.phase = "offline"
	print("LEVIATHAN BREATH WORLD: ", checks, " decoded checks, Enhanced ", world.enhanced_creature_actions)
	quit()


func gesture(serial: int, group: int, frames: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, group, 0, frames, 0, 1, 0, 0, 0]))
	return packet


func projectile(tile: Vector2i, hue: int) -> PackedByteArray:
	var packet := PackedByteArray([0xc0, 0])
	packet.append_array(Wire.uint_be(Source, 4))
	packet.append_array(Wire.uint_be(Target, 4))
	packet.append_array(Wire.uint_be(0x36d4, 2))
	packet.append_array(Wire.uint_be(tile.x, 2))
	packet.append_array(Wire.uint_be(tile.y, 2))
	packet.append(0)
	packet.append_array(Wire.uint_be(tile.x + 3, 2))
	packet.append_array(Wire.uint_be(tile.y, 2))
	packet.append_array(PackedByteArray([0, 5, 0, 0, 0, 0, 0]))
	packet.append_array(Wire.uint_be(hue, 4))
	packet.append_array(Wire.uint_be(0, 4))
	return packet
