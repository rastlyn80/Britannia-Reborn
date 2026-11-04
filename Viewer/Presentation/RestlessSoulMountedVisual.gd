extends "res://Presentation/RestlessSoulVisual.gd"
## The split robe uses the authoritative worn mount and its animated saddle.

const Mounts := preload("res://Presentation/MountVisual.gd")
const Actions := preload("res://Presentation/HumanActions.gd")
const Seats := {
	23: "Horse_Walk", 24: "Horse_Run", 25: "Horse_Idle",
	26: "Horse_Attack1h_Slashright", 27: "Horse_Attackbow",
	28: "Horse_Attackcrossbow", 29: "GhostUrgeMount",
}

var mount: Node3D
var seated_model: Node3D
var seated_rig: Skeleton3D
var seated_player: AnimationPlayer
var seated_basis := Basis.IDENTITY
var mount_key: Array = []
var mounted_skin: MeshInstance3D
var mounted_hue := -1
var pelvis := -1
var left_grip := -1
var right_grip := -1

func _ready() -> void:
	process_priority = 5
	super._ready()

func set_equipment(worn: Array) -> void:
	var item := Mounts.mount_item(worn)
	var graphic := int(item.get("id", 0))
	var body := Mounts.horse_body(graphic)
	var path: String = entry.get("mounted_assets", {}).get(treatment, "")
	if dead or body == 0 or path.is_empty() or not Mounts.mount_available(body, graphic):
		clear_mount()
		return
	var key := [int(item.get("serial", 0)), graphic]
	if mount_key != key:
		clear_mount()
		var scene := load(path) as PackedScene
		if scene == null:
			return
		var candidate := Mounts.create(body, graphic)
		if candidate == null:
			return
		if not candidate.has_method("seat"):
			candidate.free()
			return
		mount = candidate
		add_child(mount)
		seated_model = scene.instantiate()
		add_child(seated_model)
		seated_basis = seated_model.basis
		seated_rig = seated_model.find_children("*", "Skeleton3D", true, false)[0]
		seated_player = seated_model.find_children("*", "AnimationPlayer", true, false)[0]
		mounted_skin = seated_model.find_children("*", "MeshInstance3D", true, false)[0]
		pelvis = seated_rig.find_bone("bip01 pelvis")
		left_grip = seated_rig.find_bone("cp_grasp_lhand")
		right_grip = seated_rig.find_bone("cp_grasp_rhand")
		assert(mini(pelvis, mini(left_grip, right_grip)) >= 0)
		var library := seated_player.get_animation_library("").duplicate(true)
		seated_player.remove_animation_library("")
		seated_player.add_animation_library("", library)
		for slot in [23, 24, 25]:
			seated_player.get_animation(Seats[slot]).loop_mode = Animation.LOOP_LINEAR
		mount_key = key
		action_remaining = 0.0
		contact.enabled = false
		model.hide()
		set_seated_clip(Seats[25], 0.0)
	apply_seated_hue(native_hue)
	mount.apply_identity(body, int(item.get("hue", 0)), graphic)
	fit_to_saddle()

func clear_mount() -> void:
	if mount == null:
		return
	mount.free()
	seated_model.free()
	mount = null
	seated_model = null
	seated_rig = null
	seated_player = null
	mounted_skin = null
	mount_key.clear()
	mounted_hue = -1
	model.show()
	contact.enabled = not dead
	action_remaining = 0.0
	current_clip = "Idle"
	play(current_clip, 0.0)
	update_landmarks()

func set_hue(value: int) -> void:
	super.set_hue(value)
	apply_seated_hue(value)

func apply_seated_hue(value: int) -> void:
	if mounted_skin == null or mounted_hue == value:
		return
	mounted_hue = value
	if treatment != "modern":
		return
	var palette := Hue.palette(value)
	mounted_skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface in mounted_skin.mesh.get_surface_count():
		var original := mounted_skin.mesh.surface_get_material(surface) as StandardMaterial3D
		var material := ShaderMaterial.new()
		material.shader = Surface
		material.set_shader_parameter("albedo_texture", original.albedo_texture)
		material.set_shader_parameter("hue_palette", palette)
		material.set_shader_parameter("use_hue", palette != null)
		material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
		mounted_skin.set_surface_override_material(surface, material)

func motion(speed: float, turn_rate: float, delta: float) -> void:
	if mount != null:
		mount.motion(speed, turn_rate, delta)

func play_gait(moving: bool, speed: float) -> void:
	if mount == null:
		super.play_gait(moving, speed)
		return
	mount.play_gait(moving, speed)
	if action_remaining > 0.0:
		return
	var clip: String = Seats[25] if not moving else Seats[24] if speed > 3.6 else Seats[23]
	if current_clip != clip:
		set_seated_clip(clip, 0.12)

func receive_action(request: Dictionary) -> bool:
	var slot := int(request.get("action", -1)) if request.get("protocol") == "classic" else -1
	if Seats.has(slot):
		if mount == null or dead:
			return false
		var clip: String = Seats[slot]
		var length := seated_player.get_animation(clip).length
		action_remaining = Actions.duration(request, length)
		set_seated_clip(clip, 0.12, length / action_remaining)
		set_meta("native_action", request.duplicate(true))
		return true
	if mount != null:
		var death: bool = slot in [21, 22] or request.get("protocol") == "new" and int(request.get("type", -1)) == 3
		if not death:
			return false
		clear_mount()
	return super.receive_action(request)

func set_seated_clip(clip: String, blend: float, rate: float = 1.0) -> void:
	current_clip = clip
	seated_player.play(clip, blend, rate)
	seated_player.seek(0.0, false)
	seated_player.advance(0.0)

func _physics_process(delta: float) -> void:
	if mount == null:
		super._physics_process(delta)

func _process(delta: float) -> void:
	super._process(delta)
	if mount != null:
		if action_remaining <= 0.0 and current_clip in [Seats[23], Seats[24], Seats[25]]:
			var phase: float = mount.animator.current_animation_position / maxf(0.001, mount.animator.current_animation_length)
			seated_player.seek(phase * seated_player.current_animation_length, true)
		fit_to_saddle()

func fit_to_saddle() -> void:
	var saddle: Transform3D = mount.seat()
	seated_model.global_basis = saddle.basis.orthonormalized() * seated_basis
	var pelvis_position := joint_world(pelvis)
	seated_model.global_position += saddle * Vector3(0.0, 0.105, 0.0) - pelvis_position
	if mount.has_method("set_reins"):
		var left := joint_world(left_grip)
		var right := joint_world(right_grip)
		if current_clip in [Seats[27], Seats[28]]:
			left = saddle * Vector3(0.08, 0.14, 0.22)
			right = left
		elif current_clip in [Seats[26], Seats[29]]:
			right = left
		mount.set_reins(left, right)
	update_landmarks()

func joint_world(index: int) -> Vector3:
	return seated_rig.to_global(seated_rig.get_bone_global_pose(index).origin)

func update_landmarks() -> void:
	if mount == null:
		super.update_landmarks()
		return
	var inverse := global_transform.affine_inverse()
	var bounds := (inverse * mounted_skin.global_transform) * mounted_skin.get_aabb()
	for mesh: MeshInstance3D in mount.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree():
			bounds = bounds.merge((inverse * mesh.global_transform) * mesh.get_aabb())
	set_meta("nameplate_height", bounds.end.y + 0.08)
	set_meta("pick_bounds", bounds.grow(0.025))
	landmarks_changed.emit()

func begin_death_from(source: Node3D) -> float:
	clear_mount()
	return super.begin_death_from(source)
