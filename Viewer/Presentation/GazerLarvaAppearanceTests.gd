extends SceneTree
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const BODY:=778
const SCENE:="res://local-art/creatures/gazer_larva/swarm-body-refined.scn"
const OUT:="res://../work/creatures/gazer-larva/owned-source/refined-alpha-gpu"
var viewport: SubViewport
var failures:=0
func _initialize() -> void:
    create_timer(75.).timeout.connect(func():quit(2))
    call_deferred("run")
func frame() -> Image:
    for i in 3:await process_frame
    await RenderingServer.frame_post_draw
    var result:=viewport.get_texture().get_image()
    result.convert(Image.FORMAT_RGBA8)
    return result
func check(ok: bool,label: String) -> void:
    if not ok:
        failures+=1
        push_error(label)
func differences(a: Image,b: Image) -> Dictionary:
    var out: Dictionary={"occupied":0,"opaque_occupied":0,"removed":0,"different":0}
    for y in a.get_height():
        for x in a.get_width():
            var c:=a.get_pixel(x,y)
            var d:=b.get_pixel(x,y)
            var a_visible:=c.a>.25
            var b_visible:=d.a>.25
            out.occupied+=int(a_visible)
            out.opaque_occupied+=int(b_visible)
            out.removed+=int(b_visible and not a_visible)
            out.different+=int(a_visible and b_visible and (absf(c.r-d.r)+absf(c.g-d.g)+absf(c.b-d.b))>.10)
    return out
func run() -> void:
    Registry.load_index()
    if "--active" not in OS.get_cmdline_user_args():
        Registry.entries[BODY]=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/gazer_larva/preparation.json")).models[0]
    viewport=SubViewport.new()
    viewport.size=Vector2i(640,480)
    viewport.own_world_3d=true
    viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
    var camera:=Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    viewport.add_child(camera)
    var avatar:=Avatar.new()
    avatar.initial_body=BODY
    viewport.add_child(avatar)
    avatar.set_physics_process(false)
    var visual: Node3D=avatar.horse_visual
    visual.set_process(false)
    visual.contact.enabled=false
    avatar.apply_server_appearance({"body":BODY,"hue":0},[])
    var meshes: Array=visual.model.find_children("*","MeshInstance3D",true,false)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var rows: Array=[]
    for clip in ["Idle","Walk","Attack3","Death"]:
        visual.animator.play(clip,0.)
        visual.animator.seek(visual.animator.get_animation(clip).length*.37,true)
        visual.animator.pause()
        visual.skeleton.force_update_all_bone_transforms()
        var bounds:=Geometry.deformed_bounds(meshes[0],visual.skeleton).merge(Geometry.deformed_bounds(meshes[1],visual.skeleton))
        camera.size=bounds.size.length()*1.06
        camera.position=bounds.get_center()+Vector3(-1.,.5,2.)*camera.size
        camera.look_at(bounds.get_center())
        visual.apply_identity(BODY,0)
        var materials: Array[ShaderMaterial]=[]
        for mesh: MeshInstance3D in meshes:
            var material:=mesh.get_active_material(0) as ShaderMaterial
            materials.append(material)
            material.set_shader_parameter("alpha_probe",true)
            material.set_shader_parameter("use_source_alpha",false)
        var solid:=await frame()
        for material in materials:material.set_shader_parameter("use_source_alpha",true)
        var cutout:=await frame()
        var pixels:=differences(cutout,solid)
        check(pixels.occupied>200 and pixels.removed>100,clip+" retains a real visible body and removes source-card background")
        for material in materials:material.set_shader_parameter("alpha_probe",false)
        var base:=await frame()
        visual.apply_identity(BODY,53)
        var dyed:=await frame()
        visual.apply_identity(BODY,0x8035)
        var partial:=await frame()
        var full_difference:=differences(base,dyed)
        var partial_difference:=differences(dyed,partial)
        check(full_difference.different>100,clip+" native full hue changes the visible source")
        check(partial_difference.different>100,clip+" native partial hue differs from full hue")
        base.save_png(OUT+"/"+clip.to_lower()+".png")
        rows.append({"clip":clip,"alpha":pixels,"full_dye":full_difference.different,"partial_dye":partial_difference.different})
    FileAccess.open(OUT+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"failures":failures,"samples":rows,"scene_sha256":FileAccess.get_sha256(SCENE)}, "\t"))
    print("GAZER GPU: ",rows," failures ",failures)
    quit(1 if failures else 0)
