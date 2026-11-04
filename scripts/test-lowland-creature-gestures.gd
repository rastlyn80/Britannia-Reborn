extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const ROUTES := {
	51:{17:"Fidget",18:"CrestRise"},
	154:{11:"Fidget",15:"MummyRecoil",16:"MummyRecoil",17:"Fidget",18:"MummyCurl"},
	80:{4:"Attack",6:"SpringLunge",10:"Hit",11:"ToadGulp",15:"HindBrace",16:"BellyDuck",17:"Fidget",18:"ThroatPulse"},
}
const CORPSES := preload("res://Presentation/CorpseModels.gd")
const FITTED := {51:[18],154:[15,16,18],80:[6,15,16,18]}

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	load_routes()
	for body: int in ROUTES:
		var row := Registry.entry(body)
		var routes: Dictionary = ROUTES[body]
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
				if slot in FITTED[body]:
					assert(gaps.min()>-0.007, "Body %d group %d min %f" % [body,slot,gaps.min()])
				if body==80 and slot==6:
					assert(gaps[0]<0.012 and gaps.max()>0.12 and gaps[-1]<0.012)
				print(body," ",treatment," ",slot," ",routes[slot]," floor ",gaps.min(),"..",gaps.max())
			actor.free()
		for hue: int in [0,53,0x8035]:
			var corpse := CORPSES.build(body,hue)
			assert(corpse != null and corpse.get_meta("static_cadaver"))
			assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
			assert(corpse.get_meta("native_hue") == hue and corpse.find_children("*","Skeleton3D",true,false).is_empty())
			corpse.free()
	game.free()
	print("SLIME, MUMMY AND GIANT TOAD: ",samples," decoded samples with exact prior keys and nine static corpse hues")
	quit()

func load_routes() -> void:
	Registry.load_index()
	if not "--candidate" in OS.get_cmdline_user_args():
		return
	var path := "res://../work/creatures/lowland_creature_gestures/candidates.json"
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(records.size() == 6)
	var rows := {}
	for record: Dictionary in records:
		var body := int(record.body)
		assert(not rows.has(body) or rows[body] == record.presentation)
		rows[body] = record.presentation
	assert(rows.size() == ROUTES.size())
	Registry.entries.merge(rows,true)
