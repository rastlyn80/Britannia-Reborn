extends "res://../scripts/test-bone-knight-cyclops.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const ROUTES := {
	57:{4:"Attack",5:"ShieldSideCut",6:"ShieldOvercut",10:"Hit",11:"KnightDip",
		15:"ShieldDuck",16:"BladeParry",17:"Fidget",18:"BladeSalute"},
	317:{2:"Death",3:"Death",11:"BatWingCheck",15:"BankRecoil",16:"BankRecoil",
		17:"Fidget",18:"WingPulse",20:"BatSettle",21:"AirDeath"},
	128:{11:"Fidget",15:"PixieFlinch",16:"PixieFlinch",17:"Fidget",18:"PixieSpiral"},
	775:{11:"Fidget",15:"MassRecoil",16:"MassRecoil",17:"Fidget",18:"TendrilRipple"},
}
const FITTED := {57:[5,6,15,16,18],317:[15,16,18,21],128:[15,16,18],775:[15,16,18]}

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/later_creature_gestures/candidates.json"))
		var packages := {}
		for candidate: Dictionary in rows:
			var body := int(candidate.body)
			assert(not packages.has(body) or packages[body] == candidate.presentation)
			packages[body] = candidate.presentation
		assert(packages.size() == ROUTES.size())
		Registry.entries.merge(packages, true)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in ROUTES:
		var row := Registry.entry(body)
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
			Exact.check_earlier_keys(player,row.classic_gesture_base_assets[treatment])
			var mesh := actor.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh,rig)
			for slot: int in ROUTES[body]:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(body,4))
				packet.append_array(PackedByteArray([0,slot,0,5,0,1,1,0,0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[body]) and actor.current_clip == ROUTES[body][slot])
				if body == 317:
					assert(actor.dead == (slot in [2,3,21]))
					actor.model.position -= actor.fall.shift
					actor.fall.shift = Vector3.ZERO
					actor.fall.plane = {}
				actor.dead = false
				player.stop()
				player.play(actor.current_clip,0.0)
				player.advance(0.0)
				var gaps: Array[float] = []
				for frame in 61:
					player.seek(player.current_animation_length * float(frame) / 60.0,true)
					rig.force_update_all_bone_transforms()
					gaps.append(Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP))
					assert(is_finite(gaps[-1]) and actor.position.is_zero_approx() and actor.native_hue == 0x8035)
					samples += 1
				if slot in FITTED[body]:
					assert(gaps.min() > -0.007, "Body %d action %d gap %.4f" % [body,slot,gaps.min()])
				if body == 317 and slot == 21:
					assert(gaps[0] > 0.20 and gaps[-1] < 0.006)
				if body == 128 and slot == 18:
					assert(gaps[0] < 0.008 and gaps[30] > 0.25 and gaps[-1] < 0.008)
			if body == 57:
				assert(check_props(actor, LOADOUTS[57], treatment, "KnightDip"))
			if body == 775 and treatment == "modern":
				var material := mesh.get_active_material(0) as ShaderMaterial
				assert(material.shader.resource_path.ends_with("SourceAmorphousSurface.gdshader"))
				assert(material.get_shader_parameter("partial_hue") == true)
			actor.free()
		for hue: int in [0,53,0x8035]:
			var cadaver := Corpses.build(body,hue)
			assert(cadaver != null and cadaver.get_meta("static_cadaver"))
			assert(cadaver.get_meta("graphic_id") == 0x2006 and cadaver.get_meta("corpse_body") == body)
			assert(cadaver.get_meta("native_hue") == hue and cadaver.find_children("*","Skeleton3D",true,false).is_empty())
			cadaver.free()
	game.free()
	print("LATER CREATURE GESTURES: ", samples, " decoded poses, original props, material and 12 corpse hues")
	quit()
