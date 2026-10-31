extends SkeletonModifier3D
## Fit a power grip on the fixed human hand; leave wrist/arm swing untouched.
## The animation library has static, open fingers even in its sword idle.
const CURL_DEGREES := {
	"index":[50.,70.,45.],"middle":[55.,75.,45.],
	"ring":[58.,78.,50.],"pinky":[60.,80.,55.],"thumb":[20.,45.,35.]
}
const REIN_CURL_DEGREES := {
	"index":[35.,55.,25.],"middle":[40.,60.,30.],
	"ring":[45.,65.,30.],"pinky":[45.,65.,35.],"thumb":[20.,45.,35.]
}
var holding := false
var left_holding := false
var reins_holding:=false
var left_reins_holding:=false
var left_rotations := {}
var rotations := {}
var rein_rotations: Dictionary={}
var left_rein_rotations: Dictionary={}
func use_prepared_clip(animation: Animation) -> void:
	rotations.clear();left_rotations.clear();rein_rotations.clear();left_rein_rotations.clear()
	var rig:=get_skeleton()
	for track in animation.get_track_count():
		var path:=animation.track_get_path(track)
		if path.get_subname_count()==0 or animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D:continue
		var bone:=str(path.get_subname(0))
		if (bone.ends_with("_r") or bone.ends_with("_l")) and bone.get_slice("_",0) in ["index","middle","ring","pinky","thumb"]:
			var index:=rig.find_bone(bone)
			if index>=0:
				var finger:=bone.get_slice("_",0)
				var segment:=int(bone.get_slice("_",1))-1
				var neutral:=animation.rotation_track_interpolate(track,0.)
				var target: Dictionary=rotations if bone.ends_with("_r") else left_rotations
				target[index]=(neutral*Quaternion(Vector3.RIGHT,deg_to_rad(CURL_DEGREES[finger][segment])*(1. if bone.ends_with("_r") else -1.))).normalized()
				var rein_target: Dictionary=rein_rotations if bone.ends_with("_r") else left_rein_rotations
				rein_target[index]=(neutral*Quaternion(Vector3.RIGHT,deg_to_rad(REIN_CURL_DEGREES[finger][segment])*(1. if bone.ends_with("_r") else -1.))).normalized()
func _ready() -> void:
	var rig := get_skeleton()
	var source: Node3D = load("res://Art/Quaternius/Animation/UAL1_Standard.glb").instantiate()
	var source_rig: Skeleton3D = source.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer = source.find_children("*","AnimationPlayer",true,false)[0]
	var animation := preload("res://Presentation/AnimationRetarget.gd").retarget(player.get_animation("Sword_Idle"),source_rig,rig)
	use_prepared_clip(animation)
	source.free()
func _process_modification_with_delta(_delta: float) -> void:
	if not holding and not left_holding: return
	var rig := get_skeleton()
	if holding:
		var pose: Dictionary=rein_rotations if reins_holding else rotations
		for index in pose:rig.set_bone_pose_rotation(int(index),pose[index])
		if reins_holding:fit_rein_thumb(rig,"r")
	if left_holding:
		var pose: Dictionary=left_rein_rotations if left_reins_holding else left_rotations
		for index in pose:rig.set_bone_pose_rotation(int(index),pose[index])
		if left_reins_holding:fit_rein_thumb(rig,"l")
func fit_rein_thumb(rig: Skeleton3D,side: String) -> void:
	# Oppose the thumb across the curled index instead of leaving a thumbs-up
	# silhouette. Calibrate from each hand's bones, including the mirrored rig.
	var a:=rig.find_bone("thumb_01_"+side);var b:=rig.find_bone("thumb_02_"+side);var c:=rig.find_bone("thumb_03_"+side)
	var pa:=rig.get_bone_global_pose(a).origin;var pb:=rig.get_bone_global_pose(b).origin;var pc:=rig.get_bone_global_pose(c).origin
	var index:=rig.get_bone_global_pose(rig.find_bone("index_02_"+side)).origin
	var first:=pa.distance_to(pb);var second:=pb.distance_to(pc);var offset:=index-pa
	var distance:=clampf(offset.length(),absf(first-second)+.001,first+second-.001);var axis:=offset.normalized()
	var bend:=(pb-pa).slide(axis).normalized()
	var along:=(first*first-second*second+distance*distance)/(2.*distance)
	var joint:=pa+axis*along+bend*sqrt(maxf(0.,first*first-along*along))
	for part in [[a,b,joint],[b,c,pa+axis*distance]]:
		var pose:=rig.get_bone_global_pose(part[0]);var direction:=rig.get_bone_global_pose(part[1]).origin-pose.origin
		pose.basis=Basis(Quaternion(direction.normalized(),(part[2]-pose.origin).normalized()))*pose.basis
		rig.set_bone_global_pose(part[0],pose)
