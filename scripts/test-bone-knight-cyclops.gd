extends "res://../scripts/test-troll-weapon-trial.gd"

const PropsClearance := preload("res://../scripts/bone-knight-cyclops-clearance.gd")
const LOADOUTS := {57: ["Scimitar", "WoodenShield"], 75: ["CyclopsMallet"]}
const SOURCE_TRIANGLES := {"Scimitar": 122, "WoodenShield": 18, "CyclopsMallet": 28}

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/bone_cyclops/candidates.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		Registry.load_index()
		for candidate: Dictionary in rows:
			Registry.entries[int(candidate.body)] = candidate.presentation
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for body: int in LOADOUTS:
		var entry := Registry.entry(body)
		var serial := 0x4100 + body
		game.entities[serial] = {"serial": serial, "body": body, "hue": 0x8035}
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(serial, 4))
		packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(packet)
		var dip: String = entry.classic_action_categories["11"]
		for treatment: String in ["original", "rounded", "modern"]:
			assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			assert(actor.receive_action(game.last_mobile_actions[serial]) and actor.current_clip == dip)
			assert(check_recovered(actor, entry.kind, treatment, LOADOUTS[body].size()))
			assert(check_props(actor, LOADOUTS[body], treatment, dip))
			actor.free()
		for hue in [0, 53, 0x8035]:
			for prop: String in LOADOUTS[body]:
				check_corpse(body, hue, prop)
	for body: int in LOADOUTS:
		var prop: String = LOADOUTS[body].back()
		await check_handoff(body, prop, Vector3.RIGHT, 0.0)
		for axis in [Vector3.RIGHT, Vector3.FORWARD]:
			for slope in [-0.14, 0.14]:
				await check_handoff(body, prop, axis, slope)
		await check_handoff(body, prop, Vector3.RIGHT, 0.0, 0.35)
		await check_handoff(body, prop, Vector3.RIGHT, 0.0, -0.35)
	await check_handoff(57, "Scimitar", Vector3.FORWARD, 0.14)
	game.free()
	print("BONE KNIGHT/CYCLOPS: six decoded routes, nine prop/hue corpse cases and 15 terrain handoffs")
	quit()

func check_recovered(actor: Node3D, kind: String, treatment: String, extra: int) -> bool:
	var source := (load("res://local-art/creatures/%s-%s.gltf" % [kind, treatment]) as PackedScene).instantiate()
	var player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in player.get_animation_list():
		var a := player.get_animation(clip)
		var b: Animation = actor.animator.get_animation(clip)
		var appended := 0 if clip == "RESET" else extra
		if clip == "Death" and kind == "cyclops_cyclops":
			appended += 1
		if clip == "Death2" and kind == "skeletons_skeleton":
			appended += 1
		assert(a.length == b.length and b.get_track_count() == a.get_track_count() + appended)
		for track in a.get_track_count():
			assert(a.track_get_path(track) == b.track_get_path(track))
			assert(a.get("tracks/%d/keys" % track) == b.get("tracks/%d/keys" % track))
	source.free()
	return true

func check_props(actor: Node3D, names: Array, treatment: String, dip: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var body := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(body, rig)
	var collision := PropsClearance.new(body, rig)
	var props: Array[Dictionary] = []
	for name: String in names:
		var item := actor.find_child(name, true, false) as MeshInstance3D
		assert(item != null and item.has_meta("source_visual_prop"))
		assert((item.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 3 * SOURCE_TRIANGLES[name])
		var surfaces := {"CyclopsMallet": 4, "WoodenShield": 2}
		assert(item.mesh.get_surface_count() == int(surfaces.get(name, 1)))
		for surface in item.mesh.get_surface_count():
			assert(item.get_active_material(surface) == item.mesh.surface_get_material(surface))
		var joint := item.skin.get_bind_bone(0)
		var grip := rig.get_bone_parent(joint)
		assert(rig.get_bone_name(grip) == ("cp_grasp_lhand" if name == "WoodenShield" else "cp_grasp_rhand"))
		props.append({"name": name, "joint": joint, "grip": grip, "skin": Ground.skin_points(item, rig)})
	var feet := [rig.find_bone("bip01 l foot"), rig.find_bone("bip01 r foot")]
	var head := rig.find_bone("bip01 head")
	var entity_pose := actor.global_transform
	for clip in player.get_animation_list():
		# CreatureVisual inherits two animal-only clips synthesized after loading.
		if clip in ["RESET", "Eat", "LieDown"]:
			continue
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		var baseline: Array[Vector3] = []
		for foot: int in feet:
			baseline.append(rig.to_global(rig.get_bone_global_pose(foot).origin))
		var head_start := rig.to_global(rig.get_bone_global_pose(head).origin).y
		var drift := 0.0
		var head_drop := 0.0
		var body_floor := INF
		var floors := {}
		var crosses := {}
		for sample in 121:
			player.seek(player.get_animation(clip).length * float(sample) / 120.0, true)
			rig.force_update_all_bone_transforms()
			collision.update_pose()
			for prop in props:
				var pose := rig.global_transform * rig.get_bone_global_pose(prop.joint)
				var grip := rig.to_global(rig.get_bone_global_pose(prop.grip).origin)
				var release := Vector3.ZERO
				if clip == "Death" and prop.name == "CyclopsMallet":
					release = Vector3(-0.22, 0.115, 0.075) * smoothstep(0.69, 0.98, float(sample) / 120.0)
				if clip == "Death2" and prop.name == "WoodenShield":
					release = Vector3(0.29, 0.095, 0.12) * smoothstep(0.49, 0.72, float(sample) / 120.0)
				assert(pose.origin.distance_to(grip + release) < 0.003)
				var floor := Ground.minimum_plane_gap(prop.skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
				floors[prop.name] = minf(floors.get(prop.name, INF), floor)
				crosses[prop.name] = int(crosses.get(prop.name, 0)) + int(collision.crosses_prop(pose, prop.name))
			if clip == dip:
				for i in feet.size():
					drift = maxf(drift, rig.to_global(rig.get_bone_global_pose(feet[i]).origin).distance_to(baseline[i]))
				head_drop = maxf(head_drop, head_start - rig.to_global(rig.get_bone_global_pose(head).origin).y)
				body_floor = minf(body_floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		print(actor.native_body, " ", treatment, " ", clip, " floors and crossings ", floors, " / ", crosses,
			" dip feet/head/body ", [drift, head_drop, body_floor])
		if crosses.values().max() != 0 or floors.values().min() < (-0.28 if clip == "Death" else -0.003):
			return false
		if clip == dip and (drift > 0.012 or head_drop < 0.065 or body_floor < -0.008):
			return false
	return actor.global_transform.is_equal_approx(entity_pose)
