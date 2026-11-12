# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/EagleVisual.gd"

const TerrainFall := preload("res://Presentation/CougarTerrainFall.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Wings := preload("res://Presentation/SourceEagleWingClearance.gd")
const AtlasSurface := preload("res://Presentation/CreatureCutoutSurface.gdshader")
const Hues := preload("res://Presentation/HumanHue.gd")
const Probes := [Vector2(-1.15, -.7), Vector2(-1.15, .7), Vector2(1.15, -.7), Vector2(1.15, .7),
	Vector2(-1.15, 0), Vector2(1.15, 0), Vector2(0, -.86), Vector2(0, .86)]
const WingActions := ["Attack", "Fidget", "TakeOff", "Fly", "Land", "AirAttack", "AirHit",
	"EagleWingBeat", "AirEagleWingBeat"]
const ClassicIdleGroups := [2, 3, 4, 9, 10]
const IdleClips := ["Idle", "Eat", "Alert", "Fidget", "Fidget2"]
var terrain := TerrainFall.new()
var terrain_lift := 0.0
var ground_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
var wings := Wings.new()


func _init() -> void:
	fall = terrain


func _ready() -> void:
	super._ready()
	skeleton.add_child(wings)
	wings.active = false
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	terrain.skin = Ground.skin_points(mesh, skeleton)
	wings.bind(terrain.skin)
	animator.mixer_applied.connect(settle_wings)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleClips:
		action_remaining = 0.0
		if pending_ground_clip in IdleClips and pending_ground_clip not in entry.get("archive_grounded_gestures", []):
			pending_ground_clip = ""
			transition_remaining = 0.0
			flight_state = "ground"
	super.play_gait(moving, speed)
	use_flight_cycle()


func _process(delta: float) -> void:
	super._process(delta)
	use_flight_cycle()


func receive_action(request: Dictionary) -> bool:
	if not dead and wanted_moving and request.get("protocol") == "classic" and request.get("action") in ClassicIdleGroups:
		return true
	return super.receive_action(request)


func _physics_process(delta: float) -> void:
	if dead:
		return
	release_ground_lift()
	super._physics_process(delta)
	var support: Dictionary = contact.contacts.get(0, {})
	if support.is_empty():
		support = terrain.floor_under(self)
	if not support.has("collider"):
		terrain.plane = {}
		terrain.split = false
		return
	terrain.remember_floor(self, support)
	terrain.split = spans_treads(support)
	settle_living()


func spans_treads(support: Dictionary) -> bool:
	var space := get_world_3d().direct_space_state
	var normal: Vector3 = support.normal
	for offset: Vector2 in Probes:
		var point := to_global(Vector3(offset.x, 0.0, offset.y))
		ground_ray.from = Vector3(point.x, global_position.y + .65, point.z)
		ground_ray.to = Vector3(point.x, global_position.y - .65, point.z)
		var hit := space.intersect_ray(ground_ray)
		if not hit.is_empty() and hit.normal.y > .75 and (normal.dot(hit.normal) < .995
				or absf(normal.dot(hit.position - support.position)) > .018):
			return true
	return false


func release_ground_lift() -> void:
	model.global_position.y -= terrain_lift
	terrain_lift = 0.0


func settle_wings() -> void:
	if not dead and terrain.split and not terrain.plane.is_empty() and animator.assigned_animation in WingActions:
		release_ground_lift()
		wings.clear_treads(float(terrain.plane.position.y))
	settle_living()


func settle_living() -> void:
	if dead or terrain.plane.is_empty():
		return
	release_ground_lift()
	skeleton.force_update_all_bone_transforms()
	var normal: Vector3 = terrain.plane.normal
	var gap := (terrain.step_gap(skeleton) if terrain.split
		else Ground.minimum_plane_gap(terrain.skin, skeleton, skeleton.global_transform, terrain.plane.position, normal))
	if not is_finite(gap):
		return
	terrain_lift = maxf(0.0, (.003 - gap) / (1.0 if terrain.split else normal.y))
	model.global_position.y += terrain_lift


func use_flight_cycle() -> void:
	if dead or flight_state != "air" or not wanted_moving or action_remaining > 0.0:
		return
	if current_clip in ["Walk", "Run"] and animator.assigned_animation != "Fly":
		animator.play("Fly", .12)
		set_meta("rendered_action_clip", "Fly")


func begin_death_from(source: Node3D) -> float:
	var airborne: bool = source.flight_state != "ground" or str(source.animator.assigned_animation).begins_with("Air")
	terrain.split = source.terrain.split
	return fall.begin_from_source(self, source, source.fall, airborne)


func set_hue(value: int) -> void:
	hue = value
	if model == null:
		return
	var palette := Hues.palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = AtlasSurface
			material.set_shader_parameter("albedo_texture", original.albedo_texture)
			material.set_shader_parameter("source_alpha_texture", original.albedo_texture)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
			material.set_shader_parameter("detail_strength", detail if treatment == "modern" else 0.0)
			mesh.set_surface_override_material(surface, material)
