# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Profile := preload("res://Presentation/EnhancedCreatureActions.gd")
const Installed := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Serial := 105
const Candidate := "res://../work/creatures/native-form-audit/enhanced-source-gaps/bird-only/bird-enhanced.scn"
const Modes := {"0": {
	"2": ["BirdQuietSettle", "BirdQuietSettle"], "5": ["BirdGlance", "BirdQuietSettle"],
	"8": ["BirdQuietSettle"], "11": ["BirdQuietSettle", "BirdQuietSettle", "BirdQuietSettle"],
	"14": ["BirdQuietSettle"], "15": ["BirdQuietSettle"],
}, "1": {"5": ["BirdGlance"]}}
const Slopes := [Vector3.ZERO, Vector3(.14, 0.0, 0.0), Vector3(-.14, 0.0, 0.0),
	Vector3(0.0, 0.0, .14), Vector3(0.0, 0.0, -.14)]

class RouteAvatar extends Node3D:
	var horse_visual: Node3D
	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var original := Registry.entry(6)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var row := Registry.entry(6) if installed else original.duplicate(true)
	if not installed:
		row.assets.modern = Candidate
		row.enhanced_source_action_groups = Modes
		row.flight_falls_back_to_combat = true
	assert(row.enhanced_source_action_groups == Modes and row.flight_falls_back_to_combat)
	Registry.entries[6] = row
	var actor := Registry.create(6)
	root.add_child(actor)
	actor.apply_identity(6, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	var avatar := RouteAvatar.new()
	avatar.horse_visual = actor
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Serial] = {"serial": Serial, "body": 6, "hue": 0x8035}
	var selections := 0
	var compatible := 0
	for flags: int in [0, 0x04, 0x40, 0x44]:
		for kind: int in [2, 5, 8, 11, 14, 15]:
			var groups: Array = Modes["1" if flags == 0 else "0"].get(str(kind), Modes["0"][str(kind)])
			for variation: int in [0, 1, 2, 127]:
				assert(Profile.dispatch(avatar, decode(game, kind, variation), true, flags))
				assert(actor.current_clip == groups[variation % groups.size()] and not actor.dead)
				selections += 1
			for variation: int in [0, 128, 255]:
				var packet := decode(game, kind, variation)
				var result := Classic.dispatch(avatar, packet)
				var clip: String = actor.current_clip
				assert(Profile.dispatch(avatar, packet, variation >= 128, flags) == result and actor.current_clip == clip)
				compatible += 1
	var floor := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, .10, 4.0)
	collider.shape = shape
	collider.position.y = -.05
	floor.add_child(collider)
	root.add_child(floor)
	var minimum := INF
	var pose_count := 0
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var head := rig.find_bone("head")
	assert(head >= 0)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for tilt: Vector3 in Slopes:
		floor.rotation = tilt
		await physics_frame
		await physics_frame
		for variant in [0, 1]:
			player.stop()
			player.play("Idle", 0.0)
			player.advance(0.0)
			assert(Profile.dispatch(avatar, decode(game, 5, variant), true, 0x40))
			player.advance(.13)
			var angle := 0.0
			player.seek(0.0, true)
			var first := rig.get_bone_global_pose(head).basis.get_rotation_quaternion()
			for i in 31:
				player.seek(player.current_animation_length * float(i) / 30.0, true)
				for step in 25:
					actor._physics_process(1.0 / 60.0)
				rig.force_update_all_bone_transforms()
				minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
				var orientation := rig.get_bone_global_pose(head).basis.get_rotation_quaternion()
				angle = maxf(angle, first.angle_to(orientation))
				assert(actor.global_position.is_zero_approx() and actor.native_hue == 0x8035)
				pose_count += 1
			assert(angle > .50 if variant == 0 else angle > .015 and angle < .10)
	for hue in [0, 53, 0x8035]:
		var corpse := Corpses.build(6, hue)
		assert(corpse != null and corpse.get_meta("corpse_body") == 6 and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("static_cadaver") and corpse.get_meta("graphic_id") == 0x2006)
		corpse.free()
	print("BIRD ENHANCED: ", selections, " selections, ", compatible, " Classic comparisons, ",
		pose_count, " finite terrain poses, three corpse hues, minimum gap ", minimum)
	assert(selections == 96 and compatible == 72 and pose_count == 310 and minimum >= .001)
	if not installed:
		var file := FileAccess.open(Candidate.get_base_dir() + "/bird-enhanced-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"routes": selections, "classic_comparisons": compatible,
			"terrain_poses": pose_count, "min_gap": minimum, "corpse_hues": 3,
			"scene_sha256": {"modern": FileAccess.get_sha256(Candidate)},
			"test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	Registry.entries[6] = original
	avatar.free()
	actor.free()
	floor.free()
	game.free()
	quit()

func decode(game: Node, type: int, variation: int) -> Dictionary:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(Serial, 4))
	bytes.append_array(PackedByteArray([0, type, 0, 0, variation]))
	game._handle(bytes)
	return game.last_mobile_actions[Serial]
