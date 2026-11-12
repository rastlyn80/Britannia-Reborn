# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-magical-equine-riders.gd"

const SourceOstard := preload("res://Presentation/SourceEnhancedOstard.gd")


func run() -> void:
	SourceOstard.configure(true)
	if not expect(SourceOstard.active.size() == 2, "both checked source ostards load"):
		return
	for body: int in SourceOstard.Forms:
		for gender: int in [400, 401]:
			if not await exercise(body, gender):
				return
	print("SOURCE OSTARDS RIDERS: ", checks, " checks across ", poses, " poses, max seat ", max_seat,
		" m, max foot ", max_foot, " m, gripping elbow range ", elbow_range, " radians")
	quit()


func exercise(body: int, gender: int) -> bool:
	var rider := Avatar.new()
	rider.initial_body = gender
	root.add_child(rider)
	rider.set_physics_process(false)
	for outfit: Array in Outfits:
		var worn := outfit.duplicate(true)
		worn.append({"id": SourceOstard.Forms[body].item, "layer": 25, "hue": 0x8035})
		rider.apply_server_appearance({"body": gender, "hue": 1002}, worn)
		var mount := rider.horse_visual as SourceOstard
		if not expect(mount != null and mount.native_body == body and mount.reins.visible
				and rider.human_visual.missing_art.is_empty(), "the expected dyed mount and outfit appear"):
			return false
		rider.rider_contact.begin_mount(false)
		rider.human_visual.set_process(false)
		mount.set_physics_process(false)
		mount.contact.active = false
		for pair: Array in Motions:
			var gait: String = SourceOstard.Gaits[2][["Idle", "Walk", "Run"].find(pair[1])]
			rider.human_visual.cancel_action()
			rider.human_visual.play(pair[0], 0.0)
			mount.animator.play(gait, 0.0)
			rider.animator.advance(0.0)
			mount.animator.advance(0.0)
			for phase: float in [.0, .21, .50, .79]:
				rider.animator.seek(rider.animator.current_animation_length * phase, true)
				mount.animator.seek(mount.animator.current_animation_length * phase, true)
				rider.animator.pause()
				mount.animator.pause()
				for frame in 3:
					await process_frame
				var contact: SkeletonModifier3D = rider.rider_contact
				var feet: Array[float] = contact.stirrup_errors
				if not expect(contact.seat_error < .003 and feet.size() == 2 and feet.max() < .025,
						"pelvis and boots track the ostard through every mounted pose"):
					print(body, " ", gender, " ", pair, " at ", phase, " seat ", contact.seat_error, " boots ", feet)
					return false
				if not verify_grip(rider, contact):
					return false
				max_seat = maxf(max_seat, contact.seat_error)
				max_foot = maxf(max_foot, feet.max())
				poses += 1
	rider.free()
	return true
