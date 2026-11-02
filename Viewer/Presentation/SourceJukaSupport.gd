extends "res://Presentation/SourceMageSupport.gd"
## Preserve a measured two-foot airborne interval in the original gait blend.
var airborne_height:=0.
func source_airborne_height() -> float:
	if full_skin.is_empty():return 0.
	var lifts:=source_lifts()
	if lifts.size()!=2 or lifts[0]<.015 or lifts[1]<.015:return 0.
	var rig:=get_skeleton()
	var reference:=Transform3D(flat_basis,Vector3.ZERO)*model_root.global_transform.affine_inverse()*rig.global_transform
	var minimum:=Ground.minimum_plane_gap(full_skin,rig,reference,Vector3.ZERO,Vector3.UP)
	return minimum if minimum>=.015 else 0.
func _process_modification_with_delta(delta: float) -> void:
	airborne_height=source_airborne_height()
	super._process_modification_with_delta(delta)
func balance_contacts(lifts: Array[float]) -> void:
	if airborne_height<=0.:
		super.balance_contacts(lifts);return
	if contacts.size()!=feet.size():return
	var hit: Dictionary=contacts[0];var normal: Vector3=hit.normal;var origin: Vector3=hit.position
	for other: Dictionary in contacts.values():
		if normal.dot(other.normal)<.999 or absf(normal.dot(other.position-origin))>.004:return
	var rig:=get_skeleton()
	var minimum:=Ground.minimum_plane_gap(full_skin,rig,rig.global_transform,origin,normal)-airborne_height
	var maximum:=minimum
	for index in feet.size():
		var residual: float=normal.dot(sole(feet[index])-origin)-lifts[index]
		minimum=minf(minimum,residual);maximum=maxf(maximum,residual)
	var correction:=clampf(-(minimum+maximum)*.5,-.02,.02)
	var vertical: Vector3=model_root.get_parent_node_3d().global_basis.y
	model_root.position.y+=correction/maxf(.75,normal.dot(vertical))
