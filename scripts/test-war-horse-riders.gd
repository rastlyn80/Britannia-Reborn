# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-magical-equine-riders.gd"

const OriginalHorse := preload("res://Presentation/SourceWarHorseVisual.gd")


func run() -> void:
	OriginalHorse.configure_war_horses(true)
	for body: int in OriginalHorse.FormsByBody:
		var item: int = OriginalHorse.FormsByBody[body][1]
		if item < 0:
			continue
		for rider_body: int in [400, 401]:
			if not await check_rider(body, item, rider_body):
				return
	print("ORIGINAL WAR HORSE RIDERS: ", checks, " checks across ", poses, " poses, seat ", max_seat,
		" m, feet ", max_foot, " m, back ", back_gap, " m, mouth ", max_mouth, " m, elbows ", elbow_range)
	quit()


func check_rider(body: int, item: int, rider_body: int) -> bool:
	var rider := Avatar.new()
	rider.initial_body = rider_body
	root.add_child(rider)
	rider.set_physics_process(false)
	for outfit: Array in Outfits:
		var gear := outfit.duplicate(true)
		gear.append({"id": item, "layer": 25, "hue": 0x8021})
		rider.apply_server_appearance({"body": rider_body, "hue": 1002}, gear)
		var mount := rider.horse_visual as OriginalHorse
		if not expect(mount != null and mount.native_body == body and mount.native_hue == 0x8021
				and mount.harness.visible and mount.reins.visible and rider.human_visual.missing_art.is_empty(),
				"the normal mounted presentation equips the robe and plate with each original coat"):
			return false
		rider.rider_contact.begin_mount(false)
		rider.human_visual.set_process(false)
		mount.set_physics_process(false)
		mount.contact.enabled = false
		for motion: Array in Motions:
			rider.human_visual.cancel_action()
			rider.human_visual.play(motion[0], 0.)
			mount.animator.play(motion[1], 0.)
			rider.animator.advance(0.)
			mount.animator.advance(0.)
			for phase: float in [.16, .47, .78]:
				rider.animator.seek(rider.animator.current_animation_length * phase, true)
				mount.animator.seek(mount.animator.current_animation_length * phase, true)
				rider.animator.pause()
				mount.animator.pause()
				for frame in 3:
					await process_frame
				if not verify_pose(rider, mount, motion[0] in ["Rider_Idle", "Rider_Walk", "Rider_Run"]):
					return false
	rider.free()
	return true
