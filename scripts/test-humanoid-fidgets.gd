extends "res://../scripts/test-hopper-horde-actions.gd"

const ORC := {"body": 17, "sibling": 41, "kind": "orcs_orc", "batch": "orc_fidgets",
	"high": "OrcHighGesture", "hand": "bip01 r hand", "head": "bip01 head", "height": 0.18}
const ETTIN := {"body": 18, "sibling": 2, "kind": "ettins_ettin", "batch": "ettin_fidgets",
	"high": "EttinTempleCheck", "hand": "bip01 l hand", "head": "geosphere02", "height": 0.02}
var form: Dictionary

func run() -> void:
	form = ETTIN if "--ettin" in OS.get_cmdline_user_args() else ORC
	var body: int = form.body
	var gestures := {17: str(form.high), 18: "Fidget2"}
	Registry.load_index()
	var sibling := Registry.entry(form.sibling).duplicate(true)
	if not "--active" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/candidates.json" % form.batch
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == 1 and int(rows[0].body) == body)
		Registry.entries[body] = rows[0].presentation
	var entry := Registry.entry(body)
	assert(Registry.entry(form.sibling) == sibling and sibling.kind == form.kind)
	assert(entry.classic_action_categories["17"] == gestures[17] and entry.classic_action_categories["18"] == gestures[18])
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	const SERIAL := 0x1234
	game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0}
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.1, 6.0)
	shape.shape = box
	shape.position.y = -0.05
	floor_body.add_child(shape)
	root.add_child(floor_body)
	for treatment: String in ["original", "rounded", "modern"]:
		assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
		var actor := Registry.create(body)
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(body, 0x8035)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		assert(actor.native_hue == 0x8035 and source_matches(actor.animator, form.kind, treatment))
		for tilt: Vector3 in [Vector3.ZERO, Vector3(0.08, 0, -0.08), Vector3(-0.09, 0, 0.11)]:
			floor_body.rotation = tilt
			await physics_frame
			await physics_frame
			assert(check_pose(actor, floor_body, "Walk", {}, treatment))
			assert(check_pose(actor, floor_body, "Run", {}, treatment))
			for group: int in gestures:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(check_pose(actor, floor_body, gestures[group], game.last_mobile_actions[SERIAL], treatment))
		actor.free()
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and int(corpse.get_meta("native_hue")) == hue)
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	game.free()
	floor_body.free()
	print(form.batch, ": 18 decoded fidgets, 18 gait terrain runs, original tracks and three static corpse hues")
	quit()

func check_pose(actor: Node3D, plane: StaticBody3D, clip: String, packet: Dictionary, treatment: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var hand := rig.find_bone(form.hand)
	var head := rig.find_bone(form.head)
	assert(hand >= 0 and head >= 0)
	var native_root := actor.global_transform
	player.stop()
	actor.play(clip if packet.is_empty() else "Idle", 0.0)
	player.advance(0.0)
	for frame in 60:
		actor._physics_process(1.0 / 60.0)
	var duration := player.current_animation_length
	if not packet.is_empty():
		assert(actor.receive_action(packet) and actor.current_clip == clip)
		duration = actor.action_remaining
	var gap := INF
	var reach := -INF
	var delta := duration / 72.0
	for frame in 73:
		player.advance(0.0 if frame == 0 else delta)
		actor._physics_process(delta)
		update_contact(actor, delta)
		assert(not actor.contact.contacts.is_empty() and actor.global_transform.is_equal_approx(native_root))
		var wrist := rig.to_global(rig.get_bone_global_pose(hand).origin)
		var skull := rig.to_global(rig.get_bone_global_pose(head).origin)
		reach = maxf(reach, wrist.y - skull.y)
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.basis.y))
	if not packet.is_empty():
		actor._process(duration + 0.001)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == "Idle")
	print(treatment, " ", clip, " plane ", plane.rotation, " floor and wrist above skull ", [gap, reach])
	return gap >= -0.02 and (packet.is_empty() or (reach >= float(form.height) if clip == form.high else reach <= -0.4))
