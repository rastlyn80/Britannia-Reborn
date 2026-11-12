# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceDarkHorseVisual.gd"
## The original Ethereal horse artwork is worn through the standard horse proxy.

const OpaqueCoat := preload("res://Presentation/OstardSurface.gdshader")
const WarManifest := Art + "original-war-horses.json"
const EtherealBody := 200
const EtherealItem := 0x3eaa
const PackBody := 291
const BritannianBody := 118
const EnhancedClips := {
	1: "HorseCombatIdle", 2: "Death", 3: "Death2", 4: "HorseRearStrike", 10: "HorseHeadRecoil",
	12: "HorseRearCast", 15: "HorseForelegGuard", 25: "Idle", 26: "HorseQuietNod",
	27: "HorseHighFidget", 28: "HorseAlert",
}
const FormsByBody := {
	117: ["silver-steed-breath.scn", 0x3ea8, "", "silver"],
	BritannianBody: ["war-horse-enhanced.scn", 0x3eb2, "", "true_britannians"],
	119: ["war-horse-enhanced.scn", 0x3eb1, "horse-119.png", "council_of_mages"],
	120: ["war-horse-enhanced.scn", 0x3eaf, "horse-120.png", "minax"],
	121: ["war-horse-enhanced.scn", 0x3eb0, "horse-121.png", "shadowlords"],
	EtherealBody: ["silver-steed-breath.scn", EtherealItem, "horse-115.png", "ethereal"],
	PackBody: ["pack-horse-enhanced.scn", -1, "", "pack"],
}

static var war_scenes: Dictionary = {}
static var war_atlases: Dictionary = {}
var alternate_atlas: Texture2D
var original_death: Animation
var enhanced_side_fall := false
var flags_known := false


static func configure_war_horses(enabled: bool) -> void:
	war_scenes.clear()
	war_atlases.clear()
	if not enabled or not FileAccess.file_exists(WarManifest):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(WarManifest))
	if not manifest is Dictionary or int(manifest.get("schema", 0)) != 1:
		return
	var verified_scenes := {}
	for body: int in FormsByBody:
		var entry: Array = FormsByBody[body]
		var scene: String = entry[0]
		if not verified_scenes.has(scene):
			verified_scenes[scene] = verified_member(manifest, scene) and ResourceLoader.exists(Art + scene, "PackedScene")
		if not verified_scenes[scene]:
			continue
		var atlas: String = entry[2]
		if not atlas.is_empty():
			if not verified_member(manifest, atlas):
				continue
			var image := Image.load_from_file(Art + atlas)
			if image == null or image.is_empty():
				continue
			if image.generate_mipmaps() != OK:
				continue
			war_atlases[body] = ImageTexture.create_from_image(image)
		war_scenes[body] = entry


static func verified_member(manifest: Dictionary, member: String) -> bool:
	var expected := str(manifest.get(member, ""))
	return expected.length() == 64 and FileAccess.get_sha256(Art + member) == expected


static func selected_war_horse(body: int, item: int) -> bool:
	if not war_scenes.has(body):
		return false
	if body == EtherealBody:
		return item == EtherealItem
	var expected: int = war_scenes[body][1]
	return item == 0 or (item > 0 and item == expected)


static func create_war_horse(body: int) -> Node3D:
	var actor := new()
	actor.configure_candidate(body)
	return actor


func configure_candidate(body: int, scene := "") -> void:
	var entry: Array = war_scenes[body]
	source_body = body
	kind = entry[3]
	alternate_atlas = war_atlases.get(body)
	form = {"kind": kind, "scene": entry[0] if scene.is_empty() else scene, "item": entry[1],
		"seat_joint": "spine1", "saddle": Vector3(0., 1.37, .04), "mouth": Vector3(0., 1.40, 1.08),
		"stirrup": Vector3(.32, -.61, .13)}
	if body == EtherealBody:
		form["spectral_tint"] = Color("c0d9ea")


func _ready() -> void:
	super._ready()
	original_death = animator.get_animation("Death")


func set_hue(value: int) -> void:
	hue = value
	if model == null:
		return
	var spectral := form.has("spectral_tint")
	var palette: Texture2D = null if spectral and hue == 0x4001 else Hues.palette(hue)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = SpectralCoat if spectral else OpaqueCoat
			material.set_shader_parameter("albedo_texture", alternate_atlas if alternate_atlas != null else source.albedo_texture)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (hue & 0x8000) != 0)
			material.set_shader_parameter("skin_roughness", .83)
			if spectral:
				material.set_shader_parameter("spectral_tint", form.spectral_tint)
			mesh.set_surface_override_material(surface, material)


static func enhanced_group(body: int, type: int, subaction: int, variation: int, flags: int) -> int:
	if body not in [BritannianBody, PackBody] or variation < 0 or variation > 127 or flags < 0:
		return -1
	var pack := body == PackBody
	var combat := (flags & 0x40) != 0
	match type:
		0:
			return -1 if pack and subaction in [1, 2, 9] else 4
		1:
			return 15 if pack else -1
		2:
			return 15
		3:
			return 2 + (variation % 2)
		4:
			return 10
		5:
			return 27 if combat and (pack or variation % 2 == 1) else 26
		8:
			return 28
		11:
			return 12 if pack else 4
		14, 15:
			return -1 if pack else 25
	return -1


func receive_enhanced_action(request: Dictionary, flags: int) -> bool:
	if dead or native_mount_item != 0 or request.get("protocol") != "new" or int(request.get("body", 0)) != source_body:
		return false
	var group := enhanced_group(source_body, int(request.get("type", -1)),
		int(request.get("subaction", -1)), int(request.get("variation", -1)), flags)
	if not EnhancedClips.has(group):
		return false
	var clip: String = EnhancedClips[group]
	if group in [2, 3]:
		select_side_fall(group == 2)
		current_clip = clip
		dead = true
		harness.hide()
		reins.hide()
		fall.accept_action(self)
	start_fitted_clip(clip, request)
	return true


func set_native_combat_flags(flags: int) -> void:
	var entering := flags_known and (source_flags & 0x40) == 0 and (flags & 0x40) != 0
	super.set_native_combat_flags(flags)
	flags_known = flags >= 0
	if source_body == BritannianBody and entering and not dead and native_mount_item == 0 and action_remaining <= 0.:
		start_fitted_clip("HorseAlert", {})


func play_gait(moving: bool, speed: float) -> void:
	var combat_idle := source_body in [BritannianBody, PackBody] and not moving and native_mount_item == 0 \
		and (source_flags & 0x40) != 0 and not dead and action_remaining <= 0. and current_clip != "LieDown"
	if not combat_idle:
		super.play_gait(moving, speed)
		return
	if current_clip != "HorseCombatIdle":
		current_clip = "HorseCombatIdle"
		contact.enabled = true
		animator.speed_scale = 1.
		play(current_clip, .18)


func select_side_fall(enhanced: bool) -> void:
	if enhanced_side_fall == enhanced:
		return
	var library := animator.get_animation_library("")
	var animation := library.get_animation("HorseSideFall") if enhanced else original_death
	library.remove_animation("Death")
	library.add_animation("Death", animation)
	enhanced_side_fall = enhanced


func begin_source_death(source: Node3D) -> float:
	select_side_fall(source.enhanced_side_fall)
	return super.begin_source_death(source)


func start_fitted_clip(clip: String, request: Dictionary) -> void:
	current_clip = clip
	contact.enabled = not dead
	var length := animator.get_animation(clip).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.
	animator.play(clip, .12, length / action_remaining)
	animator.seek(0., false)
	if not request.is_empty():
		set_meta("native_action", request.duplicate(true))
