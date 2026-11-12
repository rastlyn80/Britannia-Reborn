# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-rabbit-gazer-seahorse-terrain.gd"

const Gear := [{"id": 0x1f03}, {"id": 0x170b}, {"id": 0x3eb3, "layer": 25, "hue": 0x8035}]


func run() -> void:
	assert(preload("res://Presentation/SeaHorseProfile.gd").enable())
	var lower := floor_box()
	var upper := floor_box()
	upper.position = Vector3(2, Step - .1, 0)
	var checked := 0
	var max_seat := 0.0
	var max_stirrup := 0.0
	for support: String in ["flat", "slope", "step"]:
		var split := support == "step"
		var normal := Vector3(.17, 1.0, -.11).normalized() if support == "slope" else Vector3.UP
		var center := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), center - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 8.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for x: float in ([-.22, -.03, .16] if split else [0.0]):
			for body: int in [400, 401]:
				var anchor := Vector3(x, Step if split and x > 0.0 else 0.0, 0.0)
				var actor := Avatar.new()
				actor.initial_body = body
				actor.position = anchor
				actor.rotation.y = PI * .5
				root.add_child(actor)
				actor.set_physics_process(false)
				actor.apply_server_appearance({"body": body, "hue": 1002}, Gear)
				var horse: Node3D = actor.horse_visual
				var player: AnimationPlayer = horse.animator
				var rider: Node3D = actor.human_visual
				var contact: SkeletonModifier3D = actor.rider_contact
				assert(horse.harness.visible and horse.reins.visible and horse.native_mount_item == 0x3eb3)
				horse.set_physics_process(false)
				horse.set_process(false)
				rider.set_process(false)
				contact.begin_mount(false)
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				rider.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				for clip: String in ["Idle", "Walk", "Run"]:
					horse.current_clip = clip
					horse.action_remaining = 100.
					for frame in 35:
						actor._physics_process(1.0 / 60.0)
						actor.animate(false, PI * .5, 1.0 / 60.0, 0.0)
					rider.cancel_action()
					rider.play("Rider_" + clip, 0.0)
					horse.play(clip, 0.0)
					player.advance(0.0)
					rider.animator.advance(0.0)
					for phase: float in [.13, .37, .61, .86]:
						player.seek(player.current_animation_length * phase, true)
						horse._physics_process(1.0 / 60.0)
						horse.contact.modification_processed.emit()
						rider.animator.seek(rider.animator.current_animation_length * phase, true)
						for frame in 4:
							await process_frame
						var feet: Array = contact.stirrup_errors
						assert(contact.seat_error < .002 and feet.size() == 2 and feet.max() < .025,
							"%s %s %s %.3f: %s %s" % [support, body, clip, phase, contact.seat_error, feet])
						assert(rider.grip.reins_holding and rider.grip.left_reins_holding and actor.position == anchor)
						max_seat = maxf(max_seat, contact.seat_error)
						max_stirrup = maxf(max_stirrup, feet.max())
						checked += 1
				actor.free()
	print("SEA HORSE RIDER TERRAIN: ", checked, " ridden poses, seat ", max_seat, " m, stirrup ", max_stirrup, " m")
	quit(0 if checked == 120 else 1)
