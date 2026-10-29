extends SkeletonModifier3D
## Keep bulky held objects clear of the hip while retaining the source arm swing.
var book:=false
var lantern:=false
func aim(rig: Skeleton3D,bone: int,child: int,target: Vector3) -> void:
	var pose:=rig.get_bone_global_pose(bone);var direction:=rig.get_bone_global_pose(child).origin-pose.origin
	pose.basis=Basis(Quaternion(direction.normalized(),(target-pose.origin).normalized()))*pose.basis
	rig.set_bone_global_pose(bone,pose)
func solve(rig: Skeleton3D,side: String,offset: Vector3) -> void:
	var a:=rig.find_bone("upperarm_"+side);var b:=rig.find_bone("lowerarm_"+side);var c:=rig.find_bone("hand_"+side)
	var pa:=rig.get_bone_global_pose(a).origin;var pb:=rig.get_bone_global_pose(b).origin;var pc:=rig.get_bone_global_pose(c).origin
	var first:=pa.distance_to(pb);var second:=pb.distance_to(pc);var target:=pc+offset;var vector:=target-pa;var distance:=clampf(vector.length(),absf(first-second)+.001,first+second-.001);var direction:=vector.normalized();target=pa+direction*distance
	var pole:=pb-pa-direction*direction.dot(pb-pa)
	if pole.length()<.001:pole=Vector3.FORWARD-direction*direction.z
	pole=pole.normalized();var along:=(first*first-second*second+distance*distance)/(2.*distance);var height:=sqrt(maxf(0.,first*first-along*along));var elbow:=pa+direction*along+pole*height
	aim(rig,a,b,elbow);aim(rig,b,c,target)
func _process_modification() -> void:
	var rig:=get_skeleton()
	if rig==null:return
	if book:solve(rig,"r",Vector3(-.07,0,.06))
	if lantern:solve(rig,"l",Vector3(.10,0,.08))
