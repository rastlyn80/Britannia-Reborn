# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const ArcClips := ["LatticeRisingStrike", "LatticeCrossingStrike", "LatticeArcCast", "LatticeHighWard"]
const HoverClips := ArcClips + ["LatticeUnfurl"]
const Quiet := "LatticeQuietHover"
const PeaceWalk := "LatticePeaceWalk"
const DrainColours := {1042155: Color(.56, .73, 1.0), 1042156: Color(1.0, .68, .53), 1042157: Color(.76, 1.0, .69)}

static var arc_mesh: ArrayMesh
var arc: MeshInstance3D
var arc_material: StandardMaterial3D
var left_hand := -1
var right_hand := -1
var drain_glow: GPUParticles3D
var combat_flags := -1
var air_plane: Dictionary = {}
var display_skin: Dictionary = {}
var alternate_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	left_hand = skeleton.find_bone("bip01 l hand")
	right_hand = skeleton.find_bone("bip01 r hand")
	assert(left_hand >= 0 and right_hand >= 0)
	animator.mixer_applied.connect(sync_arc)
	animator.mixer_applied.connect(settle_alternate_fall)
	animator.mixer_applied.connect(support_air_pose)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	display_skin = Ground.skin_points(mesh, skeleton)
	contact.modification_processed.connect(sync_arc)


func set_native_combat_flags(flags: int) -> void:
	combat_flags = flags


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0:
		return
	var locomotion: Dictionary = entry.get("locomotion", {})
	if combat_flags < 0 or (combat_flags & 64) != 0 or moving and speed > float(locomotion.get("run_threshold_mps", 3.6)):
		super.play_gait(moving, speed)
		return
	contact.enabled = true
	var clip := PeaceWalk if moving else Quiet
	if current_clip != clip:
		current_clip = clip
		play(clip, .18)
	var reference := maxf(.01, float(locomotion.get("walk_reference_mps", 1.8)))
	animator.speed_scale = clampf(speed / reference, float(locomotion.get("rate_min", .65)),
		float(locomotion.get("rate_max", 1.65))) if moving else 1.0


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip in ["Death", "Death2"]:
		alternate_fall.accept_action(self)
	else:
		alternate_fall.plane.clear()
	if current_clip in HoverClips:
		contact.enabled = false
	if is_instance_valid(drain_glow) and dead:
		drain_glow.hide()
	sync_arc()
	return true


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not dead and current_clip in HoverClips:
		air_plane = alternate_fall.floor_under(self)
		support_air_pose()
	else:
		air_plane.clear()


func support_air_pose() -> void:
	if dead or air_plane.is_empty() or current_clip not in HoverClips:
		return
	var normal: Vector3 = air_plane.normal
	var gap := Ground.minimum_plane_gap(display_skin, skeleton, skeleton.global_transform, air_plane.position, normal)
	if gap < .002:
		var before := model.position
		model.global_position += normal * (.002 - gap)
		clearance_lift += model.position - before


func settle_alternate_fall() -> void:
	if current_clip in ["Death", "Death2"] and not pose_entry.active:
		alternate_fall.settle(self)


func begin_death_from(source: Node3D) -> float:
	if source.current_clip != "Death2" or not source.dead:
		var length := super.begin_death_from(source)
		var floor := alternate_fall.floor_under(source)
		pose_entry.plane_origin = floor.position
		pose_entry.plane_normal = floor.normal
		return length
	dead = true
	contact.enabled = false
	return alternate_fall.begin_from_source(self, source, source.alternate_fall, false)


func corpse_snapshot_floor() -> float:
	if current_clip == "Death2" and not alternate_fall.plane.is_empty():
		return alternate_fall.snapshot_floor(self)
	return INF


func sync_arc() -> void:
	var active := not dead and current_clip in ArcClips and action_remaining > 0.0
	if not active:
		if is_instance_valid(arc):
			arc.hide()
		return
	var phase := animator.current_animation_position / maxf(.01, animator.current_animation_length)
	var strength := smoothstep(.04, .30, phase) * (1.0 - smoothstep(.74, .98, phase))
	if strength < .015:
		if is_instance_valid(arc):
			arc.hide()
		return
	if not is_instance_valid(arc):
		arc = MeshInstance3D.new()
		arc.name = "LatticeCastArc"
		arc.set_meta("optional_corpse_visual_prop", true)
		if arc_mesh == null:
			arc_mesh = build_arc()
		arc.mesh = arc_mesh
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arc_material = StandardMaterial3D.new()
		arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		arc_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		arc.material_override = arc_material
		add_child(arc)
	var hand := left_hand if current_clip == "LatticeCrossingStrike" else right_hand
	var palm := skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
	var bow_turn := Basis(Vector3.RIGHT, lerpf(-.42, .34, phase))
	var tilt := Basis(Vector3.FORWARD, lerpf(.38, -.38, phase))
	arc.global_transform = Transform3D(global_basis.orthonormalized() * tilt * bow_turn, palm)
	arc_material.albedo_color = Color(.78, .91, 1.0, .84 * strength)
	arc.show()


func show_native_drain(cliloc: int) -> void:
	if dead or not DrainColours.has(cliloc):
		return
	if is_instance_valid(drain_glow):
		drain_glow.queue_free()
	drain_glow = Effects.sparks(DrainColours[cliloc], 28, .68, .38, 1.10)
	drain_glow.name = "LatticeNativeDrain"
	drain_glow.position.y = 1.3
	drain_glow.one_shot = true
	drain_glow.explosiveness = .68
	add_child(drain_glow)
	drain_glow.emitting = true
	drain_glow.finished.connect(drain_glow.queue_free, CONNECT_ONE_SHOT)
	set_meta("native_drain_cliloc", cliloc)


static func build_arc() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 24:
		var a := arc_point(float(step) / 24.0)
		var b := arc_point(float(step + 1) / 24.0)
		var radius := .006 + .017 * sin(PI * (step + .5) / 24.0)
		for side in 6:
			var first := TAU * side / 6.0
			var next := TAU * (side + 1) / 6.0
			var u := Vector3(cos(first), 0, sin(first)) * radius
			var v := Vector3(cos(next), 0, sin(next)) * radius
			for vertex: Vector3 in [a + u, b + v, a + v, a + u, b + u, b + v]:
				tool.add_vertex(vertex)
	tool.generate_normals()
	return tool.commit()


static func arc_point(phase: float) -> Vector3:
	var amount := 2.0 * phase - 1.0
	return Vector3(0.0, .57 * amount, -.31 * amount * amount + .06 * pow(absf(amount), 5.0))
