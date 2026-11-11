# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/OstardMount.gd"
## Later Third Dawn living mounts. The server still owns their worn items.

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
const Hues := preload("res://Presentation/HumanHue.gd")
const Timing := preload("res://Presentation/HumanActions.gd")
const KiRinCoat := preload("res://Presentation/KiRinCoat.gdshader")
const SpectralCoat := preload("res://Presentation/OstardEthereal.gdshader")
const KiRinSpectralCoat := preload("res://Presentation/KiRinSpectralCoat.gdshader")
const Art := "res://local-art/mounts/"
const Manifest := Art + "magical-equines.json"
const Forms := {
	122: {"kind": "unicorn", "item": 0x3eb4, "scene": "unicorn-grounded.scn", "seat_joint": "spine1",
		"saddle": Vector3(0., 1.61, -.08), "mouth": Vector3(0., 1.71, 1.25),
		"stirrup": Vector3(.32, -.62, .12)},
	132: {"kind": "kirin", "item": 0x3ead, "scene": "kirin-late-grounded.scn", "seat_joint": "spine",
		"saddle": Vector3(0., 1.66, .04), "mouth": Vector3(0., 1.39, 1.53),
		"stirrup": Vector3(.34, -.60, .12)},
}
const SpectralForms := {
	122: {"kind": "unicorn_ethereal", "item": 0x3e9b, "scene": "unicorn-ethereal-grounded.scn",
		"seat_joint": "spine1", "saddle": Vector3(0., 1.315, .04), "mouth": Vector3(0., 1.47, 1.49),
		"stirrup": Vector3(.32, -.62, .12), "spectral_tint": Color("c2ddf0")},
	132: {"kind": "kirin_ethereal", "item": 0x3e9c, "scene": "kirin-ethereal-grounded.scn",
		"seat_joint": "spine", "saddle": Vector3(0., 1.665, .04), "mouth": Vector3(0., 1.40, 1.53),
		"stirrup": Vector3(.34, -.60, .12), "spectral_tint": Color("c2d2ee")},
}
const EnhancedGroups := {
	122: {2: "Death", 3: "Death2", 4: "RearingStrike", 5: "HornLunge", 10: "HeadRecoil",
		12: "CastingRear", 15: "WarningRear", 25: "Idle", 26: "QuietHeadCheck", 27: "HighFidget", 28: "GuardAlert"},
	132: {2: "Death", 3: "Death2", 4: "LowSnap", 5: "RaisedForeStrike", 10: "LowRecoil", 11: "DeepBow",
		12: "HeadSweepCast", 15: "WarningPaw", 23: "StretchAndRise", 25: "Idle", 27: "ForwardFidget", 28: "GuardAlert"},
}

static var available_forms: Dictionary = {}
static var available_spectral: Dictionary = {}
var form: Dictionary
var fall := Fall.new()
var harness: BoneAttachment3D
var fitted := false
var source_flags := 0


static func configure(enabled: bool) -> void:
	available_forms.clear()
	available_spectral.clear()
	if not enabled or not FileAccess.file_exists(Manifest):
		return
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(Manifest))
	if not record is Dictionary or int(record.get("schema", 0)) != 1:
		return
	for table: Array in [[Forms, available_forms], [SpectralForms, available_spectral]]:
		for body: int in table[0]:
			var entry: Dictionary = table[0][body]
			var member: String = entry.scene
			var path := Art + member
			var digest := str(record.get(member, ""))
			if digest.length() == 64 and FileAccess.get_sha256(path) == digest and ResourceLoader.exists(path, "PackedScene"):
				table[1][body] = entry


static func selected(body: int, item: int) -> bool:
	return not configuration(body, item).is_empty()


static func configuration(body: int, item: int) -> Dictionary:
	if available_spectral.has(body) and item == SpectralForms[body].item:
		return available_spectral[body]
	if available_forms.has(body) and (item == 0 or item == Forms[body].item):
		return available_forms[body]
	return {}


