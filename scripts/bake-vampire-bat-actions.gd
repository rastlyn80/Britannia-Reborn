extends SceneTree

const ART := "res://local-art/creatures/vampire_bat/"
const WING := "BatWingCheck"
const SETTLE := "BatSettle"
const POSES := {WING: [0.0, 0.30, 0.67, 0.82, 0.995], SETTLE: [0.0, 0.91, 0.995]}
const WING_JOINTS := ["clavicle", "upperarm", "forearm", "hand", "finger", "wing"]

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var forms := {}
	for treatment in ["original", "rounded", "modern"]:
		var source := ART + "vampire_bat-%s.gltf" % treatment
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for label in [WING, SETTLE]:
			var clip := build_motion(player, rig, label)
			assert(player.get_animation_library("").add_animation(label, clip) == OK)
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var output := ART + "vampire-bat-wings-%s.scn" % treatment
		assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		forms[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		model.free()
	var receipt := FileAccess.open("res://../work/creatures/mul-motion-review/vampire-bat-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "forms": forms}))
	receipt.close()
	print("VAMPIRE BAT: two wing actions across three source treatments")
	quit()

func build_motion(player: AnimationPlayer, rig: Skeleton3D, label: String) -> Animation:
	var result := player.get_animation("Idle").duplicate(true) as Animation
	var donor := player.get_animation("Fidget")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var phases: Array = POSES[label]
	result.length = 0.78 if label == WING else 0.40
	result.loop_mode = Animation.LOOP_NONE
	for track in result.get_track_count():
		var first: Variant = result.track_get_key_value(track, 0)
		clear_keys(result, track)
		result.track_insert_key(track, 0.0, first)
	for joint in rig.get_bone_count():
		var name := rig.get_bone_name(joint)
		if not WING_JOINTS.any(func(term): return term in name):
			continue
		var node := NodePath("%s:%s" % [path, name])
		var from := donor.find_track(node, Animation.TYPE_ROTATION_3D)
		if from < 0:
			continue
		var to := result.find_track(node, Animation.TYPE_ROTATION_3D)
		if to < 0:
			to = result.add_track(Animation.TYPE_ROTATION_3D)
			result.track_set_path(to, node)
		resample(result, to, donor, from, phases)
	if label == WING:
		# The lower wing poses require the body lift from the same source
		# times. The settle instead keeps the source idle body altitude.
		for to in result.get_track_count():
			if result.track_get_type(to) != Animation.TYPE_POSITION_3D:
				continue
			var from := donor.find_track(result.track_get_path(to), Animation.TYPE_POSITION_3D)
			if from >= 0:
				resample(result, to, donor, from, phases)
	return result

func clear_keys(motion: Animation, track: int) -> void:
	for key in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, key)

func resample(target: Animation, to: int, donor: Animation, from: int, phases: Array) -> void:
	clear_keys(target, to)
	for sample in 91:
		var phase := float(sample) / 90.0
		var position := phase * (phases.size() - 1)
		var index := mini(floori(position), phases.size() - 2)
		var start: float = phases[index] * donor.length
		var end: float = phases[index + 1] * donor.length
		var mix := smoothstep(0.0, 1.0, position - index)
		var time := phase * target.length
		if target.track_get_type(to) == Animation.TYPE_ROTATION_3D:
			var a := donor.rotation_track_interpolate(from, start)
			var b := donor.rotation_track_interpolate(from, end)
			target.rotation_track_insert_key(to, time, a.slerp(b, mix))
		else:
			var a := donor.position_track_interpolate(from, start)
			var b := donor.position_track_interpolate(from, end)
			target.position_track_insert_key(to, time, a.lerp(b, mix))
