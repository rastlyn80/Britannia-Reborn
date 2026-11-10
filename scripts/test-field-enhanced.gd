# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Dispatch := preload("res://Presentation/EnhancedCreatureActions.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")
const Installed := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Folder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/field-enhanced/"
const Bake := preload("res://../scripts/bake-field-enhanced.gd")
const FieldVisual := preload("res://Presentation/SourceEnhancedFieldVisual.gd")
const RabbitVisual := preload("res://Presentation/SourceEnhancedRabbitVisual.gd")
const RabbitTunnel := preload("res://Presentation/RabbitTunnelPose.gd")
const Slopes := [Vector3.ZERO, Vector3(.14, 0, 0), Vector3(-.14, 0, 0), Vector3(0, 0, .14), Vector3(0, 0, -.14)]
const DoeModes := {"0": {
	"2": ["DoeRearRecoil", "DoeRearRecoil"], "5": ["DoeGlance", "DoeQuietStand"], "8": ["DoeAlert"],
	"11": ["DoeBowThrust", "DoeBowThrust", "DoeBowThrust"], "14": ["DoeQuietStand"], "15": ["DoeQuietStand"],
}, "1": {"5": ["DoeGlance"]}}
const RabbitModes := {"0": {
	"2": ["RabbitQuietCrouch", "RabbitQuietCrouch"], "5": ["RabbitLookAround", "RabbitQuietCrouch"],
	"8": ["RabbitRiseAlert"], "11": ["RabbitSettleFromRear", "RabbitSettleFromRear", "RabbitSettleFromRear"],
	"14": ["RabbitQuietCrouch"], "15": ["RabbitQuietCrouch"],
}, "1": {"5": ["RabbitLookAround"]}}
const SheepModes := {"0": {
	"2": ["SheepQuietStand", "SheepQuietStand"], "5": ["SheepLookDown", "SheepQuietStand"], "8": ["SheepQuietStand"],
	"11": ["SheepQuietStand", "SheepQuietStand", "SheepQuietStand"], "14": ["SheepQuietStand"], "15": ["SheepQuietStand"],
}, "1": {"5": ["SheepLookDown"]}}
const StagModes := {"0": {
	"2": ["StagRearRecoil", "StagRearRecoil"], "5": ["StagAntlerGlance", "StagPawStamp"], "8": ["StagAntlerAlert"],
	"11": ["StagAntlerBow", "StagAntlerBow", "StagAntlerBow"], "14": ["StagQuietStand"], "15": ["StagQuietStand"],
}, "1": {"5": ["StagAntlerGlance"]}}
const Profiles := {237: DoeModes, 205: RabbitModes, 207: SheepModes, 223: SheepModes, 234: StagModes}

class Avatar extends Node3D:
	var horse_visual: Node3D
	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)

