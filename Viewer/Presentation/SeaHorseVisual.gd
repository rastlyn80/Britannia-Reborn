# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceRigMountVisual.gd"
## A rigged reconstruction following the Enhanced SeaHorse sequences.

const Fall := preload("res://Presentation/CougarTerrainFall.gd")
const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const TailContact := preload("res://Presentation/SourceSeaHorseTailContact.gd")
const Displayed := preload("res://Presentation/SourceRenderedPose.gd")
const Actions := preload("res://Presentation/HumanActions.gd")
const CLASSIC := {
	0: "CombatGlide", 1: "CombatIdle", 2: "Death", 3: "Death2", 4: "Attack", 5: "Attack2",
	10: "Hit", 11: "ForwardRush", 12: "Cast", 15: "TailCurl", 22: "Walk", 23: "Uncoil",
	24: "Run", 25: "Idle", 26: "Fidget", 27: "LongReach", 28: "Alert",
}
const COMBAT_ACTIONS := {
	0: ["Attack", "Attack2", "Attack", "Attack", "Attack", "Attack"],
	2: ["TailCurl"], 3: ["Death", "Death2"], 4: ["Hit"], 5: ["Fidget", "LongReach"],
	8: ["Alert"], 11: ["Cast"], 14: ["ForwardRush"], 15: ["Uncoil"],
}

var fall := Fall.new()
var terrain := Terrain.new()
var tail_contact := TailContact.new()
var displayed := Displayed.new()
var combat := false
var harness: BoneAttachment3D


func mount_fittings() -> Dictionary:
	return {
		"proportions": Vector3.ONE,
		"saddle": Vector3(0.0, 1.54, -0.43),
		"mouth": Vector3(0.0, 1.92, 0.79),
		"seat_bone": "saddle_socket",
		"mouth_bone": "mouth_socket",
		"stirrup": Vector3(0.34, -0.57, 0.14),
	}


func find_bone(socket_name: String) -> int:
	return skeleton.find_bone(socket_name)


