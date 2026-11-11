# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveGestureVisual.gd"

const Ember := preload("FireGargoyleEmberSurface.gdshader")
const Hue := preload("res://Presentation/HumanHue.gd")
const Variants := preload("res://Presentation/CreatureModeZeroVariants.gd")
const Breath := "FireGargoyleFireBreath"

var gait := preload("res://Presentation/UopMonsterGait.gd").new()
var fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var flight_mode := false
var muzzle_head := -1
var muzzle_offset := Vector3.ZERO


func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(fall.settle.bind(self))
	animator.get_animation("Fly").loop_mode = Animation.LOOP_LINEAR
	muzzle_head = skeleton.find_bone("bip01 head")
	var head := skeleton.get_bone_global_rest(muzzle_head)
	var relative := skeleton.global_basis.inverse() * global_basis
	muzzle_offset = head.basis.inverse() * (relative * Vector3(0.0, -.028, .135))


func set_native_combat_flags(flags: int) -> void:
	flight_mode = flags >= 0 and (flags & 4) != 0
	gait.set_flags(flags)


func play_gait(moving: bool, speed: float) -> void:
	if flight_mode:
		if not dead and action_remaining <= 0.0:
			contact.enabled = false
			if current_clip != "Fly":
				current_clip = "Fly"
				animator.speed_scale = 1.0
				play("Fly", .16)
		return
	if not gait.play(self, moving, speed, "FireGargoylePeaceWalk"):
		super.play_gait(moving, speed)


func set_hue(value: int) -> void:
	super.set_hue(value)
	if treatment != "modern" or not is_instance_valid(model):
		return
	var palette := Hue.palette(value)
	for body: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for index in body.mesh.get_surface_count():
			var atlas := body.mesh.surface_get_material(index) as StandardMaterial3D
			if atlas == null or atlas.albedo_texture == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = Ember
			material.set_shader_parameter("albedo_texture", atlas.albedo_texture)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
			body.set_surface_override_material(index, material)


func receive_action(request: Dictionary) -> bool:
	var base := entry
	var windup := is_breath_windup(request)
	if windup:
		entry = entry.merged({"classic_action_categories": entry.classic_action_categories.merged({"12": Breath}, true)}, true)
	elif request.get("protocol") == "new":
		entry = entry_for_new_action(request)
	var accepted := super.receive_action(request)
	entry = base
	if accepted:
		fall.accept_action(self)
	if accepted and windup:
		var length := animator.get_animation(Breath).length
		animator.speed_scale = action_remaining / length
		action_remaining = length
	return accepted


func entry_for_new_action(request: Dictionary) -> Dictionary:
	var type := str(request.get("type"))
	var selected: String = entry.get("new_action_categories", {}).get(type, "")
	if type == "0" and selected in ["FireGargoyleOverheadRake", "FireGargoyleSwoopingClaw"]:
		return entry
	if type == "5" and int(request.get("variation", 0)) == 1:
		# Peace has a single indexed idle gesture. Retain that selection when
		# the optional dispatcher has supplied it for this packet.
		if gait.known and not gait.combat and selected == "FireGargoyleRest":
			return entry
		return entry.merged({"new_action_categories": {"5": "FireGargoyleFlare"}}, true)
	return Variants.entry_for_packet(entry, request)


func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall, source.flight_mode)


func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)


func fire_breath_origin() -> Variant:
	if dead or current_clip != Breath or action_remaining <= 0.0:
		return null
	return skeleton.to_global(skeleton.get_bone_global_pose(muzzle_head) * muzzle_offset)


func is_breath_windup(request: Dictionary) -> bool:
	return request.get("protocol") == "classic" and request.get("action") == 12 \
		and request.get("frames") == 5 and request.get("repeat_count") == 1 \
		and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 0
