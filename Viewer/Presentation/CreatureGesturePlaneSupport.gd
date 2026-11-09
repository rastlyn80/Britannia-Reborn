extends RefCounted

const Ground := preload("res://Presentation/SourceGroundLookup.gd")

var skin: Dictionary
var lift := 0.0
var peak := 0.0

func bind_actor(actor: Node3D, clips: Array[String]) -> void:
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skin = Ground.skin_points(mesh, actor.skeleton)
	actor.animator.mixer_applied.connect(restore.bind(actor))
	actor.contact.modification_processed.connect(support.bind(actor, clips))

func restore(actor: Node3D) -> void:
	if not is_zero_approx(lift):
		actor.model.global_position.y -= lift
	lift = 0.0

func support(actor: Node3D, clips: Array[String]) -> void:
	restore(actor)
	if actor.dead or actor.current_clip not in clips or actor.contact.contacts.is_empty():
		return
	var plane: Dictionary = actor.contact.contacts.values()[0]
	var normal: Vector3 = plane.normal
	if normal.y <= 0.75:
		return
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, normal)
	lift = clampf((0.002 - gap) / normal.y, 0.0, 0.19)
	actor.model.global_position.y += lift
	peak = maxf(peak, lift)
