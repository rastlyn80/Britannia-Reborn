# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Breath := preload("res://Presentation/SkeletalDragonColdBreath.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Source := 0x4601
const Target := 0x4602
const RenownedHue := 906


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
	world.game._handle(mobile_packet(tile, Source, Breath.Body, 0))
	world.game._handle(mobile_packet(tile + Vector2i(3, 0), Target, 211, 0))
	world.game.phase = "world"
	var dragon: Node3D = world.avatars[Source].horse_visual
	var presenter: Node3D
	for child in world.get_children():
		if child is Effects:
			presenter = child
			break
	if not expect(presenter != null and dragon != null, "Skeletal Dragon and real effect presenter"):
		return
	dragon.set_process(false)
	dragon.set_physics_process(false)
	dragon.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	world.game._handle(gesture(12, 6))
	if not expect(dragon.current_clip != Breath.Clip and Breath.origin(dragon) == null, "Exact native windup signature"):
		return
	world.game._handle(gesture(12, 5))
	if not expect(dragon.current_clip == Breath.Clip and dragon.action_remaining >= 1.55, "Complete cold windup"):
		return
	dragon.animator.advance(0.0)
	world.game._handle(gesture(4, 5))
	world.game._handle(action_packet(Source, 0, 1))
	dragon.play_gait(true, 4.0)
	var rig: Skeleton3D = dragon.skeleton
	var floor := dragon.global_position
	var slope := Vector3(0.17, 1.0, -0.12).normalized()
	dragon.contact.contacts = {0: {"position": floor, "normal": slope}}
	var clearance := INF
	for frame in 78:
		dragon.animator.advance(1.0 / 60.0)
		dragon._process(1.0 / 60.0)
		if frame % 6 == 5:
			dragon.ground_gesture.support(dragon)
			clearance = minf(clearance, Ground.minimum_plane_gap(
				dragon.ground_gesture.skin, rig, rig.global_transform, floor, slope))
	if not expect(clearance >= 0.0019, "The cold breath keeps its skin above the slope %.5f" % clearance):
		return
	rig.force_update_all_bone_transforms()
	var upper := Breath.posed_point(rig, rig.find_bone(Breath.Head), Breath.UpperTip)
	var lower := Breath.posed_point(rig, rig.find_bone(Breath.Jaw), Breath.LowerTip)
	var muzzle: Variant = Breath.origin(dragon)
	if not expect(muzzle is Vector3 and upper.distance_to(lower) > 0.80, "Open jaw at native launch %s" %
			str([dragon.current_clip, dragon.animator.current_animation_position, dragon.action_remaining,
				dragon.animator.speed_scale, upper.distance_to(lower), muzzle])):
		return
	var before: int = presenter.get_child_count()
	world.game._handle(projectile(tile, Breath.Hue))
	var launch: MeshInstance3D = presenter.get_child(before) as MeshInstance3D
	if not expect(launch != null and launch.global_position.distance_to(muzzle) < 0.00001, "Muzzle anchored cold bolt"):
		return
	var light := launch.get_child(1) as OmniLight3D
	if not expect(light != null and light.light_color.is_equal_approx(Effects.colour({"graphic": 0x36d4, "hue": Breath.Hue})),
			"Native cold hue reaches the light"):
		return
	world.game._handle(projectile(tile, 0))
	var chest_launch: Node3D = presenter.get_child(before + 1)
	if not expect(chest_launch.global_position.distance_to(muzzle) > 0.10, "Other effects retain their launch path"):
		return
	dragon._process(dragon.action_remaining + 0.01)
	world.game._handle(gesture(5, 5))
	if not expect(dragon.current_clip == "Attack2" and Breath.origin(dragon) == null, "Native bite after recovery"):
		return
	world.game._handle(gesture(12, 5))
	world.game._handle(gesture(2, 5))
	if not expect(dragon.dead and dragon.current_clip == "Death" and Breath.origin(dragon) == null, "Death interrupts cold breath"):
		return
	var corpse := 0x40000000 + Source
	world.game._handle(corpse_packet(tile, corpse, Breath.Body, RenownedHue))
	world.game._handle(death_packet(Source, corpse))
	world.creature_deaths.finish(Source)
	await process_frame
	var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	if not expect(frozen != null and frozen.get_meta("corpse_body") == Breath.Body
			and frozen.get_meta("native_hue") == RenownedHue
			and frozen.find_children("*", "Skeleton3D", true, false).is_empty(), "Dyed skeletal dragon static corpse"):
		return
	world.game.phase = "offline"
	print("SKELETAL DRAGON WORLD: ", checks, " packet and pose checks, Enhanced ", world.enhanced_creature_actions)
	quit()


func gesture(group: int, frames: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(Source, 4))
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