func model_resource_path(_folder: String, _asset_kind: String) -> String:
	return Art + str(form.scene)


func build_eyes() -> void:
	# Both original atlases already contain the eyes.
	pass


func _ready() -> void:
	super._ready()
	seat_bone = find_source_bone(form.seat_joint)
	assert(seat_bone >= 0 and mouth_bone >= 0)
	seat_offset = rest_space(seat_bone) * form.saddle
	mouth_offset = rest_space(mouth_bone) * form.mouth
	set_meta("rider_ground_drop", form.saddle.y - .09)
	var rein_material := reins.material_override as StandardMaterial3D
	rein_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	reins.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	contact.feet.clear()
	contact.configure(model.find_children("*", "MeshInstance3D", true, false)[0], true)
	build_harness()
	fitted = animator.has_animation("EquineSideFall") and animator.has_animation("Death2")
	if fitted:
		var library := animator.get_animation_library("")
		var original := library.get_animation("Death")
		library.remove_animation("Death")
		library.add_animation("OriginalDeath", original)
		library.add_animation("Death", library.get_animation("EquineSideFall"))
	animator.mixer_applied.connect(_settle_fall)


func rest_space(bone: int) -> Transform3D:
	return (skeleton.global_transform * skeleton.get_bone_global_rest(bone)).affine_inverse() * global_transform


func apply_identity(body: int, value: int, item: int = 0) -> void:
	super.apply_identity(body, value, item)
	var ridden: bool = item == form.item and not dead
	reins.visible = ridden
	harness.visible = ridden
	set_meta("original_magical_equine", true)
	if form.has("spectral_tint"):
		set_meta("equine_profile", {"style": kind, "ethereal": true})


func set_hue(value: int) -> void:
	var spectral := form.has("spectral_tint")
	if kind != "kirin" and not spectral:
		super.set_hue(value)
		return
	hue = value
	if model == null:
		return
	var palette: Texture2D = null if spectral and hue == 0x4001 else Hues.palette(hue)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = (KiRinSpectralCoat if kind == "kirin_ethereal" else SpectralCoat) if spectral else KiRinCoat
			material.set_shader_parameter("albedo_texture", source.albedo_texture)
			if spectral:
				material.set_shader_parameter("spectral_tint", form.spectral_tint)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (hue & 0x8000) != 0)
			material.set_shader_parameter("skin_roughness", .84)
			mesh.set_surface_override_material(surface, material)


func stirrup(left: bool) -> Vector3:
	var offset: Vector3 = form.stirrup
	if not left:
		offset.x = -offset.x
	return seat() * offset


func rein_grip_target(left: bool) -> Vector3:
	return Vector3(.15 if left else -.15, .28, .34)


func build_harness() -> void:
	harness = BoneAttachment3D.new()
	harness.name = "SourceEquineSaddle"
	harness.bone_idx = seat_bone
	skeleton.add_child(harness)
	harness.hide()
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color("3c281c")
	leather.roughness = .88
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("857450")
	metal.metallic = .56
	metal.roughness = .48
	var pad := SphereMesh.new()
	pad.radial_segments = 24
	pad.rings = 12
	var base: Vector3 = form.saddle
	add_fitting("SaddlePad", pad, leather, base + Vector3(0., -.018, 0.),
		Basis.IDENTITY.scaled(Vector3(.56, .115, .49)))
	var ring := TorusMesh.new()
	ring.inner_radius = .31
	ring.outer_radius = .47
	ring.rings = 16
	ring.ring_segments = 8
	var strap := BoxMesh.new()
	strap.size = Vector3(.023, 1.0, .041)
	for sign: float in [-1., 1.]:
		var side := "Right" if sign < 0. else "Left"
		var from := base + Vector3(sign * .235, -.045, .015)
		var offset: Vector3 = form.stirrup
		offset.x *= sign
		var to := base + offset
		var direction := to - from
		add_fitting(side + "Strap", strap, leather, from.lerp(to, .5),
			Basis(Quaternion(Vector3.DOWN, direction.normalized())).scaled_local(Vector3(1., direction.length(), 1.)))
		add_fitting(side + "Stirrup", ring, metal, to,
			Basis(Vector3.BACK, PI * .5).scaled_local(Vector3(.19, .10, .20)))


