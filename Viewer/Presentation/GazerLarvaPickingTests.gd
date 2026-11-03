extends SceneTree
const Geometry=preload("res://Presentation/SkinGeometry.gd")
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var model: Node3D=(load("res://local-art/creatures/gazer_larva/swarm-body-refined.scn") as PackedScene).instantiate()
    root.add_child(model)
    var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
    var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
    var meshes:=model.find_children("*","MeshInstance3D",true,false)
    var measured: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/gazer_larva/preparation.json")).models[0].pick_bounds
    var p: Array=measured.position
    var size: Array=measured.size
    var envelope:=AABB(Vector3(p[0],p[1],p[2]),Vector3(size[0],size[1],size[2]))
    var misses:=0
    var samples:=0
    for clip in player.get_animation_list():
        player.play(clip,0.)
        for i in 53:
            player.seek(player.get_animation(clip).length*(float(i)+.371)/53.,true)
            player.pause()
            rig.force_update_all_bone_transforms()
            var pose:=Geometry.deformed_bounds(meshes[0],rig).merge(Geometry.deformed_bounds(meshes[1],rig))
            misses+=int(not envelope.encloses(pose))
            samples+=1
    print("GAZER PICK ENVELOPE VALIDATION: ",samples," independent poses, ",misses," outside")
    quit(1 if misses else 0)
