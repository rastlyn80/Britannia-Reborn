extends SceneTree
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const CANDIDATES := "res://../work/creatures/wraith_drake_walrus_actions/candidates.json"

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

const WRAITH := {2:"Death",3:"Death2",6:"OverheadRake",15:"ReachingRecoil",16:"RaisedGuard",18:"SpectralClutch"}
const DRAKE := {2:"Death",3:"Death2",6:"WingRake",15:"FoldedFlinch",16:"LowWingGuard",18:"WingLift",21:"AirDeath"}
const WALRUS := {4:"FlipperAlert",5:"Attack",6:"TuskThrust",8:"Death",9:"Fidget",10:"HeadHitch",12:"Death2"}
const ROUTES := {26:WRAITH,60:DRAKE,61:DRAKE,221:WALRUS}

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
		var unique := {}
		for candidate: Dictionary in rows:
			var body := int(candidate.body)
			assert(not unique.has(body) or unique[body] == candidate.presentation)
			unique[body] = candidate.presentation
		assert(unique.size() == 4)
		Registry.entries.merge(unique, true)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in ROUTES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch", row.family) == "wraith_drake_walrus_actions")
		game.entities[42] = {"serial": 42, "body": body}
		for treatment: String in ["original", "rounded", "modern"]:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			var hue := 0x4001 if body == 26 else 0x8035
			actor.apply_identity(body, hue)
			actor.set_process(false)
			actor.set_physics_process(false)
			var player: AnimationPlayer = actor.animator
			Exact.check_earlier_keys(player, row.classic_gesture_base_assets[treatment])
			var rig: Skeleton3D = actor.skeleton
			if body in [60, 61]:
				assert(actor.receive_action({"protocol":"classic","action":12,"frames":5,"serial":42}))
				player.advance(0.0)
				player.seek(player.current_animation_length * 0.55, true)
				rig.force_update_all_bone_transforms()
				var muzzle := rig.find_bone("box15")
				var expected := rig.to_global(rig.get_bone_global_pose(muzzle).origin)
				assert(actor.current_clip == "DragonBreath" and actor.fire_breath_origin().is_equal_approx(expected))
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			for slot: int in ROUTES[body]:
				actor.dead = false
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(42, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[42]) and actor.current_clip == ROUTES[body][slot])
				player.play(actor.current_clip, 0.0)
				player.advance(0.0)
				var start_floor := 0.0
				var end_floor := 0.0
				var least := INF
				for frame in 61:
					player.seek(player.current_animation_length * frame / 60.0, true)
					rig.force_update_all_bone_transforms()
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
					assert(is_finite(gap) and actor.native_hue == hue and actor.position.is_zero_approx())
					if frame == 0:
						start_floor = gap
					end_floor = gap
					least = minf(least, gap)
					samples += 1
				if slot != 3 and (body != 221 or slot in [4,6,10,12]):
					assert(least > -0.002, "Body %d group %d crossed its floor by %.4fm" % [body, slot, least])
				if slot == 21:
					assert(start_floor > 0.8 and end_floor > 0.0 and end_floor < 0.008)
					check_landing_height(body, rig, player, "Death2", 0.11)
				if body == 26:
					assert((mesh.get_active_material(0) as ShaderMaterial).shader.resource_path.ends_with("WraithSpectralSurface.gdshader"))
			actor.free()
	game.free()
	print("WRAITH, DRAKES AND WALRUS: ", samples, " decoded poses with retained source keys and native raw hue")
	quit()

func check_landing_height(body: int, rig: Skeleton3D, player: AnimationPlayer, reference: String, margin: float) -> void:
	var hips := rig.find_bone("bip01 pelvis")
	var landing := rig.to_global(rig.get_bone_global_pose(hips).origin).y
	player.play(reference, 0.0)
	player.advance(0.0)
	player.seek(player.current_animation_length, true)
	rig.force_update_all_bone_transforms()
	var source := rig.to_global(rig.get_bone_global_pose(hips).origin).y
	assert(absf(landing - source) < margin, "Body %d landed with its hips %.2fm above the recovered pose" % [body, landing - source])
