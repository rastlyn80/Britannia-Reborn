extends SceneTree

const MODELS := {
	"devourer_lion_hiryu/devourer": "DevourerMouthCheck",
	"champions/dragons_dragon_retro_red": "RikktorTailCheck",
	"aos_armed/shadow_knight": "ShadowKnightGlance",
}
const TAIL := ["bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3"]
const WINGS := ["box20", "box01", "dummy-l_wing", "dummy-r_wing"]
const GLANCE := ["bip01 head", "bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand"]

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var forms := {}
	for stem: String in MODELS:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := "res://local-art/creatures/%s-%s.gltf" % [stem, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var donor := player.get_animation("Fidget")
			var label: String = MODELS[stem]
			var base := donor if label == "DevourerMouthCheck" else player.get_animation("Idle")
			var motion := base.duplicate(true) as Animation
			motion.length = 0.78 if label == "DevourerMouthCheck" else 0.87
			motion.loop_mode = Animation.LOOP_NONE
			for track in motion.get_track_count():
				var first: Variant = base.track_get_key_value(track, 0)
				for key in range(motion.track_get_key_count(track) - 1, -1, -1):
					motion.track_remove_key(track, key)
				if label == "DevourerMouthCheck":
					resample_mouth(motion, donor, track)
				else:
					resample_gesture(motion, donor, track, first, label)
			assert(player.get_animation_library("").add_animation(label, motion) == OK)
			var packed := PackedScene.new()
			assert(packed.pack(model) == OK)
			var output := "res://local-art/creatures/%s-slot11-%s.scn" % [stem, treatment]
			assert(ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
			treatments[treatment] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(output)}
			model.free()
		forms[stem.get_file()] = treatments
	var receipt := FileAccess.open("res://../work/creatures/mul-motion-review/late-classic-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "forms": forms}))
	receipt.close()
	print("DEVOURER, RIKKTOR AND SHADOW KNIGHT: nine source scenes with separate Classic 11 motions")
	quit()

func resample_mouth(motion: Animation, donor: Animation, track: int) -> void:
	for sample in 115:
		var phase := float(sample) / 114.0
		# The short source window opens the torso. Return along that same
		# path so the original rib and front-limb relationships are kept.
		var time := donor.length * 0.26 * smoothstep(0.0, 0.32, phase) * (1.0 - smoothstep(0.46, 1.0, phase))
		var target := phase * motion.length
		match donor.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				motion.position_track_insert_key(track, target, donor.position_track_interpolate(track, time))
			Animation.TYPE_ROTATION_3D:
				motion.rotation_track_insert_key(track, target, donor.rotation_track_interpolate(track, time))
			Animation.TYPE_SCALE_3D:
				motion.scale_track_insert_key(track, target, donor.scale_track_interpolate(track, time))
			_:
				assert(false, "Unexpected Devourer source track type")

func resample_gesture(motion: Animation, donor: Animation, track: int, first: Variant, label: String) -> void:
	var path := motion.track_get_path(track)
	var joint := str(path.get_concatenated_subnames())
	var dragon := label == "RikktorTailCheck"
	var joints := TAIL + WINGS if dragon else GLANCE
	if motion.track_get_type(track) != Animation.TYPE_ROTATION_3D or joint not in joints:
		motion.track_insert_key(track, 0.0, first)
		return
	var donor_track := donor.find_track(path, Animation.TYPE_ROTATION_3D)
	assert(donor_track >= 0)
	var start: Quaternion = first
	var donor_start := donor.rotation_track_interpolate(donor_track, 0.0).inverse()
	var amplitude := 0.62 if not dragon or joint in TAIL else 0.27
	for sample in 115:
		var phase := float(sample) / 114.0
		var time := donor.length * phase
		var strength := amplitude * (1.0 - smoothstep(0.90, 1.0, phase))
		var change := donor_start * donor.rotation_track_interpolate(donor_track, time)
		motion.rotation_track_insert_key(track, motion.length * phase,
			(start * Quaternion.IDENTITY.slerp(change, strength)).normalized())
