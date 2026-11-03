extends "res://Presentation/SourcePreservingCreatureVisual.gd"
## Shared source asset, explicit baked baseline versus native target proportions.
func apply_identity(body: int,value: int,item: int=0) -> void:
	super.apply_identity(body,value,item)
	var base: Array=entry.asset_base_scale
	for identity: Dictionary in entry.bodies:
		if int(identity.body)!=body:continue
		var target: Array=identity.scale
		model.scale=default_model_scale*Vector3(float(target[0])/float(base[0]),float(target[1])/float(base[1]),float(target[2])/float(base[2]))
		contact.flat_basis=source_model_basis.scaled_local(model.scale)
		break
	update_landmarks()