func _initialize() -> void:
	create_timer(150.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var bases := {}
	for body: int in Profiles:
		bases[body] = Registry.entry(body)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in Profiles:
		var receipt := await check_body(game, body, bases[body], Profiles[body], installed)
		assert(receipt.has("routes"), "Terrain or pose regression failed for body %d" % body)
		evidence[str(body)] = receipt
	game.free()
	if not installed:
		var file := FileAccess.open(Folder + "field-enhanced-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": evidence, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()

func check_body(game: Node, body: int, base: Dictionary, modes: Dictionary, installed: bool) -> Dictionary:
	var row := Registry.entry(body) if installed else base.duplicate(true)
	if not installed:
		row.enhanced_source_action_groups = modes
		for treatment: String in row.assets:
			row.assets[treatment] = Folder + "%d-%s.scn" % [body, treatment]
	assert(row.enhanced_source_action_groups == modes)
	Registry.entries[body] = row
	var hashes := {}
	var clips := {}
	for kind: String in modes["0"]:
		var choices: Array = modes["0"][kind]
		for variant in choices.size():
			if not clips.has(choices[variant]):
				clips[choices[variant]] = [int(kind), variant]
	if not installed:
		row.archive_grounded_gestures = clips.keys()
	var routes := 0
	var comparisons := 0
	var samples := 0
	var clearance := INF
	var lowest_by_clip := {}
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor: Node3D = Registry.create(body) if installed else (RabbitVisual.new() if body == 205 else FieldVisual.new())
			actor.entry = row
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				var counts := check_routes(avatar, game, body, modes)
				routes += counts.x
				comparisons += counts.y
			for clip: String in clips:
				var selected: Array = clips[clip]
				var gap := sample(avatar, floor, decode(game, body, selected[0], selected[1]), clip)
				lowest_by_clip[clip] = minf(gap, lowest_by_clip.get(clip, INF))
				clearance = minf(clearance, gap)
				samples += 31
			if body == 205 and tilt == Vector3.ZERO:
				check_tunnel_priority(avatar, game)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("static_cadaver") and corpse.get_meta("graphic_id") == 0x2006)
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	Registry.entries[body] = base
	print("FIELD ENHANCED ", body, ": ", routes, " selections, ", comparisons, " Classic comparisons, ",
		samples, " finite terrain poses and three corpse hues; minimum ", clearance, " ", lowest_by_clip)
	assert(clearance > .001, str(lowest_by_clip))
	assert(routes == row.assets.size() * 48 and comparisons == row.assets.size() * 36)
	assert(samples == row.assets.size() * Slopes.size() * clips.size() * 31)
	return {"routes": routes, "classic_comparisons": comparisons, "terrain_poses": samples,
		"minimum_gap": clearance, "corpse_hues": 3, "minimum_by_clip": lowest_by_clip, "scene_sha256": hashes}

func check_routes(avatar: Avatar, game: Node, body: int, modes: Dictionary) -> Vector2i:
	var counts := Vector2i.ZERO
	for flags: int in [0, 0x40]:
		for kind: String in modes["0"]:
			var choices: Array = modes["1" if flags == 0 else "0"].get(kind, modes["0"][kind])
			for variation: int in [0, 1, 2, 127]:
				assert(Dispatch.dispatch(avatar, decode(game, body, int(kind), variation), true, flags))
				assert(avatar.horse_visual.current_clip == choices[variation % choices.size()] and not avatar.horse_visual.dead)
				counts.x += 1
			for variation: int in [0, 128, 255]:
				var packet := decode(game, body, int(kind), variation)
				var result := Classic.dispatch(avatar, packet)
				var clip: String = avatar.horse_visual.current_clip
				assert(Dispatch.dispatch(avatar, packet, variation >= 128, flags) == result)
				assert(avatar.horse_visual.current_clip == clip)
				counts.y += 1
	return counts

func sample(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, expected: String) -> float:
	var actor := avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		skins.append(Ground.skin_points(mesh, rig))
	var anchor: Transform3D = actor.global_transform
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	assert(Dispatch.dispatch(avatar, packet, true, 0x40) and actor.current_clip == expected)
	player.advance(.13)
	var minimum := INF
	for i in 31:
		player.seek(player.current_animation_length * i / 30.0, true)
		for j in 12:
			actor._physics_process(1.0 / 60.0)
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		actor.contact.modification_processed.emit()
		for skin: Dictionary in skins:
			minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
		assert(actor.global_transform.is_equal_approx(anchor) and not actor.contact.contacts.is_empty())
	return minimum

func check_tunnel_priority(avatar: Avatar, game: Node) -> void:
	var rabbit := avatar.horse_visual
	var pose := RabbitTunnel.new()
	pose.name = "NativeTunnelPose"
	pose.start(rabbit)
	for kind: String in RabbitModes["0"]:
		assert(Dispatch.dispatch(avatar, decode(game, 205, int(kind), 0), true, 0x40))
		assert(rabbit.current_clip == "Idle" and rabbit.skeleton.has_node("NativeTunnelPose"))
	assert(Dispatch.dispatch(avatar, decode(game, 205, 3, 0), true, 0x40) and rabbit.dead)

func create_floor(tilt: Vector3) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.rotation = tilt
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, .10, 12.0)
	collider.shape = box
	collider.position.y = -.05
	floor.add_child(collider)
	root.add_child(floor)
	await physics_frame
	await physics_frame
	return floor

func decode(game: Node, serial: int, kind: int, variation: int) -> Dictionary:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(PackedByteArray([0, kind, 0, 0, variation]))
	game._handle(bytes)
	return game.last_mobile_actions[serial]
