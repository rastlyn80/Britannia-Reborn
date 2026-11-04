extends SceneTree
## Authored CC0-base replacement, not a recovered Third Dawn actor.
const BASE="res://Art/Quaternius/Character/Superhero_Male_FullBody.gltf"
const ACTIONS="res://Art/Quaternius/Animation/UAL1_Standard.glb"
const OUTPUT="res://local-art/water-elemental/trial.scn"
const WAIST=1.02
const RINGS=20
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var uvs:=PackedVector2Array()
var bones:=PackedInt32Array()
var weights:=PackedFloat32Array()
var boundary: Dictionary={}
var discarded_weight:=0.
func _initialize() -> void:call_deferred("run")
func influence(arrays: Array,index: int) -> Dictionary:
	var result: Dictionary={};var stride: int=arrays[Mesh.ARRAY_BONES].size()/arrays[Mesh.ARRAY_VERTEX].size()
	for slot in stride:
		var weight: float=arrays[Mesh.ARRAY_WEIGHTS][index*stride+slot]
		if weight>0.:result[int(arrays[Mesh.ARRAY_BONES][index*stride+slot])]=weight
	return result
func mix_weights(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
	var result: Dictionary={}
	for key in a:result[key]=float(a[key])*(1.-t)
	for key in b:result[key]=float(result.get(key,0.))+float(b[key])*t
	return result
func interpolate(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
	return {"p":a.p.lerp(b.p,t),"n":a.n.lerp(b.n,t).normalized(),"uv":a.uv.lerp(b.uv,t),"w":mix_weights(a.w,b.w,t)}
func add_vertex(v: Dictionary) -> void:
	vertices.append(v.p);normals.append(v.n);uvs.append(v.uv)
	var order: Array=v.w.keys();order.sort_custom(func(a: int,b: int) -> bool:return float(v.w[a])>float(v.w[b]))
	var total:=0.;var discarded:=0.
	for i in order.size():
		if i<8:total+=float(v.w[order[i]])
		else:discarded+=float(v.w[order[i]])
	discarded_weight=maxf(discarded_weight,discarded)
	for i in 8:
		bones.append(int(order[i]) if i<order.size() else 0)
		weights.append(float(v.w[order[i]])/total if i<order.size() else 0.)
func triangle(a: Dictionary,b: Dictionary,c: Dictionary) -> void:
	add_vertex(a);add_vertex(b);add_vertex(c)
func clipped_body(source: MeshInstance3D,root_bind: int) -> ArrayMesh:
	for surface in source.mesh.get_surface_count():
		var arrays:=source.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			index.resize(points.size())
			for i in points.size():index[i]=i
		for offset in range(0,index.size(),3):
			var polygon: Array=[]
			for corner in 3:
				var i:=index[offset+corner]
				polygon.append({"p":points[i],"n":arrays[Mesh.ARRAY_NORMAL][i],"uv":arrays[Mesh.ARRAY_TEX_UV][i],"w":influence(arrays,i)})
			var clipped: Array=[]
			for edge in 3:
				var a: Dictionary=polygon[edge];var b: Dictionary=polygon[(edge+1)%3]
				var inside: bool=a.p.y>=WAIST;var next_inside: bool=b.p.y>=WAIST
				if inside:clipped.append(a)
				if inside!=next_inside:
					var hit:=interpolate(a,b,(WAIST-a.p.y)/(b.p.y-a.p.y));clipped.append(hit)
					var key: String="%.6f,%.6f"%[hit.p.x,hit.p.z]
					boundary[key]=hit
			for i in range(1,clipped.size()-1):triangle(clipped[0],clipped[i],clipped[i+1])
	var ring: Array=boundary.values()
	ring.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return atan2(a.p.z,a.p.x)<atan2(b.p.z,b.p.x))
	assert(ring.size()>12,"Expected a closed torso cut, not disconnected limbs")
	var grid: Array=[]
	for row in RINGS+1:
		var t:=float(row)/RINGS;var samples: Array=[]
		for i in ring.size():
			var original: Dictionary=ring[i]
			var angle: float=atan2(original.p.z,original.p.x)
			var turn:=angle+t*1.8
			var radial:=Vector2(original.p.x,original.p.z).length()
			var radius:=lerpf(radial,.055,pow(t,.75))*(1.+sin(turn*5.-t*7.)*.10*sin(PI*t))
			var point:=Vector3(cos(turn)*radius,WAIST*(1.-t),sin(turn)*radius)
			var normal:=Vector3(cos(turn),.13,sin(turn)).normalized()
			if row==0:point=original.p;normal=original.n
			var w:=mix_weights(original.w,{root_bind:1.},smoothstep(0.,.75,t))
			samples.append({"p":point,"n":normal,"uv":Vector2(float(i)/ring.size(),t),"w":w})
		grid.append(samples)
	for row in RINGS:
		for i in ring.size():
			var j: int=(i+1)%ring.size()
			# Godot front faces wind clockwise when viewed from outside.
			triangle(grid[row][i],grid[row+1][i],grid[row][j])
			triangle(grid[row][j],grid[row+1][i],grid[row+1][j])
	for i in ring.size():
		var centre: Dictionary={"p":Vector3.ZERO,"n":Vector3.DOWN,"uv":Vector2(.5,.5),"w":{root_bind:1.}}
		triangle(grid[RINGS][i],centre,grid[RINGS][(i+1)%ring.size()])
	var result:=ArrayMesh.new();var out: Array=[];out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX]=vertices;out[Mesh.ARRAY_NORMAL]=normals;out[Mesh.ARRAY_TEX_UV]=uvs;out[Mesh.ARRAY_BONES]=bones;out[Mesh.ARRAY_WEIGHTS]=weights
	# Procedural normal detail needs a valid tangent frame on every triangle.
	var tangents:=PackedFloat32Array()
	for offset in range(0,vertices.size(),3):
		var e1:=vertices[offset+1]-vertices[offset];var e2:=vertices[offset+2]-vertices[offset]
		var uv1:=uvs[offset+1]-uvs[offset];var uv2:=uvs[offset+2]-uvs[offset]
		var determinant:=uv1.x*uv2.y-uv1.y*uv2.x
		var direction: Vector3=(e1*uv2.y-e2*uv1.y)/determinant if absf(determinant)>.000001 else Vector3.RIGHT
		for corner in 3:
			var n:=normals[offset+corner];var tangent: Vector3=(direction-n*n.dot(direction)).normalized()
			if tangent.length()<.5:tangent=n.cross(Vector3.FORWARD).normalized()
			for component in [tangent.x,tangent.y,tangent.z,1.]:tangents.append(component)
	out[Mesh.ARRAY_TANGENT]=tangents
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,out,[],{},Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	result.surface_set_material(0,preload("res://Presentation/WaterElementalMaterial.gd").build())
	return result
