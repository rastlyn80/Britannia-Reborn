# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Profile := preload("res://Presentation/SourceSeaSerpentProfile.gd")
const Serpent := preload("res://Presentation/SourceEnhancedSeaSerpentVisual.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")


func _initialize() -> void:
	create_timer(90.).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	assert(Profile.enable())
	var corpse := Corpses.build(Profile.Body, 0x8035)
	var posed := Corpses.posed(Profile.Body, 0x8035) as Serpent
	assert(corpse != null and posed != null and corpse.position.y < 0.)
	assert(is_equal_approx(corpse.position.y, posed.corpse_waterline_offset()))
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.get_meta("graphic_id") == 0x2006)
	corpse.free()
	posed.free()
	var deck := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(18., .1, 18.)
	collider.shape = box
	deck.add_child(collider)
	deck.rotation.x = .09
	root.add_child(deck)
	var samples := 0
	var entry := Profile.Registry.entry(Profile.Body)
	for style: String in ["original", "rounded", "modern"]:
		var staged := entry.duplicate(true)
		staged.assets.modern = entry.assets[style]
		Profile.Registry.entries[Profile.Body] = staged
		var avatar := Avatar.new()
		avatar.initial_body = Profile.Body
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor := avatar.horse_visual as Serpent
		assert(actor != null)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var rig := actor.skeleton
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		for height: float in [-4., .35]:
			deck.position.y = height
			await physics_frame
			await physics_frame
			for group: int in Serpent.Groups:
				var clip: String = {2: "SeaSideFall", 3: "SeaRollFall"}.get(group, Serpent.Groups[group])
				actor.animator.play(clip, 0.)
				actor.animator.advance(0.)
				var basis := actor.model.basis
				var anchor := actor.model.position
				for frame in 21:
					actor.animator.seek(actor.animator.current_animation_length * float(frame) / 20., true)
					avatar._physics_process(.016)
					actor._physics_process(.016)
					rig.force_update_all_bone_transforms()
					var bounds := Geometry.deformed_bounds(mesh, rig)
					assert(bounds.is_finite() and bounds.size.length() < 24.)
					assert(actor.contact.contacts.is_empty() and actor.model.position.is_equal_approx(anchor)
						and actor.model.basis.is_equal_approx(basis) and is_zero_approx(avatar.ground_offset))
					samples += 1
		avatar.free()
	Profile.Registry.entries[Profile.Body] = entry
	print("SEA SERPENT WATERLINE: ", samples, " fully skinned poses over finite seabed and deck, static corpse stays at the native waterline")
	quit()
