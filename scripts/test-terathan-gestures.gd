extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Items := preload("res://Presentation/WorldItems.gd")

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/terathan_classic/candidates.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		Registry.load_index()
		for candidate: Dictionary in rows:
			Registry.entries[int(candidate.body)] = candidate.presentation
	elif Registry.entry(70).get("classic_gesture_batch") == "ophidian_terathan_actions":
		var path := "res://../work/creatures/ophidian_terathan_actions/accepted-native/base-rows.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			if body in [70, 71]:
				Registry.entries[body] = row
	if "--active" in OS.get_cmdline_user_args():
		var current := Registry.entry(72)
		if current.get("classic_gesture_batch") == "ranked_classic_actions":
			var path := "res://../work/creatures/ranked_classic_actions/accepted-native/base-rows.json"
			var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
			var restored := false
			for row: Dictionary in rows:
				if int(row.bodies[0].body) == 72 and current.get("classic_gesture_base_assets") == row.assets:
					Registry.entries[72] = row
					restored = true
			if not restored:
				push_error("The active Matriarch must retain the tested Terathan cast package")
				quit(1)
				return
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var items := Items.new()
	root.add_child(items)
	items.session = game
	items.add_child(items.hint)
	var poses := 0
	for body in [70, 71, 72]:
		var serial := 0x4100 + int(body)
		var entry := Registry.entry(body)
		game.entities[serial] = {"serial": serial, "body": body, "hue": 0x8035}
		for treatment: String in ["original", "rounded", "modern"]:
			assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			assert(unchanged_clips(actor, entry.kind, treatment))
			for slot: String in entry.classic_motion_references:
				var action := PackedByteArray([0x6e])
				action.append_array(Wire.uint_be(serial, 4))
				action.append_array(PackedByteArray([0, int(slot), 0, 5, 0, 1, 1, 0, 0]))
				game._handle(action)
				assert(actor.receive_action(game.last_mobile_actions[serial]))
				assert(actor.current_clip == entry.classic_action_categories[slot])
				if slot in ["12", "14"]:
					assert(check_cast(actor, slot == "14"))
				assert(check_stance(actor))
				poses += 91
			actor.free()
		for hue in [0, 53, 0x8035]:
			var holder := Node3D.new()
			items.add_child(holder)
			assert(items._equine_corpse(holder, {"id": 0x2006, "amount": body, "hue": hue, "direction": 5}, 0x40001000 + body))
			var corpse := holder.get_node("CorpseVisual")
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			assert(corpse.find_children("*", "GPUParticles3D", true, false).is_empty())
			holder.free()
	print("TERATHAN CLASSIC: ", poses, " complete-skin poses, six decoded cast-effect cases, nine static corpse hues")
	items.free()
	game.free()
	quit()

func unchanged_clips(actor: Node3D, kind: String, treatment: String) -> bool:
	var source := (load("res://local-art/creatures/%s-%s.gltf" % [kind, treatment]) as PackedScene).instantiate()
	var before := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var after: AnimationPlayer = actor.animator
	for label in before.get_animation_list():
		var original := before.get_animation(label)
		var saved := after.get_animation(label)
		if original.length != saved.length or original.get_track_count() != saved.get_track_count():
			source.free()
			return false
		for track in original.get_track_count():
			if original.track_get_path(track) != saved.track_get_path(track) or original.get("tracks/%d/keys" % track) != saved.get("tracks/%d/keys" % track):
				source.free()
				return false
	source.free()
	return true

func check_cast(actor: Node3D, overhead: bool) -> bool:
	var player: AnimationPlayer = actor.animator
	player.advance(0.15)
	player.seek(player.current_animation_length * 0.63, true)
	actor._process(0.0)
	for particles: GPUParticles3D in actor.held_motes:
		if particles.emitting == overhead:
			return false
	for particles: GPUParticles3D in actor.release_motes:
		if particles.emitting != overhead:
			return false
	if actor.arc.visible != overhead:
		return false
	if overhead:
		var rig: Skeleton3D = actor.skeleton
		rig.force_update_all_bone_transforms()
		var origin := rig.to_global(rig.get_bone_global_pose(rig.find_bone("cp_grasp_rhand")).origin)
		if not actor.arc.global_position.is_equal_approx(origin):
			return false
	player.seek(player.current_animation_length * 0.95, true)
	actor._process(0.0)
	return not actor.arc.visible and not actor.held_motes[0].emitting and not actor.release_motes[0].emitting

func check_stance(actor: Node3D) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var clip: String = actor.current_clip
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var skin := Ground.skin_points(actor.model.find_children("*", "MeshInstance3D", true, false)[0], rig)
	var tail := rig.find_bone("bip01 tail")
	var abdomen := rig.find_bone("bip01 tail1")
	var support := Array(rig.get_bone_children(tail))
	support.erase(abdomen)
	assert(support.size() == 8)
	for root_joint: int in support.duplicate():
		var descendants := Array(rig.get_bone_children(root_joint))
		while not descendants.is_empty():
			var joint: int = descendants.pop_back()
			support.append(joint)
			descendants.append_array(Array(rig.get_bone_children(joint)))
	var grip := rig.find_bone("cp_grasp_rhand")
	var origin := actor.global_transform
	var reference: Array[Transform3D] = []
	var minimum := INF
	var drift := 0.0
	var reach := 0.0
	var lift := 0.0
	var hand := Vector3.ZERO
	for sample in 91:
		player.seek(player.get_animation(clip).length * float(sample) / 90.0, true)
		rig.force_update_all_bone_transforms()
		if sample == 0:
			for joint: int in support:
				reference.append(rig.get_bone_global_pose(joint))
			hand = rig.to_global(rig.get_bone_global_pose(grip).origin)
		for i in support.size():
			var pose := rig.get_bone_global_pose(support[i])
			if not pose.basis.is_equal_approx(reference[i].basis):
				return false
			drift = maxf(drift, pose.origin.distance_to(reference[i].origin))
		var current := rig.to_global(rig.get_bone_global_pose(grip).origin)
		reach = maxf(reach, current.distance_to(hand))
		lift = maxf(lift, current.y - hand.y)
		minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
	print(actor.native_body, " ", actor.treatment, " ", clip, " floor/drift/reach/lift ", [minimum, drift, reach, lift])
	return (minimum > -0.005 and drift < 0.00001 and reach > 0.23
		and (clip != "Cast2" or lift > 0.65) and actor.global_transform.is_equal_approx(origin))
