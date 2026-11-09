extends "res://../scripts/test-bomber-ogre-rune-dopple-actions.gd"

const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const VICTIM := 0x4112
const CADAVER := 0x40012112

class Arena extends Node3D:
	var avatars: Dictionary = {}

class WitnessAvatar extends Node3D:
	var horse_visual: Node3D

var handoffs := 0
var fall_samples := 0
var maximum_jump := 0.0

func run() -> void:
	Registry.load_index()
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var path := "res://../work/creatures/bomber_ogre_rune_dopple_actions/prepared-client.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		for row: Dictionary in rows:
			Registry.entries[int(row.bodies[0].body)] = row
	for tilt: Vector3 in SLOPES:
		var floor := await support(tilt)
		for body: int in [83, 777]:
			var row := Registry.entry(body)
			assert(row.get("classic_gesture_batch" if active else "family") == BATCH)
			for phase: float in [0.23, 0.48, 0.79]:
				witness_fall(floor, body, phase)
		floor.free()
		await physics_frame
	assert(handoffs == 18 and fall_samples == 738 and maximum_jump < 0.015)
	print("OGRE LORD AND DOPPLEGANGER CORPSES: ", handoffs, " decoded alternate handoffs, ", fall_samples,
		" slope poses, maximum landmark transition ", maximum_jump)
	quit()

func witness_fall(floor: StaticBody3D, body: int, phase: float) -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var arena := Arena.new()
	root.add_child(arena)
	var items := Items.new()
	arena.add_child(items)
	items.add_child(items.hint)
	items.session = game
	var deaths := Deaths.new()
	arena.add_child(deaths)
	deaths.configure(arena, game, items)
	deaths.set_process(false)
	var avatar := WitnessAvatar.new()
	arena.add_child(avatar)
	var actor := Registry.create(body)
	avatar.horse_visual = actor
	avatar.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.sample(floor.get_world_3d().direct_space_state, actor.global_position)
	arena.avatars[VICTIM] = avatar
	game.entities[VICTIM] = {"serial": VICTIM, "body": body, "hue": 0x8035, "direction": 4}
	var source_player: AnimationPlayer = actor.animator
	source_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(actor.receive_action(decode(game, VICTIM, 3)) and actor.current_clip == "Death2")
	source_player.advance(0.15)
	var time := source_player.current_animation_length * phase
	source_player.seek(time, true)
	var head_before := head_at(actor)
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[CADAVER] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": body, "hue": 0x8035, "direction": 4}, CADAVER))
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(VICTIM, 4))
	packet.append_array(Wire.uint_be(CADAVER, 4))
	packet.append_array(Wire.uint_be(0, 4))
	game._handle(packet)
	assert(deaths.active.has(VICTIM) and not holder.visible and not avatar.visible)
	var visual: Node3D = deaths.active[VICTIM].visual
	var player: AnimationPlayer = visual.animator
	assert(visual.current_clip == "Death2" and absf(player.current_animation_position - time) < 0.002,
		str([body, phase, visual.current_clip, player.current_animation_position, time]))
	maximum_jump = maxf(maximum_jump, head_at(visual).distance_to(head_before))
	var rig: Skeleton3D = visual.skeleton
	var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := floor.global_basis.y.normalized()
	var anchor := visual.global_transform
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for frame in 41:
		player.seek(lerpf(time, player.current_animation_length, frame / 40.0), true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.global_position, normal)
		assert(is_finite(gap) and gap > -0.001 and visual.global_transform == anchor, str([body, phase, frame, gap]))
		fall_samples += 1
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(VICTIM, 4))
	game._handle(removal)
	arena.avatars.erase(VICTIM)
	avatar.free()
	deaths._process(float(deaths.active[VICTIM].remaining) + 0.1)
	assert(holder.visible and deaths.active.is_empty() and items.corpse_snapshots.has(CADAVER))
	var cadaver := holder.get_node("CorpseVisual") as Node3D
	assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == 0x8035)
	assert(cadaver.get_meta("static_cadaver") and cadaver.get_meta("death_clip") == "Death2")
	assert(cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
	handoffs += 1
	arena.free()
	game.free()

func head_at(actor: Node3D) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin)
