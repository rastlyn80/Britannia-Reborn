extends SkeletonModifier3D
## Fit a power grip on the fixed human hand; leave wrist/arm swing untouched.
## The animation library has static, open fingers even in its sword idle.
const CURL_DEGREES := {
	"index":[50.,70.,45.],"middle":[55.,75.,45.],
	"ring":[58.,78.,50.],"pinky":[60.,80.,55.],"thumb":[20.,45.,35.]
}
var holding := false
var rotations := {}
func use_prepared_clip(animation: Animation) -> void:
	rotations.clear()
	var rig:=get_skeleton()
	for track in animation.get_track_count():
		var path:=animation.track_get_path(track)
		if path.get_subname_count()==0 or animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D:continue
		var bone:=str(path.get_subname(0))
		if bone.ends_with("_r") and bone.get_slice("_",0) in ["index","middle","ring","pinky","thumb"]:
			var index:=rig.find_bone(bone)
			if index>=0:
				var finger:=bone.get_slice("_",0)
				var segment:=int(bone.get_slice("_",1))-1
				var neutral:=animation.rotation_track_interpolate(track,0.)
				rotations[index]=(neutral*Quaternion(Vector3.RIGHT,deg_to_rad(CURL_DEGREES[finger][segment]))).normalized()
func _ready() -> void:
	var rig := get_skeleton()
	var source: Node3D = load("res://Art/Quaternius/Animation/UAL1_Standard.glb").instantiate()
	var source_rig: Skeleton3D = source.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer = source.find_children("*","AnimationPlayer",true,false)[0]
	var animation := preload("res://Presentation/AnimationRetarget.gd").retarget(player.get_animation("Sword_Idle"),source_rig,rig)
	use_prepared_clip(animation)
	source.free()
func _process_modification_with_delta(_delta: float) -> void:
	if not holding: return
	var rig := get_skeleton()
	for index in rotations: rig.set_bone_pose_rotation(int(index),rotations[index])