func _ready() -> void:
	super._ready()
	for clip in ["CombatIdle", "CombatGlide"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	fall.skin = control_skin
	terrain.actor = self
	terrain.skin = control_skin
	terrain.extent = Vector2(.63, 1.08)
	skeleton.add_child(tail_contact)
	tail_contact.active = false
	tail_contact.bind(control_skin)
	animator.mixer_applied.connect(_settle)
	build_harness()


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	super._physics_process(delta)
	terrain.sample()
	terrain.settle_live()


func support_control_plane() -> void:
	if dead:
		return
	terrain.release_live()
	if terrain.split:
		tail_contact.clear_treads(float(terrain.plane.position.y))
	terrain.settle_live()
	displayed.capture(skeleton)


func apply_identity(body: int, value: int, item: int = 0) -> void:
	super.apply_identity(body, value, item)
	reins.visible = item == 0x3eb3 and not dead
	harness.visible = reins.visible


func build_harness() -> void:
	harness = BoneAttachment3D.new()
	harness.name = "SeahorseSaddle"
	harness.bone_idx = seat_bone
	skeleton.add_child(harness)
	harness.hide()
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color("372921")
	leather.roughness = 0.82
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("776b45")
	metal.metallic = 0.66
	metal.roughness = 0.52
	var pad := SphereMesh.new()
	pad.radial_segments = 24
	pad.rings = 12
	harness_piece(pad, leather, Vector3(0.0, -0.035, -0.018), Vector3(0.49, 0.17, 0.39))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.30
	ring.outer_radius = 0.48
	ring.rings = 16
	ring.ring_segments = 8
	var strap := BoxMesh.new()
	strap.size = Vector3(0.026, 1.0, 0.045)
	for sign: float in [-1.0, 1.0]:
		var start := Vector3(sign * 0.19, -0.05, 0.045)
		var end := Vector3(sign * 0.34, -0.57, 0.14)
		var line := end - start
		var band := harness_piece(strap, leather, start.lerp(end, 0.5), Vector3.ONE)
		band.basis = Basis(Quaternion(Vector3.DOWN, line.normalized())).scaled_local(Vector3(1., line.length(), 1.))
		var stirrup_piece := harness_piece(ring, metal, end, Vector3.ONE)
		stirrup_piece.basis = Basis(Vector3.BACK, PI * 0.5).scaled_local(Vector3(0.17, 0.08, 0.19))


func harness_piece(mesh: Mesh, material: Material, offset: Vector3, size: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = seat_offset + offset
	part.scale = size
	harness.add_child(part)
	return part


func set_native_combat_flags(flags: int) -> void:
	combat = flags >= 0 and (flags & 0x40) != 0


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0:
		return
	var running := moving and speed > 3.6
	var clip := "Run" if running else ("CombatGlide" if combat else "Walk") if moving else ("CombatIdle" if combat else "Idle")
	if current_clip != clip or animator.assigned_animation != clip:
		current_clip = clip
		play(clip, 0.16)
	animator.speed_scale = clampf(speed / (5.5 if running else 1.8), 0.65, 1.65) if moving else 1.0


func receive_action(request: Dictionary) -> bool:
	var clip := ""
	if request.get("protocol") == "classic":
		clip = CLASSIC.get(int(request.get("action", -1)), "")
	elif request.get("protocol") == "new":
		var type := int(request.get("type", -1))
		var subaction := int(request.get("subaction", -1))
		var variant := int(request.get("variation", -1))
		var choices: Array = ["Fidget"] if not combat and type == 5 else COMBAT_ACTIONS.get(type, [])
		if type == 0:
			if subaction == 0:
				choices = ["Attack", "Attack2", "Attack"]
			elif subaction in [1, 2, 9]:
				choices = ["Attack"]
		if variant >= 0 and variant <= 127 and not choices.is_empty():
			clip = choices[variant % choices.size()]
	if clip.is_empty() or dead:
		return false
	current_clip = clip
	var length := animator.get_animation(clip).length
	action_remaining = Actions.duration(request, length)
	animator.speed_scale = 1.0
	if clip in Fall.FALLS:
		dead = true
		contact.enabled = false
		fall.split = terrain.split
		fall.remember_floor(self, terrain.plane if not terrain.plane.is_empty() else fall.floor_under(self))
		terrain.live_lift = 0.0
	animator.play(clip, 0.1, length / maxf(0.01, action_remaining))
	animator.seek(0.0, false)
	set_meta("native_action", request.duplicate(true))
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	var previous: RefCounted = source.fall if source.dead else source.terrain
	var continuing: bool = source.dead and source.current_clip in Fall.FALLS
	var support: Dictionary = previous.plane if not previous.plane.is_empty() else fall.floor_under(source)
	model.position -= previous.shift
	current_clip = source.current_clip if continuing else "Death"
	fall.split = previous.split
	fall.remember_floor(self, support)
	var time: float = source.animator.current_animation_position if continuing else 0.0
	var rate: float = maxf(0.01, absf(source.animator.get_playing_speed())) if continuing else 1.0
	if continuing and is_zero_approx(source.animator.get_playing_speed()):
		rate = 1.0
	animator.speed_scale = 1.0
	dead = true
	contact.enabled = false
	fall.blend_start = time
	fall.blend_length = minf(0.12 * rate, animator.get_animation(current_clip).length - time)
	if fall.blend_length > 0.0:
		var previous_pose = source.displayed
		var recorded: bool = not continuing and previous_pose.rig_id == source.skeleton.get_instance_id() \
			and Engine.get_process_frames() - previous_pose.frame <= 1
		for bone in source.skeleton.get_bone_count():
			var pose: Transform3D = previous_pose.poses[bone] if recorded else source.skeleton.get_bone_pose(bone)
			fall.blend_pose.append(pose)
	animator.play(current_clip, 0.0, rate)
	animator.advance(0.0)
	animator.seek(time, true)
	action_remaining = maxf(0.0, animator.current_animation_length - time) / rate
	return action_remaining


func _settle() -> void:
	if dead:
		fall.settle(self)


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self)
