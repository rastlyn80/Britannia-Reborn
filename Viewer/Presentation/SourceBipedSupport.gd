extends "res://Presentation/SourceMountContact.gd"
## Preserve the short swing of small source bipeds; large-animal thresholds
## can pull an entire 5cm shuffling step back onto the floor.
func configure(mesh: MeshInstance3D,_quadruped: bool) -> void:
	assert(mesh.mesh.get_surface_count()==1,"Source biped support requires the measured single-surface four-weight source skin")
	var data:=mesh.mesh.surface_get_arrays(0)
	assert(data[Mesh.ARRAY_WEIGHTS].size()==data[Mesh.ARRAY_VERTEX].size()*4,"Source biped skin influence layout changed")
	super.configure(mesh,false);align_skinned_soles=true;iterations=6
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear();stance_gaps.clear()
	if not enabled or surface==null:return
	for i in feet.size():
		if not contacts.has(i):continue
		var record: Dictionary=feet[i];var point:=sole(record);var hit: Dictionary=contacts[i]
		# The terrain below this foot can be centimetres above the actor's
		# centre on a slope. Classify swing against that sampled surface.
		var strength:=1.-smoothstep(.015,.03,maxf(0.,point.y-float(hit.position.y)))
		if strength<=.001:continue
		align_sole(record,hit.position.y,strength)
		if strength>.95:
			var gap:=sole(record).y-float(hit.position.y);errors.append(absf(gap));stance_gaps.append(gap)
