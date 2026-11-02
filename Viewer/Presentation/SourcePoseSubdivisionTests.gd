extends SceneTree
## Source-free counterexample: averaging positions/weights changes posed geometry.
const Refine=preload("res://Presentation/SourcePoseSubdivision.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var rig:=Skeleton3D.new();root.add_child(rig)
	for i in 3:rig.add_bone("source"+str(i));rig.set_bone_rest(i,Transform3D.IDENTITY)
	var source_points:=PackedVector3Array([Vector3(-1,0,0),Vector3(1,0,0),Vector3(0,1,0)]);var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=source_points;arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD]);arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(0,1)]);arrays[Mesh.ARRAY_BONES]=PackedInt32Array([0,0,0,0,1,0,0,0,2,0,0,0]);arrays[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2]);var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);var skin:=Skin.new()
	for i in 3:skin.add_bind(i,Transform3D.IDENTITY)
	var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.skin=skin;rig.add_child(instance);instance.skeleton=NodePath("..");var report:=Refine.apply(instance,rig,2,0.);var data:=instance.mesh.surface_get_arrays(0);var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX];var uv: PackedVector2Array=data[Mesh.ARRAY_TEX_UV];var bindings: PackedInt32Array=data[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=data[Mesh.ARRAY_WEIGHTS];var checks:=0;var failures:=0;var worst:=0.;var conventional_error:=0.
	for frame in 61:
		var time:=float(frame)/60.
		for bone in 3:rig.set_bone_pose_position(bone,Vector3(sin(time*6.+bone)*.4,cos(time*4.+bone)*.3,0));rig.set_bone_pose_rotation(bone,Quaternion(Vector3(1.+bone,2.,3.-bone).normalized(),sin(time*5.+bone)*1.3))
		rig.force_update_all_bone_transforms();var transforms: Array[Transform3D]=[]
		for bone in 3:transforms.append(rig.get_bone_global_pose(bone))
		for vertex in points.size():
			var expected: Vector3=(transforms[0]*source_points[0])*(1.-uv[vertex].x-uv[vertex].y)+(transforms[1]*source_points[1])*uv[vertex].x+(transforms[2]*source_points[2])*uv[vertex].y;var actual:=Vector3.ZERO
			var decoded: Array[float]=[0.,0.,0.]
			for slot in 8:
				var bind:=bindings[vertex*8+slot];var bone:=instance.skin.get_bind_bone(bind);decoded[bone]+=weights[vertex*8+slot];actual+=(rig.get_bone_global_pose(bone)*instance.skin.get_bind_pose(bind)*points[vertex])*weights[vertex*8+slot]
			var error:=actual.distance_to(expected);worst=maxf(worst,error);checks+=1
			# ArrayMesh quantises stored weights. Bound only that measured loss,
			# independently from the inverse-bind construction being tested.
			var coefficients: Array[float]=[1.-uv[vertex].x-uv[vertex].y,uv[vertex].x,uv[vertex].y];var allowance:=.000002
			for bone in 3:allowance+=absf(decoded[bone]-coefficients[bone])*(transforms[bone]*source_points[bone]).length()
			if error>allowance:failures+=1
		var midpoint: Vector3=(source_points[0]+source_points[1])*.5;var naive: Vector3=((transforms[0]*midpoint)+(transforms[1]*midpoint))*.5;var target: Vector3=((transforms[0]*source_points[0])+(transforms[1]*source_points[1]))*.5;conventional_error=maxf(conventional_error,naive.distance_to(target))
	checks+=2
	if int(report.triangles)!=16 or rig.get_bone_count()!=3:failures+=1
	if conventional_error<.1:failures+=1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/amorphous"));FileAccess.open("res://../outputs/creatures/amorphous/subdivision.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"poses":61,"source_bones":3,"refined_triangles":report.triangles,"maximum_source_barycentric_error_m":worst,"conventional_interpolated_skin_error_m":conventional_error,"recipe_sha256":FileAccess.get_sha256("res://Presentation/SourcePoseSubdivision.gd"),"test_sha256":FileAccess.get_sha256("res://Presentation/SourcePoseSubdivisionTests.gd"),"scope":"Independent synthetic source-triangle deformation under61joint poses. Each refined position must equal barycentric interpolation of actual original posed corners; no additional bones. Ordinary averaged position/weights must expose the counterexample. Actual creature GPU/source/terrain proof remains separate."}));print("SOURCE POSE SUBDIVISION: ",checks," / ",failures," failures / exact pose error ",worst," / ordinary LBS error ",conventional_error);rig.free();quit(1 if failures else 0)