func puddle() -> MeshInstance3D:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sector in 80:
		var a:=TAU*float(sector)/80.;var b:=TAU*float(sector+1)/80.
		for point in [Vector3(0.,.025,0.),Vector3(cos(a)*(.61+.05*sin(a*5.)),.012,sin(a)*.5),Vector3(cos(b)*(.61+.05*sin(b*5.)),.012,sin(b)*.5)]:
			tool.set_normal(Vector3.UP);tool.set_tangent(Plane(Vector3.RIGHT,1.));tool.set_uv(Vector2(point.x,point.z));tool.add_vertex(point)
	var result:=MeshInstance3D.new();result.name="Puddle";result.mesh=tool.commit();result.mesh.surface_set_material(0,preload("res://Presentation/WaterElementalMaterial.gd").build());result.visible=false
	return result
func reset_tracks(animation: Animation,actor: Node3D,rig: Skeleton3D,body: MeshInstance3D,pool: MeshInstance3D) -> void:
	var scale_track:=-1
	for track in animation.get_track_count():
		if animation.track_get_type(track)==Animation.TYPE_SCALE_3D and str(animation.track_get_path(track)).ends_with(":root"):scale_track=track
	if scale_track<0:scale_track=animation.add_track(Animation.TYPE_SCALE_3D);animation.track_set_path(scale_track,NodePath(str(actor.get_path_to(rig))+":root"))
	for key in range(animation.track_get_key_count(scale_track)-1,-1,-1):animation.track_remove_key(scale_track,key)
	animation.track_insert_key(scale_track,0.,Vector3.ONE)
	for pair in [[body,true],[pool,false]]:
		var track:=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(track,NodePath(str(actor.get_path_to(pair[0]))+":visible"));animation.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE);animation.track_insert_key(track,0.,pair[1])
