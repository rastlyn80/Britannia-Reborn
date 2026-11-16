# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Donor := 9
const Clips := {
	"SlasherIdle": [1.75, 1], "Death": [1.45, 2], "Death2": [1.55, 3],
	"SlasherRake": [.85, 4], "SlasherDoubleClaw": [1.13, 5], "SlasherRecoil": [.60, 10],
	"SlasherFear": [1.20, 12], "SlasherGuard": [.87, 15], "SlasherVeil": [1.18, 23],
	"SlasherSurvey": [1.20, 26], "SlasherFire": [1.28, 27],
}
const Joints := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "bip01 tail", "bip01 tail1", "bip01 tail2"]
var cloth_joints: PackedInt32Array


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var folder := OS.get_environment("BR_SLASHER_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	var donor := Registry.entry(Donor)
	var proof := {}
	for style: String in ["original", "rounded", "modern"]:
		var path := Registry.asset_path(donor, style)
		var digest := FileAccess.get_sha256(path)
		assert(digest == donor.asset_sha256[style])
		var actor := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(actor)
		var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var animator := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() == 55 and rig.get_bone_name(51) == "bip01 tail")
		refit(mesh, rig)
		var skin := Ground.skin_points(mesh, rig)
		var library := animator.get_animation_library("")
		for name: String in Clips:
			var options: Array = Clips[name]
			var motion := fit_grounded(animator, rig, [skin], options[0], "bip01", Joints, pose_slasher.bind(options[1]))
			replace(library, name, motion)
		var aliases := {"Idle":"SlasherIdle", "ReadyStance":"SlasherIdle", "Attack":"SlasherRake",
			"Attack2":"SlasherDoubleClaw", "Fidget":"SlasherSurvey", "Cast":"SlasherFear", "Hit":"SlasherRecoil"}
		for name: String in aliases:
			replace(library, name, library.get_animation(aliases[name]).duplicate(true))
		for name: String in library.get_animation_list():
			fit_cloth(animator, rig, library.get_animation(name), name)
		animator.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		var out := folder.path_join("741-%s.scn" % style)
		assert(scene.pack(actor) == OK and ResourceSaver.save(scene, out, ResourceSaver.FLAG_COMPRESS) == OK)
		proof[style] = {"donor": digest, "scene": FileAccess.get_sha256(out),
			"bones": rig.get_bone_count(), "cape_bones": cloth_joints.size(), "vertices": skin.source_vertices}
		print("SLASHER FIT: ", style, " / ", proof[style])
		actor.free()
	var output := FileAccess.open(folder.path_join("fitted-scenes.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(proof, "\t"))
	output.close()
	quit()


func replace(library: AnimationLibrary, name: String, clip: Animation) -> void:
	if library.has_animation(name):
		library.remove_animation(name)
	assert(library.add_animation(name, clip) == OK)


func refit(mesh: MeshInstance3D, rig: Skeleton3D) -> void:
	var source := mesh.mesh
	var output := ArrayMesh.new()
	mesh.skin = mesh.skin.duplicate() as Skin
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var links: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var faces: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var stride := weights.size() / points.size()
		var colour := PackedColorArray()
		colour.resize(points.size())
		var wing := PackedByteArray()
		wing.resize(points.size())
		for i in points.size():
			var spread := .0
			var fingers := .0
			var tail := .0
			var crown := .0
			for j in stride:
				var k := i * stride + j
				var binding := links[k]
				var bone := mesh.skin.get_bind_bone(binding)
				if bone < 0:
					bone = rig.find_bone(mesh.skin.get_bind_name(binding))
				var w := weights[k]
				if bone >= 7 and bone <= 19:
					spread += w
				elif bone in [27,28,29,30,36,37,38,39]:
					fingers += w
				elif bone in [51,52,53]:
					tail += w
				elif bone == 22:
					crown += w
			wing[i] = int(spread > .29 or point_is_outer_wing(points[i]))
			var point := points[i]
			var emerging := smoothstep(.06, .9, fingers)
			var bend := smoothstep(.18, .90, tail)
			var temple := smoothstep(2.90, 3.30, point.z) * crown
			var stretch := Vector3(1.0 + .20 * emerging, 1.0 + .43 * bend, 1.0)
			point *= stretch
			point.z -= .18 * emerging
			point.z -= .21 * temple
			point.y -= .16 * emerging
			point.x += signf(point.x) * .10 * emerging
			points[i] = point
			normals[i] = (normals[i] / stretch).normalized()
			var sienna := Color(.57,.215,.125)
			var ochre := Color(.80,.36,.17)
			var smoke := Color(.23,.11,.10)
			var low := 1.0 - smoothstep(.12,.77,point.z)
			colour[i] = sienna.lerp(ochre, crown*.26).lerp(smoke, maxf(low*.45, bend*.53))
		var keep := PackedInt32Array()
		for i in range(0, faces.size(), 3):
			if wing[faces[i]] + wing[faces[i+1]] + wing[faces[i+2]] >= 2:
				continue
			for c in 3:
				keep.append(faces[i+c])
		assert(keep.size() < faces.size() and not keep.is_empty())
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colour
		arrays = compact_surface(arrays, keep, stride)
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		var material := source.surface_get_material(surface).duplicate() as StandardMaterial3D
		material.albedo_texture = regrade(material.albedo_texture)
		tintable(material, .83)
		output.surface_set_material(output.get_surface_count() - 1, material)
	var costume := SurfaceTool.new()
	costume.begin(Mesh.PRIMITIVE_TRIANGLES)
	build_mantle(costume, mesh.skin, rig)
	build_brooches(costume, mesh.skin, rig)
	costume.index()
	costume.commit(output)
	var fabric := StandardMaterial3D.new()
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.fill(Color(.43,.37,.46))
	fabric.albedo_texture = ImageTexture.create_from_image(img)
	tintable(fabric, .92)
	output.surface_set_material(output.get_surface_count() - 1, fabric)
	mesh.mesh = output
	rig.reset_bone_poses()


func tintable(material: StandardMaterial3D, roughness: float) -> void:
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_color = Color.WHITE
	material.roughness = roughness


func regrade(texture: Texture2D) -> ImageTexture:
	var image := texture.get_image()
	if image.is_compressed():
		assert(image.decompress() == OK)
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var input := image.get_pixel(x,y)
			var gray := .07 + .90 * pow(maxf(input.r, maxf(input.g,input.b)), .72)
			image.set_pixel(x,y,Color(gray,gray,gray,input.a))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func build_mantle(tool: SurfaceTool, skin: Skin, rig: Skeleton3D) -> void:
	cloth_joints = PackedInt32Array()
	var bindings: Array[PackedInt32Array] = []
	for column in 5:
		var across := float(column) / 4.0
		var parent := 6
		var chain := PackedInt32Array()
		for row in 4:
			var progress := float(row) / 3.0
			var point := mantle_point(across, progress)
			var rest := Transform3D(Basis.IDENTITY, point)
			var joint := rig.get_bone_count()
			var key := "slasher_mantle_%d_%d" % [column,row]
			rig.add_bone(key)
			rig.set_bone_parent(joint,parent)
			rig.set_bone_rest(joint,rig.get_bone_global_rest(parent).affine_inverse()*rest)
			skin.add_named_bind(key,rest.affine_inverse())
			chain.append(skin.get_bind_count()-1)
			cloth_joints.append(joint)
			parent = joint
		bindings.append(chain)
	var strips := 40
	var rings := 26
	for col in strips:
		for row in rings:
			var torn := ((col >= 10 and col <= 12 and row >= 17 and row <= 21)
				or (col >= 27 and col <= 29 and row >= 19 and row <= 22)
				or (col % 9 in [0,1] and row >= 24)
				or (col % 11 == 3 and row >= 25))
			if torn:
				continue
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var u := float(col+corner.x)/strips
				var v := float(row+corner.y)/rings
				var x := mini(3,floori(u*4))
				var y := mini(2,floori(v*3))
				var blend_x := u*4-x
				var blend_y := v*3-y
				var normal := (mantle_point(u+.002,v)-mantle_point(u-.002,v)).cross(
					mantle_point(u,v+.002)-mantle_point(u,v-.002)).normalized()
				var shade := .47 + .18 * cos(u * TAU * 6) + .06 * sin(v * 75.0 + u * 52.0)
				var tint := Color(.045,.027,.061).lerp(Color(.18,.118,.208), shade)
				var bones := PackedInt32Array([bindings[x][y],bindings[x+1][y],bindings[x][y+1],bindings[x+1][y+1]])
				var weights := PackedFloat32Array([(1.0-blend_x)*(1.0-blend_y),blend_x*(1.0-blend_y),(1.0-blend_x)*blend_y,blend_x*blend_y])
				emit(tool,mantle_point(u,v),normal,tint,Vector2(u,v),bones,weights)


func mantle_point(u: float, v: float) -> Vector3:
	var side := u*2.0-1.0
	var folded := .064 * sin(u * TAU * 6.0) * sin(v * PI * .53)
	var hem := (.19 * sin(u * TAU * 3.0) + .09 * cos(u * TAU * 11.0)) * pow(v,4.0)
	return Vector3(side * (.77 + .21 * v), .12 + v * 1.31 + folded - .27 * side * side,
		2.75 - 1.55 * v - .16 * absf(side) + hem)


func point_is_outer_wing(point: Vector3) -> bool:
	return point.z > 3.52 and point.y > .08 or point.y > 1.28 and point.z > 1.88


func compact_surface(arrays: Array, indices: PackedInt32Array, weights_per_vertex: int) -> Array:
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var remap := PackedInt32Array()
	remap.resize(count)
	remap.fill(-1)
	var kept := PackedInt32Array()
	var remapped := PackedInt32Array()
	for prior: int in indices:
		var index := remap[prior]
		if index < 0:
			index = kept.size()
			remap[prior] = index
			kept.append(prior)
		remapped.append(index)
	for attribute in Mesh.ARRAY_MAX:
		if attribute == Mesh.ARRAY_INDEX or arrays[attribute] == null or arrays[attribute].is_empty():
			continue
		var values: Variant = arrays[attribute]
		var packed: Variant = values.duplicate()
		packed.clear()
		var stride := weights_per_vertex if attribute in [Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_BONES] else (4 if attribute == Mesh.ARRAY_TANGENT else 1)
		assert(values.size() == count * stride)
		for prior in kept:
			for slot in stride:
				packed.append(values[prior * stride + slot])
		arrays[attribute] = packed
	arrays[Mesh.ARRAY_INDEX] = remapped
	return arrays


func build_brooches(tool: SurfaceTool, skin: Skin, rig: Skeleton3D) -> void:
	var binding := -1
	for index in skin.get_bind_count():
		var name := skin.get_bind_name(index)
		if name == rig.get_bone_name(6) or skin.get_bind_bone(index) == 6:
			binding = index
			break
	assert(binding >= 0)
	var gold := Color(.36,.21,.39)
	for side in [-1.0,1.0]:
		for index in 4:
			var centre := Vector3(side*(.27+.105*index),-.37+.015*index,2.63+.055*sin(float(index)))
			var radius := .079 if index == 0 else .055
			var gem := Color(.73,.38,.87) if index % 2 == 0 else Color(.41,.16,.57)
			for face in 6:
				var a := TAU*face/6.0
				var b := TAU*(face+1)/6.0
				var left := Vector3(cos(a),.0,sin(a))
				var right := Vector3(cos(b),.0,sin(b))
				var top := centre - Vector3.UP*radius*.48
				for point: Vector3 in [top,centre+left*radius,centre+right*radius]:
					emit(tool,point,(point-centre+Vector3.FORWARD*.018).normalized(),
						gem.lerp(gold,float(face%3)*.20),Vector2.ZERO,
						PackedInt32Array([binding,binding,binding,binding]),PackedFloat32Array([1.0,.0,.0,.0]))


func emit(tool: SurfaceTool, point: Vector3, normal: Vector3, tint: Color, coords: Vector2,
		bones: PackedInt32Array, weights: PackedFloat32Array) -> void:
	tool.set_normal(normal)
	tool.set_color(tint)
	tool.set_uv(coords)
	tool.set_bones(bones)
	tool.set_weights(weights)
	tool.add_vertex(point)


func pose_slasher(rig: Skeleton3D, phase: float, group: int) -> void:
	if group in [2,3]:
		var fall := smoothstep(.20,.98,phase)
		turn_world(rig,"bip01",Vector3.FORWARD,fall*(1.40 if group == 2 else -.88))
		turn_world(rig,"bip01",Vector3.RIGHT,fall*(.39 if group == 2 else -1.23))
		turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,-.91*fall)
		turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,-.62*fall)
		turn_world(rig,"bip01 l thigh",Vector3.RIGHT,.44*fall)
		turn_world(rig,"bip01 tail1",Vector3.UP,(.59 if group == 2 else -.61)*fall)
		return
	var wave := sin(TAU*phase)
	turn_world(rig,"bip01 spine2",Vector3.RIGHT,-.11+.037*wave)
	turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,-.51+.057*wave)
	turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,-.24-.057*wave)
	turn_world(rig,"bip01 tail1",Vector3.UP,.08*wave)
	if group == 1:
		return
	var effort := smoothstep(.10,.41,phase)*(1.0-smoothstep(.57,.99,phase))
	var sign := -1.0 if group in [5,15,23] else 1.0
	turn_world(rig,"bip01 spine1",Vector3.UP,.47*sign*effort)
	turn_world(rig,"bip01 head",Vector3.RIGHT,(-.35 if group in [12,23,27] else .27)*effort)
	turn_world(rig,"bip01 l upperarm",Vector3.RIGHT,(-1.07 if group in [4,12,27] else -.56)*effort)
	turn_world(rig,"bip01 r upperarm",Vector3.RIGHT,(-1.13 if group in [5,12,23] else -.48)*effort)
	turn_world(rig,"bip01 l forearm",Vector3.UP,.45*effort)
	turn_world(rig,"bip01 r forearm",Vector3.UP,-.52*effort)
	turn_world(rig,"bip01 tail2",Vector3.UP,-.50*sign*effort)


func fit_cloth(animator: AnimationPlayer, rig: Skeleton3D, clip: Animation, label: String) -> void:
	var prefix := animator.get_node(animator.root_node).get_path_to(rig)
	var death := label in ["Death","Death2"]
	for index in cloth_joints.size():
		var bone := cloth_joints[index]
		var row := index%4
		var column := index/4
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath("%s:%s" % [prefix,rig.get_bone_name(bone)]))
		var rest := rig.get_bone_rest(bone).basis.get_rotation_quaternion()
		for frame in 29:
			var phase := float(frame)/28.0
			var travel := float(row)/3.0
			var fading := 1.0-smoothstep(.55,.98,phase) if death else 1.0
			var ripple := sin(TAU*phase+float(column)*.59-travel*1.05)*travel*fading
			var stride := .08 if label in ["Walk","Run","SlasherVeil"] else .033
			var settle := smoothstep(.38,.99,phase)*travel*.12 if death else .0
			clip.rotation_track_insert_key(track,phase*clip.length,
				rest*Quaternion(Vector3.RIGHT,stride*ripple+settle)*Quaternion(Vector3.UP,.06*ripple))
