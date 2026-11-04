extends SceneTree
## Body 267 slot 11: retime one rise and reach from the recovered Misc clip.

const SOURCE := "res://local-art/creatures/late_source/troglodyte-%s.gltf"
const OUTPUT := "res://local-art/creatures/troglodyte-267-reach-trial-%s.scn"
const ANCHORS := [0.0, 0.72, 0.86, 1.09, 1.25]
const LENGTH := 0.60
const SAMPLES := 72

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for treatment in ["original", "rounded", "modern"]:
		if not bake(treatment):
			quit(1)
			return
	quit()

func bake(treatment: String) -> bool:
	var model := (load(SOURCE % treatment) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("")
	var original := library.get_animation("Misc")
	assert(original.length > ANCHORS[-1] and not library.has_animation("Pillage"))
	var motion := Animation.new()
	motion.length = LENGTH
	for track in original.get_track_count():
		var type := original.track_get_type(track)
		assert(type == Animation.TYPE_POSITION_3D or type == Animation.TYPE_ROTATION_3D)
		var target := motion.add_track(type)
		motion.track_set_path(target, original.track_get_path(track))
		for sample in SAMPLES + 1:
			var fraction := float(sample) / SAMPLES
			var phase := fraction * (ANCHORS.size() - 1)
			var left := mini(floori(phase), ANCHORS.size() - 2)
			var source_time := lerpf(ANCHORS[left], ANCHORS[left + 1], phase - left)
			if type == Animation.TYPE_POSITION_3D:
				motion.position_track_insert_key(target, LENGTH * fraction, original.position_track_interpolate(track, source_time))
			else:
				motion.rotation_track_insert_key(target, LENGTH * fraction, original.rotation_track_interpolate(track, source_time))
	assert(library.add_animation("Pillage", motion) == OK)
	var scene := PackedScene.new()
	var saved := scene.pack(model) == OK and ResourceSaver.save(scene, OUTPUT % treatment, ResourceSaver.FLAG_COMPRESS) == OK
	model.free()
	print("TROGLODYTE 267 REACH: ", treatment, ", 73 samples from 56 recovered source tracks")
	return saved
