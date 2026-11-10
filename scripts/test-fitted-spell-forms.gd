# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const TILTS := [Vector3.ZERO, Vector3(.13, 0., 0.), Vector3(0., 0., -.13)]
const BODIES := [285, 705]
var routes := 0
var samples := 0
var corpses := 0
var minimum := INF

func _initialize() -> void:
	create_timer(120.).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for body: int in BODIES:
		game.entities[body] = {"serial": body, "body": body, "hue": 0}
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("static_cadaver") and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			assert(corpse.get_meta("death_clip") == "Death")
			corpse.free()
			corpses += 1
	for tilt: Vector3 in TILTS:
		var plane := await support(tilt)
		for body: int in BODIES:
			var row := Registry.entry(body)
			var base: Dictionary = row.get("stone_mode_predecessor", row)
			for treatment: String in row.assets:
				var actor := Registry.create(body)
				actor.treatment = treatment
				root.add_child(actor)
				actor.apply_identity(body, 53)
				actor.set_physics_process(false)
				actor.set_process(false)
				actor.contact.active = false
				var player: AnimationPlayer = actor.animator
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				var rig: Skeleton3D = actor.skeleton
				var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
				var skin := Ground.skin_points(mesh, rig)
				assert(mesh.mesh.get_surface_count() == 2 and skin.unique_vertices > 300)
				var anchor := actor.global_transform
				var contacts := 0
				for group: String in base.classic_action_categories:
					player.stop()
					actor.dead = false
					assert(actor.receive_action(decode(game, body, int(group))), str([body, treatment, group]))
					var expected: String = row.classic_action_categories[group]
					assert(actor.current_clip == expected)
					routes += 1
					for frame in 25:
						player.seek(player.current_animation_length * frame / 24.0, true)
						if not actor.dead:
							actor._physics_process(1.0 / 60.0)
							actor.contact._process_modification_with_delta(1.0 / 60.0)
							rig.force_update_all_bone_transforms()
							actor.contact.modification_processed.emit()
							contacts += actor.contact.contacts.size()
						rig.force_update_all_bone_transforms()
						var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, plane.global_basis.y.normalized())
						assert(is_finite(gap) and gap >= -.004 and actor.global_transform == anchor,
							str([body, treatment, tilt, group, frame, gap]))
						minimum = minf(gap, minimum)
						samples += 1
					if body == 285 and expected in ["Death", "Death2"]:
						var pelvis := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 pelvis")).origin)
						var torso := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 spine2")).origin)
						var trunk := torso - pelvis
						assert(absf(trunk.y) < .23 and trunk.z * (-1.0 if expected == "Death" else 1.0) > .26,
							str([body, treatment, tilt, expected, trunk]))
				assert(contacts > 0)
				actor.free()
		plane.free()
		await physics_frame
	game.free()
	assert(routes == 207 and samples == 5175 and corpses == 6)
	var trial := OS.get_environment("BR_FORM_TEST_DIR")
	if not trial.is_empty():
		var out := FileAccess.open(trial.path_join("next-original-forms/pose-evidence.json"), FileAccess.WRITE)
		assert(out != null)
		out.store_string(JSON.stringify({"native_action_decodes": routes, "finite_ground_poses": samples,
			"corpse_hues": corpses, "minimum_ground_gap": minimum,
			"index_sha256": FileAccess.get_sha256("res://local-art/creatures/accepted-index.json")}, "\t"))
		out.close()
	print("SPELL FORM PRESENTATION ", routes, " decoded groups, ", samples, " supported poses, ", corpses, " static corpse hues, minimum ", minimum)
	quit()

func decode(game: Node, serial: int, group: int) -> Dictionary:
	var packet := PackedByteArray([0x6e, 0, 0, (serial >> 8) & 255, serial & 255])
	packet.append_array(PackedByteArray([0, group, 0, 6, 0, 1, 1, 0, 0]))
	game._handle(packet)
	return game.last_mobile_actions[serial]

func support(tilt: Vector3) -> StaticBody3D:
	var ground := StaticBody3D.new()
	root.add_child(ground)
	ground.rotation = tilt
	var box := BoxShape3D.new()
	box.size = Vector3(10., .10, 10.)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = -.05
	ground.add_child(collider)
	await physics_frame
	await physics_frame
	return ground
