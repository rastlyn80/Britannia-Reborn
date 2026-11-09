extends SceneTree
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(267).duplicate(true)
	if row.get("classic_gesture_batch") == "quagmire_through_exodus_actions":
		row = preload("res://Presentation/SealedCreatureActionBase.gd").retained(row, 267).duplicate(true)
		Registry.entries[267] = row
	assert(row.kind == "troglodyte")
	var active := "--active" in OS.get_cmdline_user_args()
	var originals: Dictionary = row.get("classic_gesture_base_assets", row.assets).duplicate(true)
	for treatment in ["original", "rounded", "modern"]:
		var path := "res://local-art/creatures/troglodyte-267-reach-trial-%s.scn" % treatment
		if active:
			assert(row.assets[treatment] == path and row.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
		else:
			row.assets[treatment] = path
	if active:
		assert(row.classic_action_categories["11"] == "Pillage")
	else:
		Registry.entries[267] = row
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[0x4100] = {"serial": 0x4100, "body": 267, "hue": 53}
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(0x4100, 4))
	packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
	game._handle(packet)
	for treatment in ["original", "rounded", "modern"]:
		var actor := Registry.create(267)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(267, 53)
		assert(actor.receive_action(game.last_mobile_actions[0x4100]) and actor.current_clip == "Pillage")
		var player: AnimationPlayer = actor.animator
		var original := (load(originals[treatment]) as PackedScene).instantiate()
		var source := original.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for clip_name in source.get_animation_list():
			var before := source.get_animation(clip_name)
			var after := player.get_animation(clip_name)
			assert(after.length == before.length and after.get_track_count() == before.get_track_count())
			for track in before.get_track_count():
				assert(after.track_get_path(track) == before.track_get_path(track))
				assert(after.get("tracks/%d/keys" % track) == before.get("tracks/%d/keys" % track))
		original.free()
		var rig: Skeleton3D = actor.skeleton
		var mesh := actor.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh,rig)
		var low := INF
		var high := -INF
		var root_pose := actor.global_transform
		var head := rig.find_bone("bip01 head")
		var head_start := 0.0
		var head_rise := 0.0
		player.play("Pillage", 0.0)
		player.advance(0.0)
		for frame in 73:
			player.seek(frame / 120.0, true)
			rig.force_update_all_bone_transforms()
			var floor := Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP)
			var y := rig.to_global(rig.get_bone_global_pose(head).origin).y
			if frame == 0:
				head_start = y
			head_rise = maxf(head_rise, y-head_start)
			low = minf(low, floor)
			high = maxf(high, floor)
			assert(actor.global_transform.is_equal_approx(root_pose))
		assert(low > -0.003 and high < 0.02 and head_rise > 1.25)
		print(treatment, " floor ", [low, high], " head rise ", head_rise)
		actor.free()
	for hue in [0, 53, 0x8035]:
		var corpse := Corpses.build(267, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == 267 and corpse.get_meta("graphic_id") == 0x2006)
		assert(corpse.get_meta("native_hue") == hue and corpse.get_meta("death_clip") == "Death")
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	game.free()
	print("TROGLODYTE: three decoded action routes, three static corpse hues, existing clips exact")
	quit()
