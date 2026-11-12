# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceMagicalEquine.gd"

const Coat := preload("res://Presentation/SourceDarkHorseCoat.gdshader")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const NativeItems := {116: 0x3ea7, 178: 0x3ea9, 179: 0x3eb7, 190: 0x3e9e}
const Scenes := {false: "nightmare-breath.scn", true: "firesteed-breath.scn"}
const DarkManifest := Art + "dark-horses.json"
const Breath := "FireBreath"

static var available_scenes := {}
var source_body: int
var live_shift := Vector3.ZERO


static func configure_sources(enabled: bool) -> void:
	available_scenes.clear()
	if not enabled or not FileAccess.file_exists(DarkManifest):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(DarkManifest))
	if not manifest is Dictionary or int(manifest.get("schema", 0)) != 1:
		return
	for scene: String in Scenes.values():
		var path := Art + scene
		var digest := str(manifest.get(scene, ""))
		if digest.length() == 64 and FileAccess.get_sha256(path) == digest and ResourceLoader.exists(path, "PackedScene"):
			available_scenes[scene] = true


static func accepts_source(body: int, item: int) -> bool:
	return NativeItems.has(body) and (item == 0 or item == NativeItems[body]) \
		and available_scenes.has(Scenes[body == 190])


static func create_source(body: int) -> Node3D:
	var actor := new()
	actor.configure_candidate(body, Scenes[body == 190])
	return actor


func configure_candidate(body: int, scene := "") -> void:
	source_body = body
	kind = "fire" if body == 190 else "nightmare"
	if scene.is_empty():
		scene = "firesteed-source.scn" if body == 190 else "nightmare-source.scn"
	form = {"kind": kind, "scene": scene, "item": NativeItems[body],
		"seat_joint": "spine1", "saddle": Vector3(0., 1.37, .04), "mouth": Vector3(0., 1.40, 1.08),
		"stirrup": Vector3(.32, -.61, .13)}


func _ready() -> void:
	super._ready()
	# Keep the recovered hoof poses. The parent still samples terrain for tilt.
	contact.active = false


func _settle_fall() -> void:
	model.position -= live_shift
	live_shift = Vector3.ZERO
	if dead:
		super._settle_fall()
		return
	var support := fall.floor_under(self)
	if not support.has("collider"):
		return
	if fall.skin.is_empty():
		fall.remember_floor(self, support)
	skeleton.force_update_all_bone_transforms()
	var normal: Vector3 = support.normal
	var gap := Ground.minimum_plane_gap(fall.skin, skeleton, skeleton.global_transform, support.position, normal)
	if gap < .002:
		var original := model.position
		model.global_position.y += (.002 - gap) / normal.y
		live_shift = model.position - original


func begin_source_death(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	harness.hide()
	reins.hide()
	return fall.begin_from_source(self, source, source.fall, source.live_shift)


func set_hue(value: int) -> void:
	hue = value
	if model == null:
		return
	var palette: Texture2D = Hues.palette(hue)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = Coat
			material.set_shader_parameter("albedo_texture", source.albedo_texture)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (hue & 0x8000) != 0)
			material.set_shader_parameter("fire_steed", kind == "fire")
			mesh.set_surface_override_material(surface, material)


func receive_action(request: Dictionary) -> bool:
	# ModernUO FireBreath uses this five-frame forward one-shot before the
	# server emits the projectile at 1.3 seconds.
	var native_breath: bool = request.get("protocol") == "classic" and int(request.get("action", -1)) == 12 \
		and int(request.get("frames", 0)) == 5 and int(request.get("repeat_count", 0)) == 1 \
		and int(request.get("delay", -1)) == 0 and not request.get("reverse", false) and not request.get("repeat", false)
	if not native_breath or not animator.has_animation(Breath):
		return super.receive_action(request)
	if dead or native_mount_item != 0:
		return false
	current_clip = Breath
	action_remaining = animator.get_animation(Breath).length
	contact.enabled = true
	animator.speed_scale = 1.0
	animator.play(Breath, .08)
	animator.seek(0.0, false)
	set_meta("native_action", request.duplicate(true))
	return true


func fire_breath_origin() -> Variant:
	if dead or current_clip != Breath:
		return null
	var bit := socket("mouth")
	return bit.origin + bit.basis.z * .10
