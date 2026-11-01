extends "res://Presentation/CatGroundSupport.gd"
## Original four rabbit paws, including the longer four-joint hind chains.
func configure(mesh: MeshInstance3D,quadruped: bool) -> void:
	super.configure(mesh,quadruped);feet.clear();iterations=6
	var rig:=get_skeleton();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	for side: String in ["L","R"]:
		for prefix: String in ["Front","Back"]:
			var upper:=rig.find_bone(prefix+"UpLeg_"+side);var lower:=rig.find_bone(prefix+"Leg_"+side);var ankle:=rig.find_bone(prefix+"Leg_"+side+".001") if prefix=="Back" else rig.find_bone(prefix+"Paw_"+side);var paw:=rig.find_bone(prefix+"Paw_"+side)
			assert(mini(upper,mini(lower,mini(ankle,paw)))>=0,"Missing original rabbit leg chain")
			var record:={"a":upper,"b":lower,"c":ankle,"end":paw,"vertices":[],"source_leg":prefix+side};var seen: Dictionary={}
			for vertex in vertices.size():
				var influence:=0.
				for j in stride:
					var bind:=joints[vertex*stride+j];var index:=surface.skin.get_bind_bone(bind)
					if index<0:index=rig.find_bone(surface.skin.get_bind_name(bind))
					if index==paw:influence+=weights[vertex*stride+j]
				if influence>.6 and not seen.has(vertices[vertex]):record.vertices.append(vertex);seen[vertices[vertex]]=true
			assert(not record.vertices.is_empty(),"Rabbit paws require actual weighted source sole vertices")
			feet.append(record)
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear();stance_gaps.clear()
	if not enabled or surface==null:return
	for i in feet.size():
		if not contacts.has(i):continue
		var record: Dictionary=feet[i];var point:=sole(record);var hit: Dictionary=contacts[i]
		# Release the genuine small-animal swing and entire airborne hop. The
		# relevant surface is below this paw, not the actor's centre height.
		var strength:=1.-smoothstep(.008,.024,maxf(0.,point.y-float(hit.position.y)))
		if strength<=.001:continue
		align_sole(record,hit.position.y,strength)
		if strength>.95:
			var gap:=sole(record).y-float(hit.position.y);errors.append(absf(gap));stance_gaps.append(gap)
