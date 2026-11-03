extends "res://Presentation/SourcePreservingCreatureVisual.gd"
## Shared original-rig mount fittings. Native permissions remain server-owned.
var seat_bone:=-1
var mouth_bone:=-1
var seat_offset:=Vector3.ZERO
var mouth_offset:=Vector3.ZERO
var reins: MeshInstance3D
var rein_mesh:=ImmediateMesh.new()
var fittings: Dictionary={}
func mount_fittings() -> Dictionary:
	assert(false,"Source mount requires explicit authored fittings");return {}
func find_bone(suffix: String) -> int:
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone).replace("_","")=="bip01 "+suffix:return bone
	return -1
func _ready() -> void:
	super._ready();fittings=mount_fittings()
	var proportions: Vector3=fittings.proportions if treatment=="modern" else Vector3.ONE
	default_model_scale*=proportions;model.scale=default_model_scale
	contact.flat_basis=source_model_basis.scaled_local(default_model_scale)
	set_meta("authored_proportions",proportions)
	seat_bone=find_bone(str(fittings.seat_bone));mouth_bone=find_bone(str(fittings.mouth_bone))
	assert(seat_bone>=0 and mouth_bone>=0,"Original mount socket bones missing")
	var saddle: Vector3=fittings.saddle*proportions;var mouth: Vector3=fittings.mouth*proportions
	seat_offset=skeleton.get_bone_global_rest(seat_bone).affine_inverse()*(skeleton.global_transform.affine_inverse()*(global_transform*saddle))
	mouth_offset=skeleton.get_bone_global_rest(mouth_bone).affine_inverse()*(skeleton.global_transform.affine_inverse()*(global_transform*mouth))
	set_meta("rider_ground_drop",saddle.y-.09)
	reins=MeshInstance3D.new();reins.name="AuthoredSourceReins";reins.mesh=rein_mesh;add_child(reins)
	var material:=StandardMaterial3D.new();material.albedo_color=Color("30251d");material.roughness=.9;reins.material_override=material
func anchor(bone: int,offset: Vector3) -> Transform3D:
	var pose:=skeleton.get_bone_global_pose(bone)
	var delta:=skeleton.global_basis*pose.basis*skeleton.get_bone_global_rest(bone).basis.inverse()*skeleton.global_basis.inverse()
	var facing:=global_basis*(model.basis*source_model_basis.inverse()).orthonormalized()
	return Transform3D(delta.orthonormalized()*facing,skeleton.to_global(pose*offset))
func seat() -> Transform3D:return anchor(seat_bone,seat_offset)
func apply_identity(body: int,value: int,item: int=0) -> void:
	super.apply_identity(body,value,item);set_meta("native_mount_item",item)
func stirrup(left: bool) -> Vector3:
	var offset: Vector3=fittings.stirrup;offset.x*=1. if left else -1.;return seat()*offset
func socket(_name: String,_rotation_delta: bool=false) -> Transform3D:return anchor(mouth_bone,mouth_offset)
func motion(speed: float,turn_rate: float,delta: float) -> void:
	lean=lerpf(lean,clampf(turn_rate*minf(speed,6.)*.009,-.065,.065),1.-exp(-6.*delta))
func set_reins(left: Vector3,right: Vector3) -> void:
	rein_mesh.clear_surfaces();rein_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.,1.]:
		var a:=to_local(socket("mouth").origin+global_basis.x*side*.10);var b:=to_local(left if side>0 else right)
		for step in 16:
			var t:=float(step)/16.;var u:=float(step+1)/16.
			var p:=a.lerp(b,t)+Vector3.DOWN*.12*sin(PI*t);var q:=a.lerp(b,u)+Vector3.DOWN*.12*sin(PI*u)
			var across:=(q-p).cross(Vector3.UP).normalized()*.004
			for point in [p-across,q-across,q+across,p-across,q+across,p+across]:rein_mesh.surface_add_vertex(point)
	rein_mesh.surface_end()
