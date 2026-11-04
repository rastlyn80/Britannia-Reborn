extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const SERIAL := 0x4100
const BODY := 14
const TREATMENTS := ["original", "rounded", "modern"]
const ACTIONS := {11: "StoneGesture", 12: "Assemble"}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var accepted := Registry.entry(BODY)
	if "--active" in OS.get_cmdline_user_args():
		for treatment: String in TREATMENTS:
			var path: String = accepted.assets[treatment]
			assert(path == "res://local-art/creatures/earth-aos/" + treatment + ".scn")
			assert(FileAccess.get_sha256(path) == accepted.authored_action_scene_sha256[treatment])
	else:
		var trial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/earth-aos/candidate.json"))
		Registry.entries[BODY] = trial
	for treatment: String in TREATMENTS:
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		assert(is_equal_approx(actor.skeleton.global_basis.get_scale().x, 1.3))
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var expected_triangles := 410 if treatment == "original" else 6560
		assert(mesh.mesh.get_faces().size() == 3 * expected_triangles)
		if treatment == "modern":
			var surface := mesh.get_surface_override_material(0) as ShaderMaterial
			assert(surface.shader.resource_path.ends_with("CreatureMineralSurface.gdshader"))
		for slot: int in ACTIONS:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(SERIAL, 4))
			packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
			assert(actor.current_clip == ACTIONS[slot] and actor.native_hue == 0x8035)
			assert(actor.contact.enabled == (slot == 11))
			if not sample_motion(actor, mesh, ACTIONS[slot], treatment):
				quit(1)
				return
			actor._process(actor.action_remaining + 0.001)
			actor.play_gait(false, 0.0)
			assert(actor.current_clip == "Idle" and actor.contact.enabled)
		actor.free()
	for hue in [0, 0x11, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	Registry.entries[BODY] = accepted
	game.free()
	print("EARTH ELEMENTAL AOS: six decoded routes, 486 full-skin poses and three static corpse hues")
	quit()

func sample_motion(actor: Node3D, mesh: MeshInstance3D, clip: String, treatment: String) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var skin := Ground.skin_points(mesh, rig)
	var root_pose := actor.global_transform
	var neck := rig.find_bone("bip01 neck")
	var wrist := rig.find_bone("bip01 r hand")
	var minimum := INF
	var start_top := 0.0
	var finish_floor := 0.0
	var first_neck := Vector3.ZERO
	var finish_neck := Vector3.ZERO
	var first_wrist := Vector3.ZERO
	var wrist_travel := 0.0
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	for sample in 81:
		player.seek(player.get_animation(clip).length * float(sample) / 80.0, true)
		rig.force_update_all_bone_transforms()
		var neck_point := rig.to_global(rig.get_bone_global_pose(neck).origin)
		var wrist_point := rig.to_global(rig.get_bone_global_pose(wrist).origin)
		if sample == 0:
			first_neck = neck_point
			first_wrist = wrist_point
			start_top = -Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.DOWN)
		wrist_travel = maxf(wrist_travel, wrist_point.distance_to(first_wrist))
		finish_floor = Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		finish_neck = neck_point
		minimum = minf(minimum, finish_floor)
		if not actor.global_transform.is_equal_approx(root_pose):
			return false
	if clip == "Assemble":
		var rise := finish_neck.y - first_neck.y
		print(treatment, " emergence initial top / final floor / neck rise ", [start_top, finish_floor, rise])
		return start_top < 0.0 and absf(finish_floor) < 0.006 and rise > 1.0
	print(treatment, " gesture minimum floor / wrist travel ", [minimum, wrist_travel])
	return minimum > -0.012 and wrist_travel > 0.15
