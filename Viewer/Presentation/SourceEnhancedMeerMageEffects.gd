# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/EnhancedCreatureEffects.gd"

const Mage := preload("SourceEnhancedMeerMageVisual.gd")
const Graphic := 0x091c
const Particle := 9539
const Dispersed := 1071925
const CloudName := "MeerMageInsectSwarm"


class Swarm extends MultiMeshInstance3D:
	const Count := 24
	const Life := 8.5
	static var insect: ArrayMesh
	var elapsed := 0.0
	var remaining := Life

	func _ready() -> void:
		if insect == null:
			insect = make_insect()
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = insect
		multimesh.instance_count = Count
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_process(0.0)

	func _process(delta: float) -> void:
		remaining -= delta
		if remaining <= 0.0:
			queue_free()
			return
		elapsed += delta
		for index in Count:
			var t := elapsed * (3.1 + float(index % 6) * .36) + float(index) * 2.399963
			var radius := .27 + float(index % 9) * .047
			var height := .41 * sin(t * .73 + index) + .12 * sin(t * 2.43)
			var point := Vector3(radius * cos(t), height, radius * sin(t))
			var tangent := Vector3(-sin(t), .48 * cos(t * .73 + index), cos(t)).normalized()
			var heading := Basis.looking_at(tangent, Vector3.UP)
			var roll := Basis(Vector3.BACK, .60 * sin(elapsed * 28.0 + index))
			multimesh.set_instance_transform(index, Transform3D(heading * roll, point))

	static func make_insect() -> ArrayMesh:
		var shape := SurfaceTool.new()
		shape.begin(Mesh.PRIMITIVE_TRIANGLES)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = .64
		shape.set_material(material)
		var front := Vector3(0, 0, -.025)
		var rear := Vector3(0, 0, .031)
		var top := Vector3(0, .011, 0)
		var bottom := Vector3(0, -.008, 0)
		for side in [-1, 1]:
			var flank := Vector3(side * .011, 0, 0)
			shape.set_color(Color("583728"))
			for point: Vector3 in [front, flank, top, top, flank, rear, front, bottom, flank, bottom, rear, flank]:
				shape.add_vertex(point)
			shape.set_color(Color("bdad88"))
			for point: Vector3 in [Vector3(side * .006, .003, -.006), Vector3(side * .033, .012, -.017),
					Vector3(side * .024, .008, .019), Vector3(side * .006, .003, -.006),
					Vector3(side * .024, .008, .019), Vector3(side * .005, .004, .014)]:
				shape.add_vertex(point)
		shape.generate_normals()
		return shape.commit()


func configure(world_scene: Node3D) -> void:
	super.configure(world_scene)
	scene.game.module("messages").localized_speech.connect(on_localized_speech)
	scene.game.module("player").death_animation.connect(on_death)


func present(effect: Dictionary) -> void:
	if scene == null or scene.game.phase != "world" or not is_swarm(effect):
		super.present(effect)
		return
	var serial := int(effect.target if int(effect.target) else effect.source)
	var avatar := scene.avatars.get(serial) as Avatar
	if avatar == null:
		super.present(effect)
		return
	var cloud := avatar.get_node_or_null(CloudName) as Swarm
	if cloud == null:
		cloud = Swarm.new()
		cloud.name = CloudName
		avatar.add_child(cloud)
		cloud.position.y = 1.03
	cloud.remaining = Swarm.Life


static func is_swarm(effect: Dictionary) -> bool:
	return effect.kind == "fixed_mobile" and int(effect.graphic) == Graphic and int(effect.speed) == 10 \
		and int(effect.duration) == 180 and (not effect.has("tile") or int(effect.tile) == Particle and int(effect.layer) == 3)


func on_localized_speech(serial: int, body: int, kind: int, cliloc: int) -> void:
	if scene.game.phase != "world":
		return
	if cliloc == Dispersed:
		clear_swarm(serial)
		return
	if body != 770 or kind != 0 or cliloc not in Mage.ForestCalls:
		return
	var avatar := scene.avatars.get(serial) as Avatar
	if avatar != null and avatar.horse_visual is Mage:
		avatar.horse_visual.start_forest_call(cliloc)


func on_death(serial: int, _corpse: int) -> void:
	clear_swarm(serial)


func clear_swarm(serial: int) -> void:
	var avatar := scene.avatars.get(serial) as Avatar
	if avatar == null:
		return
	var cloud := avatar.get_node_or_null(CloudName)
	if cloud != null:
		cloud.queue_free()