func own(node: Node,scene: Node) -> void:
	for child in node.get_children():child.owner=scene;own(child,scene)

func add_legacy_water_actions(player: AnimationPlayer, rig: Skeleton3D, library: AnimationLibrary) -> void:
	var upper := rig.find_bone("upperarm_r")
	var elbow := rig.find_bone("lowerarm_r")
	assert(upper >= 0 and elbow >= 0)
	var keys := {
		"OverheadSurge": [[0.0, Vector3.ZERO], [0.23, Vector3(-0.8, 0.2, -0.3)],
			[0.48, Vector3(-0.25, 0.95, -0.08)], [0.72, Vector3(-0.25, -0.24, -0.95)], [1.0, Vector3.ZERO]],
		"WaterHold": [[0.0, Vector3(-0.35, -0.75, -0.55)]],
	}
	for clip: String in keys:
		var motion := library.get_animation("Idle").duplicate(true) as Animation
		motion.length = 1.0
		motion.loop_mode = Animation.LOOP_NONE
		var arm_track := -1
		for track in motion.get_track_count():
			var value: Variant = motion.track_get_key_value(track, 0)
			for key in range(motion.track_get_key_count(track) - 1, -1, -1):
				motion.track_remove_key(track, key)
			motion.track_insert_key(track, 0.0, value)
			if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D and str(motion.track_get_path(track)).ends_with(":upperarm_r"):
				arm_track = track
		assert(arm_track >= 0)
		for key: Array in keys[clip]:
			player.play("Idle")
			player.seek(0.0, true)
			rig.force_update_all_bone_transforms()
			var target: Vector3 = key[1]
			if not target.is_zero_approx():
				var pose := rig.get_bone_global_pose(upper)
				var current := (rig.get_bone_global_pose(elbow).origin - pose.origin).normalized()
				pose.basis = Basis(Quaternion(current, target.normalized())) * pose.basis
				rig.set_bone_global_pose(upper, pose)
			motion.rotation_track_insert_key(arm_track, key[0], rig.get_bone_pose_rotation(upper))
		library.add_animation(clip, motion)
	player.stop()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var actor: Node3D=load(BASE).instantiate();actor.name="WaterElemental";root.add_child(actor)
	var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
	var body: MeshInstance3D
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.name=="SuperHero_Male":body=mesh
		else:mesh.free() # No human eyebrows or eyeballs in the fluid silhouette.
	var root_bind:=-1
	for bind in body.skin.get_bind_count():
		var bone:=body.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(body.skin.get_bind_name(bind))
		if rig.get_bone_name(bone)=="root":root_bind=bind
	assert(root_bind>=0)
	body.mesh=clipped_body(body,root_bind);body.name="FluidBody"
	body.skin=body.skin.duplicate() # Keep the distributable scene self-contained.
	var pool:=puddle();actor.add_child(pool)
	var source: Node3D=load(ACTIONS).instantiate();root.add_child(source)
	var source_rig: Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
	var source_player: AnimationPlayer=source.find_children("*","AnimationPlayer",true,false)[0]
	var player:=AnimationPlayer.new();player.name="AnimationPlayer";actor.add_child(player)
	var library:=AnimationLibrary.new();player.add_animation_library("",library)
	var mapping: Dictionary={"Idle":"Idle","Walk":"Walk","Run":"Jog_Fwd","Attack":"Punch_Jab","Attack2":"Punch_Cross","Attack3":"Sword_Attack","Hit":"Hit_Chest","Hit2":"Hit_Head","Fidget":"Idle_Talking","Cast":"Spell_Simple_Shoot","Cast2":"Spell_Simple_Enter","Cast3":"Spell_Simple_Exit","Pillage":"PickUp_Table"}
	for clip: String in mapping:
		var animation: Animation=preload("res://Presentation/AnimationRetarget.gd").retarget(source_player.get_animation(mapping[clip]),source_rig,rig)
		for track in range(animation.get_track_count()-1,-1,-1):
			var path:=animation.track_get_path(track)
			if path.get_subname_count()!=1 or rig.find_bone(str(path.get_subname(0)))<0:animation.remove_track(track);continue
			var bone_name:=str(path.get_subname(0));var bone:=rig.find_bone(bone_name)
			animation.track_set_path(track,NodePath(str(actor.get_path_to(rig))+":"+bone_name))
			if bone_name=="root" and animation.track_get_type(track)==Animation.TYPE_POSITION_3D:
				for key in animation.track_get_key_count(track):animation.track_set_key_value(track,key,rig.get_bone_rest(bone).origin)
		animation.loop_mode=Animation.LOOP_LINEAR if clip in ["Idle","Walk","Run","Fidget"] else Animation.LOOP_NONE
		reset_tracks(animation,actor,rig,body,pool)
		library.add_animation(clip,animation)
	# A fluid collapse, not a human falling onto invisible legs. Source pose is held.
	for clip in ["Death","Death2"]:
		var animation: Animation=library.get_animation("Idle").duplicate(true);animation.loop_mode=Animation.LOOP_NONE;animation.length=1.25
		for track in animation.get_track_count():
			var value: Variant=animation.track_get_key_value(track,0)
			for key in range(animation.track_get_key_count(track)-1,-1,-1):animation.track_remove_key(track,key)
			animation.track_insert_key(track,0.,value)
		for track in animation.get_track_count():
			var path:=str(animation.track_get_path(track))
			if animation.track_get_type(track)==Animation.TYPE_SCALE_3D and path.ends_with(":root"):
				animation.track_insert_key(track,.35,Vector3(1.12,1.12,.9));animation.track_insert_key(track,1.25,Vector3(1.9,1.9,.055))
			elif path.ends_with("FluidBody:visible"):animation.track_insert_key(track,1.25,false)
			elif path.ends_with("Puddle:visible"):animation.track_insert_key(track,.75,true)
		library.add_animation(clip,animation)
	add_legacy_water_actions(player, rig, library)
	source.free();own(actor,actor)
	var packed:=PackedScene.new();assert(packed.pack(actor)==OK);assert(ResourceSaver.save(packed,OUTPUT)==OK)
	var clips: Dictionary={}
	for clip in player.get_animation_list():
		var animation:=player.get_animation(clip)
		var origin := "Retargeted Quaternius UAL1 Standard: " + str(mapping.get(clip, ""))
		if clip.begins_with("Death"):
			origin = "Authored liquid collapse"
		elif clip in ["OverheadSurge", "WaterHold"]:
			origin = "Authored pose from visual inspection of original Water Elemental slots 7 and 8"
		clips[clip]={"duration":animation.length,"loop":animation.loop_mode==Animation.LOOP_LINEAR,"origin":origin,"support_policy":"fluid_base"}
	var envelope:=AABB();var first:=true
	for clip in player.get_animation_list():
		for sample in 9:
			player.play(clip,0.);player.seek(player.get_animation(clip).length*float(sample)/8.,true);player.pause();rig.force_update_all_bone_transforms()
			var box:=preload("res://Presentation/SkinGeometry.gd").deformed_bounds(body,rig)
			envelope=box if first else envelope.merge(box);first=false
	envelope=envelope.grow(.035)
	var report:=FileAccess.open(OUTPUT.get_base_dir()+"/preparation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"triangles":vertices.size()/3,"seam_vertices":boundary.size(),"bones":rig.get_bone_count(),"discarded_weight":discarded_weight,"clips":clips,"envelope":{"position":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]}},"  "));report.close()
	print("WATER PREPARED ",vertices.size()/3," triangles, ",boundary.size()," seam vertices, ",rig.get_bone_count()," bones; max discarded weight ",discarded_weight)
	actor.free();quit()
