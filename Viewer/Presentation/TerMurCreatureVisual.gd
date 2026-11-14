# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Surface := preload("res://Presentation/TerMurConstructSurface.gdshader")
const Hues := preload("res://Presentation/HumanHue.gd")
const Appearance := preload("res://Presentation/GargoyleAppearance.gd")
const LeatherPatterns := {0x302: 0x301, 0x303: 0x304, 0x310: 0x311}
const VollemBreath := "VollemFireBreath"

var flying := false
var flight_lift := 0.0
var ground_offset := 0.0
var equipment := {}
var breath_joint := -1
var breath_muzzle := Vector3.ZERO


func _ready() -> void:
	super._ready()
	ground_offset = model.position.y
	if kind != "vollem":
		return
	breath_joint = skeleton.find_bone("bip01 head")
	var jaw := skeleton.find_bone("bip01 jaw")
	if breath_joint >= 0 and jaw >= 0:
		breath_muzzle = skeleton.get_bone_rest(jaw).origin.normalized()
	var motion: Animation = animator.get_animation("Attack2").duplicate()
	animator.get_animation_library("").add_animation(VollemBreath, motion)


func set_hue(value: int) -> void:
	hue = value
	if model == null:
		return
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible:
			continue
		var graphic := int(mesh.get_meta("ter_mur_equipment", 0))
		var key := equipment_key(graphic, int(mesh.get_meta("ter_mur_layer", 0)))
		var item: Dictionary = equipment.get(key, {})
		if treatment != "modern" and item.is_empty() and native_body not in [666, 667]:
			continue
		set_finish(mesh, int(item.get("hue", 0)) if graphic else value)


func set_finish(mesh: MeshInstance3D, value: int) -> void:
	for index in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(index) as StandardMaterial3D
		if source == null or not source.has_meta("ter_mur_finish"):
			continue
		var finish := source.albedo_color
		var roughness := source.roughness
		var surface_hue := value
		var armor_id := int(source.get_meta("ter_mur_armor_id", 0))
		if armor_id and equipment.has(armor_id):
			var item: Dictionary = equipment[armor_id]
			var cloth := Appearance.Cloth.has(item.id)
			finish = Color("#9d8c6d") if cloth else Color("#40392e")
			roughness = .96 if cloth else .91
			surface_hue = int(item.hue)
		elif native_body in [666, 667] and not mesh.has_meta("ter_mur_equipment"):
			# Native racial skin colours refer to the skin surface as a whole.
			surface_hue &= 0x3fff
		var palette := Hues.palette(surface_hue)
		var material := ShaderMaterial.new()
		material.shader = Surface
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
		material.set_shader_parameter("hue_palette", palette)
		material.set_shader_parameter("use_hue", palette != null)
		material.set_shader_parameter("partial_hue", (surface_hue & 0x8000) != 0)
		material.set_shader_parameter("finish", finish)
		material.set_shader_parameter("roughness", roughness)
		material.set_shader_parameter("metalness", source.metallic)
		mesh.set_surface_override_material(index, material)


func set_equipment(worn: Array) -> void:
	if native_body not in [666, 667]:
		return
	var incoming := {}
	var allowed_horns := Appearance.horn_graphics(native_body == 667)
	for item: Dictionary in worn:
		var graphic := int(item.get("id", 0))
		var layer := int(item.get("layer", 0))
		var region := int(LeatherPatterns.get(graphic, Appearance.Cloth.get(graphic, graphic)))
		if (region in [0x301, 0x304, 0x311, 0x40a, 0x901]
				or layer == 11 and graphic in allowed_horns
				or layer == 16 and native_body == 666 and graphic in Appearance.FacialHorns):
			var key := equipment_key(region, layer if layer in [11, 16] else 0)
			incoming[key] = {"id": graphic, "hue": int(item.get("hue", 0))}
	if incoming == equipment:
		return
	equipment = incoming
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var graphic := int(mesh.get_meta("ter_mur_equipment", 0))
		if graphic:
			mesh.visible = incoming.has(equipment_key(graphic, int(mesh.get_meta("ter_mur_layer", 0))))
	set_hue(native_hue)

func equipment_key(graphic: int, layer: int) -> int:
	return (layer << 16) | graphic


func set_native_combat_flags(flags: int) -> void:
	var next := bool(flags & 4) and animator.has_animation("Fly")
	if flying != next and not dead:
		flying = next
		if action_remaining <= 0.0:
			play_gait(false, 0.0)


func play_gait(moving: bool, speed: float) -> void:
	if not flying:
		super.play_gait(moving, speed)
	elif not dead and action_remaining <= 0.0:
		contact.enabled = false
		animator.speed_scale = 1.0
		if current_clip != "Fly":
			current_clip = "Fly"
			play(current_clip)


func _physics_process(delta: float) -> void:
	if native_body in [666, 667] and not dead:
		flight_lift = move_toward(flight_lift, .36 if flying else 0.0, delta * 1.2)
		if flying or flight_lift > 0.0:
			model.position.y = ground_offset + flight_lift
			return
		if model.position.y > ground_offset:
			model.position.y = ground_offset
	if not flying:
		super._physics_process(delta)


func receive_action(request: Dictionary) -> bool:
	if native_body in [666, 667] and not dead and request.get("protocol") == "classic" \
			and request.get("frames") == 10 and request.get("repeat_count") == 1 \
			and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 0:
		var action := int(request.get("action", -1))
		if action in [60, 61]:
			current_clip = "TakeOff" if action == 60 else "Land"
			contact.enabled = false
			action_remaining = animator.get_animation(current_clip).length
			animator.speed_scale = 1.0
			animator.play(current_clip, .12)
			animator.seek(0.0, false)
			set_meta("native_action", request.duplicate(true))
			return true
	if native_body == 293 and not dead and request.get("protocol") == "classic" \
			and request.get("action") == 12 and request.get("frames") == 5 and request.get("repeat_count") == 1 \
			and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 0:
		current_clip = VollemBreath
		contact.enabled = not flying
		action_remaining = 2.10
		animator.speed_scale = 1.0
		animator.play(VollemBreath, .12, animator.get_animation(VollemBreath).length / action_remaining)
		animator.seek(0.0, false)
		set_meta("native_action", request.duplicate(true))
		return true
	return super.receive_action(request)


func fire_breath_origin() -> Variant:
	if breath_joint < 0 or dead or current_clip != VollemBreath or action_remaining <= 0.0:
		return null
	skeleton.force_update_all_bone_transforms()
	var pose := skeleton.get_bone_global_pose(breath_joint)
	var offset := (skeleton.global_basis * (pose.basis * breath_muzzle)).normalized()
	return skeleton.to_global(pose.origin) + offset * .22