func add_fitting(label: String, mesh: Mesh, material: Material, position: Vector3, basis: Basis) -> void:
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = mesh
	piece.material_override = material
	harness.add_child(piece)
	piece.transform = rest_space(seat_bone) * Transform3D(basis, position)


func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead:
		harness.hide()
		reins.hide()
		fall.accept_action(self)
	return accepted


func set_native_combat_flags(flags: int) -> void:
	source_flags = maxi(flags, 0)


func play_gait(moving: bool, speed: float) -> void:
	if not fitted or current_clip == "LieDown":
		super.play_gait(moving, speed)
		return
	if dead or action_remaining > 0.:
		return
	var running := moving and speed > 3.6
	var mounted := native_mount_item != 0
	var hovering := native_body == 132 and not mounted and (source_flags & 0x04) != 0
	var combat := not mounted and (source_flags & 0x40) != 0
	var clip := "Run" if running else "Walk" if moving else "Idle"
	if hovering:
		clip = "HoverGather"
	elif native_body == 132 and mounted:
		clip = "MountedRun" if running else "MountedWalk" if moving else "MountedIdle"
	elif combat and not running:
		clip = "CombatWalk" if moving else "CombatIdle"
	contact.enabled = not hovering
	contact.active = not hovering
	if current_clip != clip or animator.assigned_animation != clip:
		current_clip = clip
		play(clip, .18)
	animator.speed_scale = clampf(speed / (5.5 if running else 1.8), .65, 1.65) if moving and not hovering else 1.


static func action_group(body: int, type: int, subaction: int, variation: int, flags: int) -> int:
	if flags < 0 or variation < 0 or variation > 127 or not EnhancedGroups.has(body):
		return -1
	var choices: Array
	match type:
		0:
			choices = [4, 5, 4] if subaction == 0 else [4] if subaction in [1, 2, 9] else [4, 5, 4, 4, 4, 4]
		2:
			choices = [15]
		3:
			choices = [2, 3]
		4:
			choices = [10]
		5:
			var combat := (flags & 0x40) != 0 or (body == 132 and (flags & 0x04) != 0)
			choices = [25, 27] if body == 132 and combat else [25] if body == 132 else [26, 27] if combat else [26]
		8:
			choices = [28]
		11:
			choices = [12]
		14:
			choices = [11 if body == 132 else 25]
		15:
			choices = [23 if body == 132 else 25]
		_:
			return -1
	return choices[variation % choices.size()]


func receive_enhanced_action(request: Dictionary, flags: int) -> bool:
	if not fitted or dead or request.get("protocol") != "new" or int(request.get("body", 0)) != native_body:
		return false
	var group := action_group(native_body, int(request.get("type", -1)), int(request.get("subaction", -1)),
		int(request.get("variation", -1)), flags)
	if group < 0:
		return false
	var clip: String = EnhancedGroups[native_body][group]
	current_clip = clip
	dead = clip in Fall.FALLS
	contact.enabled = not dead
	contact.active = not dead
	if dead:
		harness.hide()
		reins.hide()
		fall.accept_action(self)
	var length := animator.get_animation(clip).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.
	animator.play(clip, .10, length / action_remaining)
	animator.seek(0.0, false)
	set_meta("native_action", request.duplicate(true))
	return true


func begin_source_death(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	return fall.begin_from_source(self, source, source.fall)


func _settle_fall() -> void:
	if dead:
		fall.settle(self)


func corpse_snapshot_floor() -> float:
	return INF if fall.skin.is_empty() else fall.snapshot_floor(self)
