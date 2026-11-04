extends "res://../scripts/test-troll-weapon-trial.gd"

const BAT := 317
const SERIAL := 0x413d
const GROUPS := {11: "BatWingCheck", 20: "BatSettle"}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(
			"res://../work/creatures/vampire_bat_actions/candidates.json"))
		Registry.load_index()
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": BAT, "hue": 0x8035}
	var plane := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.1, 10)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position.y = -0.05
	plane.add_child(collision)
	root.add_child(plane)
	var row := Registry.entry(BAT)
	for treatment: String in ["original", "rounded", "modern"]:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
		var actor := Registry.create(BAT)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BAT, 0x8035)
		assert(actor.native_hue == 0x8035 and actor.contact.feet.is_empty())
		assert(check_baseline(actor.animator, treatment))
		for tilt: Vector3 in [Vector3.ZERO, Vector3(0.08, 0, -0.08), Vector3(-0.09, 0, 0.11)]:
			plane.rotation = tilt
			await physics_frame
			await physics_frame
			for group: int in GROUPS:
				assert(check_flight(actor, game, plane, group, treatment))
		actor.free()
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(BAT, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == BAT and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("death_clip") == "Death")
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	plane.free()
	game.free()
	print("VAMPIRE BAT ACTIONS: 18 decoded plane runs, unchanged source tracks and three static corpse hues")
	quit()

func check_baseline(player: AnimationPlayer, treatment: String) -> bool:
	var path := "res://local-art/creatures/vampire_bat/vampire_bat-%s.gltf" % treatment
	var model := (load(path) as PackedScene).instantiate()
	var source := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in source.get_animation_list():
		var a := source.get_animation(clip)
		var b := player.get_animation(clip)
		assert(b != null and b.length == a.length and b.get_track_count() == a.get_track_count())
		for track in a.get_track_count():
			assert(a.track_get_path(track) == b.track_get_path(track))
			assert(a.get("tracks/%d/keys" % track) == b.get("tracks/%d/keys" % track))
	model.free()
	return true

func check_flight(actor: Node3D, game: Node, plane: StaticBody3D, group: int, treatment: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var head := rig.find_bone("bip01 head")
	var wing := rig.find_bone("bip01 l finger01")
	assert(head >= 0 and wing >= 0)
	var native_root := actor.global_transform
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	actor.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 75:
		actor._physics_process(1.0 / 60.0)
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, group, 0, 5 if group == 11 else 3, 0, 1, 1, 0, 0]))
	game._handle(packet)
	assert(actor.receive_action(game.last_mobile_actions[SERIAL]) and actor.current_clip == GROUPS[group])
	var low := INF
	var head_heights: Array[float] = []
	var settled_heights: Array[float] = []
	var wing_heights: Array[float] = []
	var duration: float = actor.action_remaining
	for sample in 97:
		var delta := duration / 96.0
		player.advance(0.0 if sample == 0 else delta)
		actor._physics_process(delta)
		rig.force_update_all_bone_transforms()
		assert(not actor.contact.contacts.is_empty())
		assert(actor.global_transform.is_equal_approx(native_root))
		var head_point := rig.to_global(rig.get_bone_global_pose(head).origin)
		var wing_point := rig.to_global(rig.get_bone_global_pose(wing).origin)
		head_heights.append(plane.basis.y.dot(head_point - plane.position))
		if sample * delta >= 0.14:
			settled_heights.append(head_heights.back())
		wing_heights.append(plane.basis.y.dot(wing_point - head_point))
		low = minf(low, Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.basis.y))
	actor._process(duration + 0.001)
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "Idle" and player.assigned_animation == "Idle")
	var lift: float = head_heights.max() - head_heights.min()
	var steady_lift: float = settled_heights.max() - settled_heights.min()
	var wing_travel: float = wing_heights.max() - wing_heights.min()
	print(treatment, " group ", group, " floor, head lift, settled lift and relative wing travel ",
		[low, lift, steady_lift, wing_travel], " at ", plane.rotation)
	return low >= -0.012 and wing_travel > 0.06 \
		and (lift > 0.30 if group == 11 else lift < 0.15 and steady_lift < 0.01)
