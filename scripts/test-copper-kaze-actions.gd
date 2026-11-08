extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const CANDIDATES := "res://../work/creatures/copper_kaze_actions/candidates.json"
const MOTIONS := {110:{15:"CopperRecoil", 16:"CopperBrace", 18:"CopperShift"},
	196:{15:"KazeDoubleFlinch", 16:"KazeForearmGuard", 18:"KazeForwardSway"}}

static func load_routes() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
		assert(rows.size() == 2)
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	load_routes()
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in MOTIONS:
		var row := Registry.entry(body)
		var routes: Dictionary = MOTIONS[body]
		game.entities[body] = {"serial":body,"body":body,"hue":0x8035}
		for treatment: String in ["original","rounded","modern"]:
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body,0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var rig: Skeleton3D = actor.skeleton
			var player: AnimationPlayer = actor.animator
			var mesh := actor.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh,rig)
			Exact.check_earlier_keys(player,row.classic_gesture_base_assets[treatment])
			for slot: int in routes:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(body,4))
				packet.append_array(PackedByteArray([0,slot,0,5,0,1,1,0,0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[body]) and actor.current_clip==routes[slot])
				actor.dead = false
				player.stop()
				player.play(actor.current_clip,0.0)
				player.advance(0.0)
				var gaps: Array[float] = []
				for frame in 61:
					player.seek(player.current_animation_length*float(frame)/60.0,true)
					rig.force_update_all_bone_transforms()
					gaps.append(Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP))
					assert(actor.native_hue==0x8035 and actor.position.is_zero_approx() and is_finite(gaps[-1]))
					samples += 1
				assert(gaps.min()>-0.007, "Body %d group %d min %f" % [body,slot,gaps.min()])
				print(body," ",treatment," ",slot," ",routes[slot]," floor ",gaps.min(),"..",gaps.max())
			actor.free()
		for hue in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("graphic_id") == 0x2006)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
	game.free()
	print("DULL COPPER AND KAZE KEMONO: ",samples," decoded samples with exact prior keys and six static corpse hues")
	quit()
