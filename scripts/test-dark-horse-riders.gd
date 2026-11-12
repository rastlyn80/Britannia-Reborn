# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-magical-equine-riders.gd"

const DarkHorse := preload("res://Presentation/SourceDarkHorseVisual.gd")


func run() -> void:
	DarkHorse.configure_sources(true)
	for body: int in DarkHorse.NativeItems:
		for rider_body: int in [400, 401]:
			var rider := Avatar.new()
			rider.initial_body = rider_body
			root.add_child(rider)
			rider.set_physics_process(false)
			for outfit: Array in Outfits:
				var gear := outfit.duplicate(true)
				gear.append({"id": DarkHorse.NativeItems[body], "layer": 25, "hue": 0x8035})
				rider.apply_server_appearance({"body": rider_body, "hue": 1002}, gear)
				var mount := rider.horse_visual as DarkHorse
				if not expect(mount != null and mount.native_body == body and mount.native_hue == 0x8035
						and mount.harness.visible and mount.reins.visible and rider.human_visual.missing_art.is_empty(),
						"normal mount route fits both riders and all tested clothing"):
					return
				rider.rider_contact.begin_mount(false)
				rider.human_visual.set_process(false)
				mount.set_physics_process(false)
				mount.contact.enabled = false
				for motion: Array in Motions:
					rider.human_visual.cancel_action()
					rider.human_visual.play(motion[0], 0.0)
					mount.animator.play(motion[1], 0.0)
					rider.animator.advance(0.0)
					mount.animator.advance(0.0)
					for phase: float in [.16, .47, .78]:
						rider.animator.seek(rider.animator.current_animation_length * phase, true)
						mount.animator.seek(mount.animator.current_animation_length * phase, true)
						rider.animator.pause()
						mount.animator.pause()
						for frame in 3:
							await process_frame
						if not verify_pose(rider, mount, motion[0] in ["Rider_Idle", "Rider_Walk", "Rider_Run"]):
							return
			rider.free()
	print("DARK HORSE RIDERS: ", checks, " checks across ", poses, " poses, elbow angles ", elbow_range)
	quit()
