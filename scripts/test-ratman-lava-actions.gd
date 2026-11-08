extends SceneTree
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const SwordClearance := preload("res://../scripts/ratman-sword-clearance.gd")
const CANDIDATES := "res://../work/creatures/ratman_lava_actions/candidates.json"
const MOTIONS := {
	90: {3:"Death2", 4:"CoilSnap", 6:"LongStrike", 15:"NeckDrawback", 16:"LowNeckRecoil", 18:"TailRipple"},
	143: {11:"MageStoop", 15:"MageBladeRise", 16:"MageBladeBrace", 18:"MageGuardLook"},
}

static func load_routes() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
		assert(rows.size() == 2)
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func():quit(2))
	call_deferred("run")
func run() -> void:
	load_routes()
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in MOTIONS:
		game.entities[body] = {"serial":body, "body":body, "hue":0x8035}
		for treatment: String in ["original", "rounded", "modern"]:
			samples += check_motions(body, treatment, game)
		for hue in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("graphic_id") == 0x2006)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			assert((body == 143) == (corpse.find_child("RatmanSword", true, false) != null))
			corpse.free()
	game.free()
	print("RATMAN MAGE AND LAVA SERPENT: ", samples, " decoded poses and six static corpse hues")
	quit()

func check_motions(body: int, treatment: String, game: Node) -> int:
	var samples := 0
	var row := Registry.entry(body)
	assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body,0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	Exact.check_earlier_keys(player, row.classic_gesture_base_assets[treatment])
	if body == 90 and treatment == "modern":
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var material := mesh.get_surface_override_material(0) as ShaderMaterial
		assert(material.shader.resource_path.ends_with("SourceLavaSerpentSurface.gdshader"))
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var body_skin := Ground.skin_points(mesh, rig)
	var sword := actor.model.find_child("RatmanSword", true, false) as MeshInstance3D
	var sword_skin := Ground.skin_points(sword, rig) if sword != null else {}
	var solver := SwordClearance.new(mesh, rig) if sword != null else null
	var grip := rig.find_bone("cp_grasp_rhand")
	var blade := rig.find_bone("ratman sword")
	assert((body == 143) == (sword != null))
	for slot: int in MOTIONS[body]:
		actor.dead = false
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(body, 4))
		packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(packet)
		assert(actor.receive_action(game.last_mobile_actions[body]) and actor.current_clip == MOTIONS[body][slot])
		player.stop()
		player.play(actor.current_clip, 0.0)
		player.advance(0.0)
		var least := INF
		var largest := -INF
		for frame in 83:
			player.seek(player.current_animation_length * frame / 82.0,true)
			rig.force_update_all_bone_transforms()
			var gap := Ground.minimum_plane_gap(body_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
			assert(is_finite(gap) and actor.native_hue == 0x8035 and actor.position.is_zero_approx())
			least = minf(least,gap)
			largest = maxf(largest,gap)
			if sword != null:
				assert(Ground.minimum_plane_gap(sword_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP) > 0.006)
				assert(rig.get_bone_global_pose(grip).origin.is_equal_approx(rig.get_bone_global_pose(blade).origin))
				if frame % 4 == 0:
					solver.update_pose()
					assert(not solver.intersects(rig.global_transform * rig.get_bone_global_pose(blade)))
			samples += 1
		assert(least > -0.005 and (slot == 3 or largest < 0.005), "Body %d %s group %d support gap %s..%s" % [body,treatment,slot,least,largest])
	actor.free()
	return samples
