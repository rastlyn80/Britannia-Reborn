# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceDarkHorseVisual.gd"
## Body 793 is the same native visual for all four constructors.

const SkeletalCoat := preload("res://Presentation/SourceSkeletalHorseSurface.gdshader")
const Body := 793
const Item := 0x3ebb
const Scene := "skeletal-mount-enhanced.scn"
const ManifestPath := Art + "skeletal-mount.json"
const DistinctClassic := {6: "Attack2", 10: "Fidget2"}
const Enhanced := {
	1: "SkeletalCombatIdle", 2: "Death", 3: "Death2", 4: "SkeletalRearStrike", 10: "Hit",
	12: "SkeletalRearCast", 15: "SkeletalForelegGuard", 22: "Walk", 24: "Run", 25: "Idle",
	26: "SkeletalQuietNod", 27: "SkeletalHighFidget", 28: "SkeletalAlert",
}

static var source_available := false
var original_death: Animation
var enhanced_side_fall := false
var flags_known := false


static func configure_skeletal(enabled: bool) -> void:
	source_available = false
	if not enabled or not FileAccess.file_exists(ManifestPath):
		return
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(ManifestPath))
	if not record is Dictionary or int(record.get("schema", 0)) != 1:
		return
	var expected := str(record.get(Scene, ""))
	source_available = expected.length() == 64 and FileAccess.get_sha256(Art + Scene) == expected \
		and ResourceLoader.exists(Art + Scene, "PackedScene")


static func selected_skeletal(body: int, item: int) -> bool:
	return source_available and body == Body and item in [0, Item]


static func create_skeletal() -> Node3D:
	var actor := new()
	actor.configure_candidate(Body, Scene)
	return actor


func configure_candidate(body: int, scene := Scene) -> void:
	source_body = body
	kind = "skeleton"
	form = {"kind": kind, "scene": scene, "item": Item,
		"seat_joint": "spine1", "saddle": Vector3(0., 1.44, .035), "mouth": Vector3(0., 1.35, 1.40),
		"stirrup": Vector3(.32, -.61, .13)}


func _ready() -> void:
	super._ready()
	original_death = animator.get_animation("Death")


func set_hue(value: int) -> void:
	hue = value
	if model == null:
		return
	var palette: Texture2D = Hues.palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = SkeletalCoat
			material.set_shader_parameter("albedo_texture", source.albedo_texture)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
			mesh.set_surface_override_material(surface, material)


func receive_action(request: Dictionary) -> bool:
	var clip := str(DistinctClassic.get(int(request.get("action", -1)), "")) if request.get("protocol") == "classic" else ""
	if clip.is_empty():
		return super.receive_action(request)
	if dead or not animator.has_animation(clip):
		return false
	start_clip(clip, request)
	return true


static func enhanced_group(type: int, variation: int, flags: int) -> int:
	if variation < 0 or variation > 127 or flags < 0:
		return -1
	match type:
		0:
			return 4
		2:
			return 15
		3:
			return 2 + (variation % 2)
		4:
			return 10
		5:
			return 27 if (flags & 0x40) != 0 and variation % 2 == 1 else 26
		8:
			return 28
		11:
			return 12
		14, 15:
			return 25
	return -1


func receive_enhanced_action(request: Dictionary, flags: int) -> bool:
	if dead or native_mount_item != 0 or request.get("protocol") != "new" or int(request.get("body", 0)) != Body:
		return false
	var group := enhanced_group(int(request.get("type", -1)), int(request.get("variation", -1)), flags)
	if not Enhanced.has(group):
		return false
	if group in [2, 3]:
		select_side_fall(group == 2)
		current_clip = Enhanced[group]
		dead = true
		harness.hide()
		reins.hide()
		fall.accept_action(self)
	start_clip(Enhanced[group], request)
	return true


func set_native_combat_flags(flags: int) -> void:
	var entering := flags_known and (source_flags & 0x40) == 0 and (flags & 0x40) != 0
	super.set_native_combat_flags(flags)
	flags_known = flags >= 0
	if entering and not dead and native_mount_item == 0 and action_remaining <= 0.:
		start_clip("SkeletalAlert", {})


func play_gait(moving: bool, speed: float) -> void:
	if not moving and not dead and native_mount_item == 0 and (source_flags & 0x40) != 0 \
			and action_remaining <= 0. and current_clip != "LieDown":
		if current_clip != "SkeletalCombatIdle":
			current_clip = "SkeletalCombatIdle"
			contact.enabled = true
			animator.speed_scale = 1.
			play(current_clip, .18)
		return
	super.play_gait(moving, speed)


func select_side_fall(enhanced: bool) -> void:
	if enhanced_side_fall == enhanced:
		return
	var library := animator.get_animation_library("")
	var animation := library.get_animation("SkeletalSideFall") if enhanced else original_death
	library.remove_animation("Death")
	library.add_animation("Death", animation)
	enhanced_side_fall = enhanced


func begin_source_death(source: Node3D) -> float:
	select_side_fall(source.enhanced_side_fall)
	return super.begin_source_death(source)


func start_clip(clip: String, request: Dictionary) -> void:
	current_clip = clip
	contact.enabled = not dead
	var length := animator.get_animation(clip).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.0
	animator.play(clip, .12, length / action_remaining)
	animator.seek(0.0, false)
	if not request.is_empty():
		set_meta("native_action", request.duplicate(true))
