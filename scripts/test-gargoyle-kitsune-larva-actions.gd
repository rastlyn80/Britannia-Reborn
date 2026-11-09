extends "res://../scripts/test-mage-lord-tentacle-actions.gd"

const PACKAGE := "gargoyle_kitsune_larva_actions"
const FORMS := [67, 246, 778]
const GROUND := {67: {15:"StoneWingRecoil", 16:"StoneWingRecoil", 18:"StoneArmCheck", 21:"StoneSettle"},
	246: {10:"KitsuneCall"}}
const LARVA := {10:"Hit", 15:"LarvaRecoil", 16:"LarvaRecoil", 17:"Fidget", 18:"LarvaTilt"}
const Geometry := preload("res://Presentation/SkinGeometry.gd")

func install_packages() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/prepared-client.json" % PACKAGE
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == FORMS.size())
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			assert(body in FORMS and row.status == "prepared" and row.family == PACKAGE)
			Registry.entries[body] = row
	else:
		for body: int in FORMS:
			assert(Registry.entry(body).get("classic_gesture_batch") == PACKAGE)

func run() -> void:
	install_packages()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in FORMS:
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
				and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
			if body == 778:
				assert(corpse.find_child("OriginalCards", true, false) != null)
			corpse.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in TREATMENTS:
			for body: int in GROUND:
				sample_ground(session, plane, treatment, body)
		plane.free()
		await physics_frame
	assert(checked == 765)
	print("STONE GARGOYLE AND BAKE KITSUNE: ", checked, " decoded terrain poses")
	for treatment: String in ["original", "modern"]:
		sample_larva(session, treatment)
	var larva := Registry.entry(778)
	assert(larva.assets.original == larva.assets.rounded)
	assert(checked == 1015)
	print("GAZER LARVA: 250 decoded hover poses, original and refined cards, and nine total corpse hues")
	session.free()
	quit()

func create_actor(body: int, treatment: String) -> Node3D:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func exact_saved_keys(body: int, treatment: String) -> void:
	var row := Registry.entry(body)
	var saved := (load(Registry.asset_path(row, treatment)) as PackedScene).instantiate()
	var player := saved.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	Earlier.check_earlier_keys(player, row.classic_gesture_base_assets[treatment])
	saved.free()

func sample_ground(session: Node, plane: StaticBody3D, treatment: String, body: int) -> void:
	var actor := create_actor(body, treatment)
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	if plane.rotation == Vector3.ZERO:
		exact_saved_keys(body, treatment)
	var normal := plane.global_basis.y.normalized()
	var head := rig.find_bone("bip01 head")
	for slot: int in GROUND[body]:
		assert(actor.receive_action(decode(session, body, slot)) and actor.current_clip == GROUND[body][slot])
		assert(not actor.dead)
		player.advance(0.15)
		var start := 0.0
		var peak := -INF
		for sample in 17:
			player.seek(player.current_animation_length * sample / 16.0, true)
			var joint := rig.to_global(rig.get_bone_global_pose(head).origin)
			var height := (joint - plane.global_position).dot(normal)
			if sample == 0:
				start = height
			peak = maxf(peak, height)
			var gap := Ground.minimum_plane_gap(actor.skin, rig, rig.global_transform, plane.global_position, normal)
			assert(actor.global_transform == Transform3D.IDENTITY and gap >= 0.0015)
			checked += 1
		if body == 246:
			assert(peak - start > 0.09, "Classic group 10 raises the Kitsune's head")
	if body == 67:
		for slot: int in [19, 20]:
			assert(actor.receive_action(decode(session, body, slot)))
			assert(actor.current_clip == ("Fly" if slot == 19 else "TakeOff") and not actor.contact.enabled)
	actor.free()

func sample_larva(session: Node, treatment: String) -> void:
	var actor := create_actor(778, treatment)
	actor.position = Vector3(2.2, 0.94, 1.4)
	var anchor := actor.global_transform
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	assert(rig.get_bone_count() == 126)
	var skins: Array[Node] = actor.model.find_children("*", "MeshInstance3D", true, false)
	assert(skins.size() == (1 if treatment == "original" else 2))
	exact_saved_keys(778, treatment)
	var keys := {}
	for group: int in LARVA:
		player.stop()
		assert(actor.receive_action(decode(session, 778, group)) and actor.current_clip == LARVA[group])
		player.advance(0.15)
		var sample: Array[Quaternion] = []
		for frame in 25:
			player.seek(player.current_animation_length * frame / 24.0, true)
			rig.force_update_all_bone_transforms()
			for mesh: MeshInstance3D in skins:
				var bounds := Geometry.deformed_bounds(mesh, rig)
				assert(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length() > 0.1)
			assert(actor.global_transform == anchor and actor.native_hue == 0x8035 and actor.native_body == 778)
			sample.append(rig.get_bone_pose_rotation(0))
			checked += 1
		keys[group] = sample
	assert(keys[15] == keys[16] and keys[10] != keys[15] and keys[17] != keys[18])
	actor.free()
