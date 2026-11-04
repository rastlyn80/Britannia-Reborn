extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const BODIES := [9, 10, 12, 38, 40, 43, 59, 60, 61]
const DRAGONS := [12, 59, 60, 61]

class Arena extends Node3D:
	var avatars := {}
	var game: Node

func _initialize() -> void:
	create_timer(55.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/dragon_daemon/candidates.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		Registry.load_index()
		for candidate: Dictionary in rows:
			Registry.entries[int(candidate.body)] = candidate.presentation
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.phase = "world"
	var arena := Arena.new()
	root.add_child(arena)
	arena.game = game
	var effects := Effects.new()
	arena.add_child(effects)
	effects.configure(arena)
	var items := Items.new()
	arena.add_child(items)
	items.session = game
	items.add_child(items.hint)
	var poses := 0
	for body: int in BODIES:
		var entry := Registry.entry(body)
		for treatment: String in ["original", "rounded", "modern"]:
			assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
			var avatar := Avatar.new()
			arena.add_child(avatar)
			avatar.set_process(false)
			avatar.set_physics_process(false)
			avatar.position = Vector3(2.0, 0.0, -3.0)
			avatar.rotation.y = 0.36
			var actor := Registry.create(body)
			actor.treatment = treatment
			avatar.horse_visual = actor
			avatar.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			var expected_scale := 0.5 if body in [60, 61] else 1.0
			assert(actor.model.scale.is_equal_approx(Vector3.ONE * expected_scale))
			var serial := 0x4100 + body
			game.entities[serial] = {"serial": serial, "body": body, "hue": 0x8035}
			arena.avatars[serial] = avatar
			arena.avatars[serial + 0x100] = avatar
			for slot: String in entry.classic_motion_references:
				var action := PackedByteArray([0x6e])
				action.append_array(Wire.uint_be(serial, 4))
				action.append_array(PackedByteArray([0, int(slot), 0, 5, 0, 1, 1, 0, 0]))
				game._handle(action)
				assert(actor.receive_action(game.last_mobile_actions[serial]))
				assert(actor.current_clip == entry.classic_action_categories[slot])
				if actor.current_clip == "DragonBreath":
					check_projectile(game, effects, actor, avatar, serial)
				check_stance(actor)
				poses += 61
			arena.avatars.erase(serial)
			arena.avatars.erase(serial + 0x100)
			avatar.free()
		for hue in [0, 53, 0x8035]:
			var holder := Node3D.new()
			items.add_child(holder)
			assert(items._equine_corpse(holder, {"id": 0x2006, "amount": body, "hue": hue, "direction": 5}, 0x40001000 + body))
			var corpse := holder.get_node("CorpseVisual")
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			holder.free()
	print("DRAGON/DAEMON: ", poses, " complete-skin poses, 27 static corpse hues, 12 decoded fire projectiles")
	arena.free()
	game.free()
	quit()

func check_projectile(game: Node, effects: Node3D, actor: Node3D, avatar: Node3D, serial: int) -> void:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var jaw := rig.find_bone("box14")
	var breath := player.get_animation("DragonBreath")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var jaw_track := breath.find_track(NodePath("%s:box14" % path), Animation.TYPE_ROTATION_3D)
	assert(jaw >= 0 and jaw_track >= 0)
	var closed := breath.rotation_track_interpolate(jaw_track, 0.0)
	player.advance(0.0)
	for frame in 78:
		player.advance(1.0 / 60.0)
		actor._process(1.0 / 60.0)
	actor.play_gait(true, 4.0)
	assert(actor.current_clip == "DragonBreath" and is_equal_approx(player.current_animation_position, 1.3))
	rig.force_update_all_bone_transforms()
	assert(rig.get_bone_pose_rotation(jaw).angle_to(closed) > 0.35)
	var muzzle: Vector3 = actor.fire_breath_origin()
	var chest := avatar.global_position + Vector3.UP * 1.2
	assert(chest.distance_to(muzzle) > 1.0)
	assert(effects._bolt_origin({"source": serial, "graphic": 0x36d3, "from": Vector3i.ZERO}).is_equal_approx(chest))
	var projectile := PackedByteArray([0x70, 0])
	projectile.append_array(Wire.uint_be(serial, 4))
	projectile.append_array(Wire.uint_be(serial + 0x100, 4))
	projectile.append_array(Wire.uint_be(0x36d4, 2))
	projectile.append_array(PackedByteArray([0, 1, 0, 1, 0, 0, 2, 0, 2, 0, 5, 0, 0, 0, 0, 0]))
	assert(projectile.size() == 28)
	game._handle(projectile)
	assert(effects.get_child_count() == 1)
	var bolt := effects.get_child(0) as MeshInstance3D
	assert(bolt.global_position.is_equal_approx(muzzle))
	bolt.free()

func check_stance(actor: Node3D) -> void:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var clip: String = actor.current_clip
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var skin: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skin.append(Ground.skin_points(mesh, rig))
	assert(not skin.is_empty())
	var feet := [rig.find_bone("bip01 l foot"), rig.find_bone("bip01 r foot")]
	assert(feet.min() >= 0)
	var planted: Array[Vector3] = []
	rig.force_update_all_bone_transforms()
	for joint: int in feet:
		planted.append(rig.to_global(rig.get_bone_global_pose(joint).origin))
	for sample in 61:
		player.seek(player.get_animation(clip).length * float(sample) / 60.0, true)
		rig.force_update_all_bone_transforms()
		for i in feet.size():
			assert(rig.to_global(rig.get_bone_global_pose(feet[i]).origin).distance_to(planted[i]) < 0.00001)
		for mesh in skin:
			assert(Ground.minimum_plane_gap(mesh, rig, rig.global_transform, Vector3.ZERO, Vector3.UP) >= -0.005)
