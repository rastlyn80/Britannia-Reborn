extends SceneTree

const SOURCE := "res://Art/Creatures/Wisp/wisp.scn"
const OUTPUT := "res://local-art/creatures/wisp-distinct-actions.res"
const CANDIDATE := "res://local-art/creatures/wisp-distinct-candidate.scn"
enum Motion {TALL_FLARE, SPLIT_FLICKER, RAY_DRIFT}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var library := AnimationLibrary.new()
	assert(library.add_animation("TallFlare", pulse(Motion.TALL_FLARE)) == OK)
	assert(library.add_animation("SplitFlicker", pulse(Motion.SPLIT_FLICKER)) == OK)
	assert(library.add_animation("RayDrift", pulse(Motion.RAY_DRIFT)) == OK)
	assert(ResourceSaver.save(library, OUTPUT, ResourceSaver.FLAG_COMPRESS) == OK)
	var model := (load(SOURCE) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var existing := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", existing)
	assert(existing.get_animation_list().size() == 16)
	for clip: String in library.get_animation_list():
		assert(existing.add_animation(clip, library.get_animation(clip)) == OK)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, CANDIDATE, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	var receipt := FileAccess.open("res://local-art/creatures/wisp-distinct-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"source": FileAccess.get_sha256(SOURCE), "scene": FileAccess.get_sha256(CANDIDATE),
		"library": FileAccess.get_sha256(OUTPUT), "recipe": FileAccess.get_sha256(get_script().resource_path)}))
	receipt.close()
	print("WISP DISTINCT ACTIONS: two energy reactions and a ray drift")
	quit()

func pulse(motion: Motion) -> Animation:
	var clip := Animation.new()
	clip.length = [0.54, 0.61, 1.28][motion]
	var tall := motion == Motion.TALL_FLARE
	var drift := motion == Motion.RAY_DRIFT
	var center := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(center, NodePath("Rig:EnergyRoot"))
	var tilt := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(tilt, NodePath("Rig:EnergyRoot"))
	var vertical := add_scale_track(clip, "EnergyRoot")
	var rays: Array[int] = []
	for ray in 6:
		rays.append(add_scale_track(clip, "Ray%d" % ray))
	for frame in 61:
		var phase := float(frame) / 60.0
		var swell := sin(PI * phase) ** 2.0
		var stutter := sin(TAU * phase * 2.0) * swell
		var size := Vector3(1.0 - 0.18 * swell, 1.0 + 0.12 * swell, 1.0 - 0.18 * swell) if tall else Vector3.ONE
		clip.position_track_insert_key(center, phase * clip.length, Vector3(0, 0.95 + 0.04 * swell, 0))
		var orientation := Quaternion(Vector3.UP, 0.35 * swell) if drift else Quaternion(Vector3.FORWARD, 0.14 * stutter if not tall else 0.0)
		clip.rotation_track_insert_key(tilt, phase * clip.length, orientation)
		clip.scale_track_insert_key(vertical, phase * clip.length, size)
		for index in rays.size():
			var scale := 1.0
			if tall:
				scale += (0.53 if index < 2 else -0.13) * swell
			elif drift:
				var sweep := cos(TAU * phase - float(index) * PI / 3.0)
				scale += (0.12 if index < 2 else 0.37) * sweep * swell
			else:
				var sign := 1.0 if index % 2 == 0 else -1.0
				scale += (0.22 if index < 2 else 0.29) * sign * stutter
			clip.scale_track_insert_key(rays[index], phase * clip.length, Vector3(1.0, scale, 1.0))
	return clip

func add_scale_track(clip: Animation, name: String) -> int:
	var track := clip.add_track(Animation.TYPE_SCALE_3D)
	clip.track_set_path(track, NodePath("Rig:" + name))
	return track
