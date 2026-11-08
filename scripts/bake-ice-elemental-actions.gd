extends "res://../scripts/bake-zombie-actions.gd"

const ICE := {15: "IceArmDraw", 16: "IceForearmGuard", 18: "IceWeightShift"}
const JOINTS := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 head", "bip01 l upperarm",
	"bip01 l forearm", "bip01 r upperarm", "bip01 r forearm"]

func run() -> void:
	var source := Registry.entry(161)
	var row := source.duplicate(true)
	row.assets = {}
	for treatment: String in ["original", "rounded", "modern"]:
		row.assets[treatment] = Registry.asset_path(source, treatment)
	Registry.entries[161] = row
	bake_body(161, "ice-elemental", ICE, ["bake-ice-elemental-actions.gd", "bake-zombie-actions.gd"])
	measure_ground(source.ground_lookup)
	quit()

func measure_ground(source_path: String) -> void:
	var curves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	assert(curves.sample_rate == 960)
	var count := 0
	var pins := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := "res://local-art/creatures/ice-elemental-actions-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var clips: Dictionary = curves.treatments[treatment].clips
		assert(clips.size() == 13)
		for clip: String in ICE.values():
			assert(not clips.has(clip))
			player.play(clip, 0.0)
			player.advance(0.0)
			var length := player.current_animation_length
			var samples := ceili(length * 960.0)
			var positions: Array = []
			for frame in samples + 1:
				var time := length * frame / samples
				player.seek(time, true)
				rig.force_update_all_bone_transforms()
				var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
				assert(is_finite(gap) and absf(gap) < 0.008)
				positions.append([time, -gap])
				count += 1
			clips[clip] = positions
		pins[treatment] = FileAccess.get_sha256(path)
		model.free()
	curves.overlay = {"base_sha256":FileAccess.get_sha256(source_path), "scenes":pins, "samples":count}
	var file := FileAccess.open("res://local-art/creatures/ice-elemental-ground.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(curves, "", true, true))
	file.close()
	print("ICE ELEMENTAL ACTIONS: ", count, " new measured ground samples, thirteen original curves retained per treatment")

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var library := player.get_animation_library("")
	var original := library.get_animation("Idle")
	var seed := original.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: String in JOINTS:
		var path := NodePath("%s:%s" % [rig_path, name])
		if seed.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			var track := seed.add_track(Animation.TYPE_ROTATION_3D)
			seed.track_set_path(track, path)
			seed.rotation_track_insert_key(track, 0.0, rig.get_bone_rest(rig.find_bone(name)).basis.get_rotation_quaternion())
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", seed) == OK)
	var fitted := super.fit_troll(player, rig, skins, slot)
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", original) == OK)
	return fitted

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.06, 0.47, phase) * (1.0 - smoothstep(0.60, 0.98, phase))
	if slot == 18:
		turn_world(rig, "bip01 spine", Vector3.RIGHT, 0.24 * pulse)
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, 0.26 * pulse)
		turn_world(rig, "bip01 spine2", Vector3.UP, -0.23 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, 0.58 * pulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.26 * pulse)
		return
	var guard := slot == 16
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (0.38 if guard else 0.21) * pulse)
	turn_world(rig, "bip01 spine2", Vector3.UP, (-0.18 if guard else 0.24) * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.25 * pulse)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, (-1.52 if guard else -0.84) * pulse)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, (-0.81 if guard else -0.58) * pulse)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.69 * pulse)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.43 * pulse)
