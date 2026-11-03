extends SceneTree
const Refine=preload("res://Presentation/SourcePoseSubdivision.gd")
const SOURCE:="res://local-art/creatures/gazer_larva/swarm-exact-source.scn"
const OUTPUT:="res://local-art/creatures/gazer_larva/swarm-body-refined.scn"
const CARD_COUNT:=42
## Classify rigid card triangles by their pinned named source joints.
## Only the skinned body receives conditional subdivision.
func _initialize() -> void:
    create_timer(60.).timeout.connect(func():quit(2))
    call_deferred("run")
func subset(arrays: Array, indices: PackedInt32Array, first: int, limit: int) -> ArrayMesh:
    var target: Array=[]
    target.resize(Mesh.ARRAY_MAX)
    var points:=PackedVector3Array()
    var normals:=PackedVector3Array()
    var uvs:=PackedVector2Array()
    var bones:=PackedInt32Array()
    var weights:=PackedFloat32Array()
    var tangent:=PackedFloat32Array()
    for corner in range(first,limit):
        var index:=indices[corner]
        points.append(arrays[Mesh.ARRAY_VERTEX][index])
        normals.append(arrays[Mesh.ARRAY_NORMAL][index])
        uvs.append(arrays[Mesh.ARRAY_TEX_UV][index])
        bones.append_array(arrays[Mesh.ARRAY_BONES].slice(index*4,index*4+4))
        weights.append_array(arrays[Mesh.ARRAY_WEIGHTS].slice(index*4,index*4+4))
        if arrays[Mesh.ARRAY_TANGENT]!=null:
            tangent.append_array(arrays[Mesh.ARRAY_TANGENT].slice(index*4,index*4+4))
    target[Mesh.ARRAY_VERTEX]=points
    target[Mesh.ARRAY_NORMAL]=normals
    target[Mesh.ARRAY_TEX_UV]=uvs
    target[Mesh.ARRAY_BONES]=bones
    target[Mesh.ARRAY_WEIGHTS]=weights
    if not tangent.is_empty():target[Mesh.ARRAY_TANGENT]=tangent
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,target)
    return mesh
func run() -> void:
    var model: Node3D=(load(SOURCE) as PackedScene).instantiate()
    root.add_child(model)
    var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
    var body: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
    var original:=body.mesh
    var a:=original.surface_get_arrays(0)
    var indices:=PackedInt32Array()
    if a[Mesh.ARRAY_INDEX]!=null:indices=a[Mesh.ARRAY_INDEX]
    else:
        for index in a[Mesh.ARRAY_VERTEX].size():indices.append(index)
    assert(indices.size()==824*3 and rig.get_bone_count()==126)
    var links: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/gazer-larva/owned-source/card-bindings.json"))
    assert(links.parts.size()==21)
    var rigid: Dictionary={}
    for part: Dictionary in links.parts:
        var leaf:=rig.find_bone(str(part.name))
        assert(leaf>=0)
        rigid[leaf]=PackedInt32Array()
    var card_indices:=PackedInt32Array()
    var body_indices:=PackedInt32Array()
    for first in range(0,indices.size(),3):
        var triangle:=indices.slice(first,first+3)
        var leaf:=-1
        var is_card:=true
        for corner in triangle.size():
            var vertex:=triangle[corner]
            var binding: int=a[Mesh.ARRAY_BONES][vertex*4]
            var joint:=body.skin.get_bind_bone(binding)
            if joint<0:joint=rig.find_bone(body.skin.get_bind_name(binding))
            if corner==0:leaf=joint
            if joint!=leaf or not rigid.has(joint) or not is_equal_approx(a[Mesh.ARRAY_WEIGHTS][vertex*4],1.):
                is_card=false
                break
        if is_card:
            var vertices: PackedInt32Array=rigid[leaf]
            vertices.append_array(triangle)
            rigid[leaf]=vertices
            card_indices.append_array(triangle)
        else:body_indices.append_array(triangle)
    for vertices: PackedInt32Array in rigid.values():
        assert(vertices.size()==6)
        var points: Dictionary={}
        for vertex in vertices:points[a[Mesh.ARRAY_VERTEX][vertex]]=true
        assert(points.size()==4)
    assert(card_indices.size()==42*3 and body_indices.size()==782*3)
    var cards:=MeshInstance3D.new()
    cards.name="OriginalCards"
    cards.mesh=subset(a,card_indices,0,card_indices.size())
    cards.mesh.surface_set_material(0,original.surface_get_material(0))
    cards.skin=body.skin
    body.get_parent().add_child(cards)
    cards.owner=model
    cards.transform=body.transform
    cards.skeleton=cards.get_path_to(rig)
    body.mesh=subset(a,body_indices,0,body_indices.size())
    body.mesh.surface_set_material(0,original.surface_get_material(0))
    var card_arrays:=cards.mesh.surface_get_arrays(0)
    var max_normal_delta:=0.
    for corner in CARD_COUNT*3:
        var vertex:=card_indices[corner]
        for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV]:
            assert(card_arrays[channel][corner]==a[channel][vertex])
        max_normal_delta=maxf(max_normal_delta,card_arrays[Mesh.ARRAY_NORMAL][corner].distance_to(a[Mesh.ARRAY_NORMAL][vertex]))
        for slot in 4:
            assert(card_arrays[Mesh.ARRAY_BONES][corner*4+slot]==a[Mesh.ARRAY_BONES][vertex*4+slot])
            assert(is_equal_approx(card_arrays[Mesh.ARRAY_WEIGHTS][corner*4+slot],a[Mesh.ARRAY_WEIGHTS][vertex*4+slot]))
    print("Card normal upload maximum delta: ",max_normal_delta)
    if max_normal_delta>.0002:quit(1);return
    var report:=Refine.apply(body,rig,1,.0007)
    assert(report.triangles==3128 and cards.mesh.surface_get_array_len(0)==126)
    var scene:=PackedScene.new()
    assert(scene.pack(model)==OK)
    assert(ResourceSaver.save(scene,OUTPUT,ResourceSaver.FLAG_COMPRESS)==OK)
    var imported: Node3D=(ResourceLoader.load(OUTPUT, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
    assert(imported.find_children("*","MeshInstance3D",true,false).size()==2)
    assert(imported.find_children("*","Skeleton3D",true,false)[0].get_bone_count()==126)
    imported.free()
    FileAccess.open("res://../work/creatures/gazer-larva/owned-source/body-refine.json",FileAccess.WRITE).store_string(JSON.stringify({
        "source":FileAccess.get_sha256(SOURCE),"asset":FileAccess.get_sha256(OUTPUT),"source_body_triangles":782,
        "refined_body_triangles":report.triangles,"untouched_card_triangles":42,"cards":21,"rig_joints":126,"maximum_card_normal_upload_delta":max_normal_delta,
        "scope":"Exact original rigid card positions/UVs/skin binding and bounded normal upload, body-only conditional subdivision, saved-scene reload. No animated fidelity or native acceptance."}, "\t"))
    print("GAZER BODY REFINEMENT: ",report.triangles," body triangles, 42 original card triangles")
    quit()
