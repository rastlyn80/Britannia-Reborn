# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceQuadrupedCollapseVisual.gd"

const BowAim := preload("SourceRatmanBowAim.gd")
const Hue := preload("res://Presentation/HumanHue.gd")
const BowSource := "res://local-art/creatures/centaur-bow/weapon-bow-original.gltf"
const BowScale := .60
const Grip := Vector3(-.00065, .0104, -.0045)
const Clearance := .003

static var rest_bow: ArrayMesh
static var rest_arrays: Array
static var string_vertices := PackedInt32Array()
static var string_center := Vector3.ZERO
var bow: MeshInstance3D
var aim := BowAim.new()
var left_grasp: int
var right_grasp: int
var bow_hue := -1
var draw_offset := Vector3.ZERO


func _ready() -> void:
	super._ready()
	left_grasp = skeleton.find_bone("cp_grasp_lhand")
	right_grasp = skeleton.find_bone("cp_grasp_rhand")
	assert(left_grasp >= 0 and right_grasp >= 0)
	aim.bind(self)
	animator.mixer_applied.connect(sync_bow)
	contact.modification_processed.connect(sync_bow)


static func prepare_bow() -> bool:
	if rest_bow != null:
		return true
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(ProjectSettings.globalize_path(BowSource), state) != OK:
		return false
	var imported := document.generate_scene(state)
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		imported.free()
		return false
	var source: Mesh = meshes[0].mesh
	var arrays := source.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var string_indices := PackedInt32Array()
	var center := Vector3.ZERO
	for index in positions.size():
		var point := positions[index]
		if absf(point.y - .0104) < .00025 and point.z > .229 and absf(point.x) < .01:
			string_indices.append(index)
			center += point
	if string_indices.size() < 3:
		imported.free()
		return false
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
	rest_bow = ArrayMesh.new()
	rest_bow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	rest_bow.surface_set_material(0, source.surface_get_material(0))
	rest_arrays = arrays
	string_vertices = string_indices
	string_center = center / float(string_indices.size())
	imported.free()
	return true


func set_equipment(worn: Array) -> void:
	var equipped: Dictionary = {}
	for item: Dictionary in worn:
		if int(item.get("layer", 0)) == 2 and int(item.get("id", 0)) in [0x13b1, 0x13b2]:
			equipped = item
			break
	if equipped.is_empty():
		if is_instance_valid(bow):
			bow.hide()
		return
	if not is_instance_valid(bow):
		if not prepare_bow():
			return
		bow = MeshInstance3D.new()
		bow.name = "RatmanBow"
		bow.mesh = rest_bow
		bow.set_meta("corpse_prop_keeps_material", true)
		add_child(bow)
	var hue := int(equipped.get("hue", 0))
	if hue != bow_hue:
		bow_hue = hue
		var source := rest_bow.surface_get_material(0) as StandardMaterial3D
		bow.set_surface_override_material(0, Hue.material(source, hue) if hue != 0 else source)
	bow.show()
	sync_bow()


func bow_release_available() -> bool:
	return not dead and is_instance_valid(bow) and bow.is_visible_in_tree()


func begin_bow_release(destination: Vector3) -> float:
	if not bow_release_available():
		return -1.0
	aim.start(destination)
	return BowAim.ReleaseTime


func bow_arrow_origin() -> Vector3:
	return bow.to_global(string_center + draw_offset + Vector3(0.0, .035, 0.0))


func sync_bow() -> void:
	if not is_instance_valid(bow) or not bow.visible:
		return
	var forward := global_basis.z.slide(Vector3.UP).normalized()
	var across := forward.cross(Vector3.UP)
	var height := grasp(left_grasp).y - global_position.y
	var rise := clampf((height - .15) / (.80 * BowScale), .24, .74)
	var vertical := Vector3.UP * rise - forward * sqrt(1.0 - rise * rise)
	var offset := draw_offset if not dead and aim.elapsed < BowAim.RecoveryTime else Vector3.ZERO
	place_bow(Basis(across, vertical, across.cross(vertical)), offset)
	if dead:
		ground_bow()


func pose_bow_release(flight: Vector3, across: Vector3, weight: float, draw: float) -> void:
	if not bow_release_available():
		return
	var released := release_basis(flight, across)
	var basis := bow.global_basis.orthonormalized().slerp(released, weight)
	var right := grasp(right_grasp)
	var fit := basis.scaled_local(Vector3.ONE * BowScale)
	var origin := grasp(left_grasp) - fit * Grip
	var local := Transform3D(fit, origin).affine_inverse() * right
	place_bow(basis, (local - string_center).limit_length(.60) * draw)


func bow_draw_target(flight: Vector3, across: Vector3, distance: float) -> Vector3:
	var basis := release_basis(flight, across)
	return grasp(left_grasp) + basis * ((string_center - Grip) * BowScale) - flight * distance


func release_basis(flight: Vector3, across: Vector3) -> Basis:
	var upright := flight.cross(across)
	return Basis(-across, upright, upright.cross(across))


func grasp(joint: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(joint).origin)


func place_bow(basis: Basis, offset: Vector3) -> void:
	var fit := basis.scaled_local(Vector3.ONE * BowScale)
	bow.global_transform = Transform3D(fit, grasp(left_grasp) - fit * Grip)
	if offset.is_equal_approx(draw_offset):
		return
	draw_offset = offset
	if draw_offset.is_zero_approx():
		bow.mesh = rest_bow
		return
	var vertices: PackedVector3Array = rest_arrays[Mesh.ARRAY_VERTEX].duplicate()
	for index in string_vertices:
		vertices[index] += draw_offset
	var arrays := rest_arrays.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var drawn := ArrayMesh.new()
	drawn.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	drawn.surface_set_material(0, rest_bow.surface_get_material(0))
	bow.mesh = drawn


func ground_bow() -> void:
	if collapse_plane.is_empty():
		return
	var normal: Vector3 = collapse_plane.normal
	var origin: Vector3 = collapse_plane.position
	var initial := bow_gap(origin, normal, bow.global_transform)
	if initial >= Clearance:
		return
	var basis := bow.global_basis.orthonormalized()
	var thin := basis.x
	var turn := Quaternion(thin, normal if thin.dot(normal) >= 0.0 else -normal)
	var base := bow.global_transform
	var pivot := grasp(left_grasp)
	var lower := 0.0
	var upper := 1.0
	for sample in 8:
		var weight := (lower + upper) * .5
		var rotated := Basis(Quaternion.IDENTITY.slerp(turn, weight)) * base.basis
		var candidate := Transform3D(rotated, pivot - rotated * Grip)
		if bow_gap(origin, normal, candidate) < Clearance:
			lower = weight
		else:
			upper = weight
	var fitted := Basis(Quaternion.IDENTITY.slerp(turn, upper)) * basis
	place_bow(fitted, Vector3.ZERO)
	var gap := bow_gap(origin, normal, bow.global_transform)
	if gap < Clearance:
		var lift := Vector3.UP * (Clearance - gap) / normal.y
		model.global_position += lift
		collapse_shift += global_basis.inverse() * lift
		bow.global_position += lift


func bow_gap(origin: Vector3, normal: Vector3, pose: Transform3D) -> float:
	var gap := INF
	for point: Vector3 in rest_arrays[Mesh.ARRAY_VERTEX]:
		gap = minf(gap, normal.dot(pose * point - origin))
	return gap


func corpse_snapshot_floor() -> float:
	var body_floor := super.corpse_snapshot_floor()
	if is_instance_valid(bow) and bow.visible:
		return minf(body_floor, bow_gap(global_position, Vector3.UP, bow.global_transform))
	return body_floor
