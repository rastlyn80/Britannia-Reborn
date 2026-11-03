extends RefCounted
## Opt-in displayed-pose entry for exact-skin variants; donor renderers unchanged.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var rendered_pose:=preload("res://Presentation/SourceRenderedPose.gd").new()
var active:=false
var anchor:=Vector3.ZERO
var start_position:=Vector3.ZERO
var plane_origin:=Vector3.ZERO
var plane_normal:=Vector3.UP
var skin: Dictionary={}
var curves: Dictionary={}
var displayed_model:=Transform3D.IDENTITY
var displayed_space:=Transform3D.IDENTITY
var displayed_frame:=-10
func configure(visual: Node3D,position: Vector3) -> void:
	anchor=position
	visual.animator.deterministic=true
	visual.contact.modification_processed.connect(func():capture_rendered(visual))
	RenderingServer.frame_post_draw.connect(visual._capture_variant_frame)
	if visual.entry.has("ground_lookup"):curves=Ground.load_curves(str(visual.entry.ground_lookup),visual.treatment)
func capture_rendered(visual: Node3D) -> void:
	rendered_pose.capture(visual.skeleton)
	displayed_model=visual.model.transform
	var space:=visual.model.find_child("SourceSpace",true,false) as Node3D
	if space!=null:displayed_space=space.transform
func capture_frame(visual: Node3D) -> void:
	if not visual.is_visible_in_tree():return
	displayed_frame=Engine.get_process_frames()
	displayed_model=visual.model.transform
	var space:=visual.model.find_child("SourceSpace",true,false) as Node3D
	if space!=null:displayed_space=space.transform
func displayed_rig(rig: Skeleton3D) -> Skeleton3D:
	# A held skin can remain visible without another modifier update. Its
	# submitted local bones remain valid while the model placement is redrawn.
	if rendered_pose.rig_id!=rig.get_instance_id() or rendered_pose.poses.size()!=rig.get_bone_count():return rig
	var result:=Skeleton3D.new()
	for bone in rendered_pose.poses.size():result.add_bone(rig.get_bone_name(bone))
	for bone in rendered_pose.poses.size():
		var pose: Transform3D=rendered_pose.poses[bone]
		result.set_bone_parent(bone,rig.get_bone_parent(bone));result.set_bone_pose_position(bone,pose.origin)
		result.set_bone_pose_rotation(bone,pose.basis.get_rotation_quaternion());result.set_bone_pose_scale(bone,pose.basis.get_scale())
	return result
func begin(visual: Node3D,source: Node3D) -> float:
	var cached: bool=source.pose_entry.rendered_pose.rig_id==source.skeleton.get_instance_id() and Engine.get_process_frames()-int(source.pose_entry.displayed_frame)<=1
	# A model's clearance/tilt can change after its last submitted frame too.
	# Capture placement and SourceSpace with the same final bone snapshot.
	if cached:visual.model.transform=source.pose_entry.displayed_model
	start_position=visual.model.position
	plane_origin=source.global_position;plane_normal=Vector3.UP
	for hit: Dictionary in source.contact.contacts.values():
		plane_origin=hit.position;plane_normal=hit.normal.normalized();break
	var space:=source.model.find_child("SourceSpace",true,false) as Node3D
	var target_space:=visual.model.find_child("SourceSpace",true,false) as Node3D
	assert(space!=null and target_space!=null)
	var source_space: Transform3D=source.pose_entry.displayed_space if cached else space.transform
	var source_rig: Skeleton3D=source.pose_entry.displayed_rig(source.skeleton) if cached else source.skeleton
	visual.animator.stop();visual.animator.speed_scale=1.;visual.play("Death",0.)
	visual.animator.seek(0.,true);visual.animator.advance(0.);visual.skeleton.force_update_all_bone_transforms()
	var path: NodePath=visual.animator.get_node(visual.animator.root_node).get_path_to(target_space)
	var animation:=preload("res://Presentation/SourcePoseEntry.gd").build(visual.animator,visual.skeleton,source_rig,{path:source_space})
	if source_rig!=source.skeleton:source_rig.free()
	var library: AnimationLibrary=visual.animator.get_animation_library("").duplicate()
	visual.animator.stop(true);visual.animator.remove_animation_library("");visual.animator.add_animation_library("",library)
	library.remove_animation("Death");library.add_animation("Death",animation)
	skin=Ground.skin_points(visual.model.find_children("*","MeshInstance3D",true,false)[0],visual.skeleton)
	active=true;visual.current_clip="Death";visual.dead=true;visual.action_remaining=animation.length
	visual.contact.enabled=false;visual.blend_remaining=.12
	visual.animator.play("Death",0.);visual.animator.seek(0.,true);visual.animator.advance(0.)
	return animation.length
func support(visual: Node3D) -> void:
	var time: float=visual.animator.current_animation_position
	if time<=0.:
		visual.model.position=start_position;visual.update_landmarks();return
	var calibrated:=anchor+Vector3.UP*Ground.sample(curves,"Death",maxf(0.,time-.08)) if not curves.is_empty() else anchor
	visual.model.position=start_position.lerp(calibrated,clampf(time/.08,0.,1.))
	var gap:=Ground.minimum_plane_gap(skin,visual.skeleton,visual.skeleton.global_transform,plane_origin,plane_normal)
	if gap<0.:visual.model.global_position+=plane_normal*(-gap+.00005)
	visual.update_landmarks()
