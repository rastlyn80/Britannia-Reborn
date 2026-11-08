extends SceneTree
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Clearance := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const CANDIDATES := "res://../work/creatures/ophidian_patchwork_actions/candidates.json"
const ROUTES := {
	86: {3:"Death2", 5:"BardicheLowSweep", 6:"BardicheHighChop", 15:"BardicheHighRecoil", 16:"BardicheLowBrace", 18:"BardicheGripShift"},
	309: {15:"WideArmRecoil", 16:"WideArmRecoil", 18:"ReachAndHitch"},
}

static func load_routes() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
		assert(rows.size() == 3)
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation

func _initialize() -> void:
	create_timer(55.).timeout.connect(func(): quit(2))
	call_deferred("run")
func run() -> void:
	load_routes()
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in ROUTES:
		game.entities[body] = {"serial":body, "body":body, "hue":0x8035}
		for treatment: String in ["original", "rounded", "modern"]:
			samples += check_motions(body, treatment, game)
		for hue in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("graphic_id") == 0x2006)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
	game.free()
	print("OPHIDIAN AND PATCHWORK: ", samples, " decoded poses and six static corpse hues")
	quit()

func check_motions(body: int, treatment: String, game: Node) -> int:
	var samples := 0
	var row := Registry.entry(body)
	assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	Exact.check_earlier_keys(player, row.classic_gesture_base_assets[treatment])
	var mesh := actor.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var prop := actor.model.find_child("OphidianBardiche", true, false) as MeshInstance3D
	var body_skin := Ground.skin_points(mesh, rig)
	var prop_skin := Ground.skin_points(prop, rig) if prop != null else {}
	var solver := Clearance.new(mesh, rig) if prop != null else null
	var grip := rig.find_bone("cp_grasp_rhand")
	var weapon := rig.find_bone("ophidian bardiche")
	for slot: int in ROUTES[body]:
		actor.dead = false
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(body, 4))
		packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(packet)
		assert(actor.receive_action(game.last_mobile_actions[body]) and actor.current_clip == ROUTES[body][slot])
		player.stop()
		player.play(actor.current_clip, 0.0)
		player.advance(0.0)
		var body_gap := INF
		var prop_gap := INF
		var conflicts := 0
		for frame in 121:
			player.seek(player.current_animation_length*float(frame)/120.0, true)
			rig.force_update_all_bone_transforms()
			body_gap = minf(body_gap, Ground.minimum_plane_gap(body_skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP))
			if prop != null:
				prop_gap = minf(prop_gap, Ground.minimum_plane_gap(prop_skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP))
				assert(rig.get_bone_global_pose(grip).origin.is_equal_approx(rig.get_bone_global_pose(weapon).origin))
				solver.update_pose()
				conflicts += int(solver.intersects(rig.global_transform * rig.get_bone_global_pose(weapon)))
			assert(actor.native_hue == 0x8035 and actor.position.is_zero_approx())
			samples += 1
		print(body, " ", slot, " min skin/prop floor and weapon conflicts ", [body_gap,prop_gap,conflicts])
		assert(body_gap > -0.005 and prop_gap > 0.0 and conflicts == 0)
	actor.free()
	return samples
