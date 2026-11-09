extends RefCounted
## Keep the skin of a fitted source gesture above the sampled terrain plane.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var skin: Dictionary
var restore_pose := Transform3D.IDENTITY
var applied := false

func bind(actor: Node3D) -> void:
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skin = Ground.skin_points(mesh, actor.skeleton)
	actor.animator.mixer_applied.connect(release.bind(actor))
	actor.contact.modification_processed.connect(support.bind(actor))

func release(actor: Node3D) -> void:
	if applied:
		actor.model.transform = restore_pose
		applied = false

func support(actor: Node3D) -> void:
	if actor.dead or actor.current_clip not in actor.entry.get("archive_grounded_gestures", []):
		return
	release(actor)
	if actor.contact.contacts.is_empty():
		return
	var hit: Dictionary = actor.contact.contacts.values()[0]
	var normal: Vector3 = hit.normal
	restore_pose = actor.model.transform
	applied = true
	if actor.entry.get("archive_align_gesture_slope", false):
		var local_normal := (actor.global_basis.inverse() * normal).normalized()
		var slope := Basis(Quaternion(Vector3.UP, local_normal))
		actor.model.basis = (slope * actor.source_model_basis).scaled_local(restore_pose.basis.get_scale())
	actor.skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform, hit.position, normal)
	if gap < 0.002:
		actor.model.global_position.y += (0.002 - gap) / float(normal.y)
