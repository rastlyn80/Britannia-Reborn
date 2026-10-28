extends SceneTree
const FILES=["Reconstruction.gd","BridgePlan.gd","RegionalRules.gd","CityProps.gd","RegionalContext.gd","RoofPlan.gd","Facade.gd","FloorPlan.gd","InteriorShell.gd","GeometryLibrary.gd","SurfaceLibrary.gd","TerrainSurface.gd","FarCity.gdshader","Roof.gdshader","RegionalBake.gd","SourceOwnership.gd","WindowDressing.gd","LocalLibrary.gd","Lava.gdshader","Waterfall.gdshader","SurfaceVariants.gd","SurfaceVariants.gdshaderinc","Ground.gdshader","Facade.gdshader","Carpet.gdshader","DoorLeaf.gd","PropReplacements.gd","prop-replacements.json","ReviewedCatalog.gd","reviewed-catalog.json","static-catalog.json"]
var batches:Dictionary={}
var materials:Dictionary={}
var directory:="res://../outputs/britain"
func _initialize()->void:call_deferred("run")
static func fingerprint(folder:String)->String:
 var text:=FileAccess.get_sha256(folder.path_join("atlas.json"))+str(Engine.get_version_info().string)
 for asset in ["Quaternius","Kenney","Surfaces","PolyHaven","Objaverse","Reduced"]:text+=FileAccess.get_sha256("res://Art/"+asset+"/manifest.json")
 for name in FILES:text+=FileAccess.get_sha256("res://Presentation/"+name)
 return text.sha256_text()
func append(node:Node3D,parent_transform:Transform3D,source:Dictionary)->void:
 var transform:=parent_transform*node.transform
 if node is MeshInstance3D and node.mesh:
  for i in node.mesh.get_surface_count():
   var original:Material=node.get_active_material(i)
   if original is StandardMaterial3D and original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
   var key:=original.get_instance_id() if original else 0
   if not batches.has(key):
    var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]=tool
    var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/FarCity.gdshader")
    var color:=Color("aa9f88")
    var texture:Texture2D
    var scale:=Vector2.ONE
    if original is ShaderMaterial:
     for field in ["palette","roof_color","base_color"]:
      var value:Variant=original.get_shader_parameter(field)
      if value is Color:color=value;break
     var value:Variant=original.get_shader_parameter("surface_albedo")
     if value is Texture2D:texture=value
     value=original.get_shader_parameter("surface_scale")
     if value is Vector2:scale=value
    elif original is StandardMaterial3D:color=original.albedo_color;texture=original.albedo_texture
    material.set_shader_parameter("palette",color)
    material.set_shader_parameter("surface_albedo",texture)
    material.set_shader_parameter("surface_scale",scale)
    material.set_shader_parameter("has_texture",texture!=null)
    materials[key]=material
   var owned:=preload("res://Presentation/SourceOwnership.gd").mesh(node.mesh,i,source)
   batches[key].append_from(owned,0,transform)
 for child in node.get_children():
  # Distant massing omits window shutters and flower boxes.
  if child is Node3D and child.get_meta("kind","")!="dressing":append(child,transform,source)
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--atlas="):directory=arg.substr(8).get_base_dir()
 var signature:=fingerprint(directory)
 var stamp_path:=directory.path_join("architecture-bake.local.json")
 var scene_path:=directory.path_join("architecture.scn")
 if FileAccess.file_exists(stamp_path) and FileAccess.file_exists(scene_path):
  var old:Variant=JSON.parse_string(FileAccess.get_file_as_string(stamp_path))
  if old is Dictionary and old.get("fingerprint","")==signature:print("REGIONAL BAKE: current");quit();return
 var data:=preload("res://Presentation/AtlasData.gd").new()
 if not data.open(directory.path_join("atlas.json")):quit(1);return
 var plan:=preload("res://Presentation/RegionalContext.gd").new()
 plan.prepare(data)
 var bounds:=Rect2i(int(plan.world.originX),int(plan.world.originY),int(plan.world.width),int(plan.world.height))
 var kinds=["wall","window","corner","gable","trim","beam","arch","pillar","post","floor","landing","stairs","roof","door","fence","asset"]
 var count:=0
 var models:=0
 var base:=Transform3D(Basis.IDENTITY,Vector3(plan.world.originX,0,plan.world.originY))
 for i in plan.world.statics.size():
  var source:Dictionary=plan.world.statics[i]
  if not bounds.has_point(Vector2i(source.x,source.y)) or plan.reconstruction.rule_for(source.id).get("kind","") not in kinds:continue
  var node:Node3D=plan.reconstruction.build(source,plan.world,i)
  count+=1
  if node:append(node,base,source);node.free();models+=1
  if count%512==0:
   plan.reconstruction.report.clear()
   print("REGIONAL BAKE GEOMETRY: ",count)
   await process_frame
 var result:=Node3D.new();result.name="JoinedCityArchitecture"
 var vertices:=0
 for key in batches:
  var mesh:ArrayMesh=batches[key].commit()
  if mesh==null:continue
  vertices+=mesh.surface_get_array_len(0)
  var part:=MeshInstance3D.new();part.mesh=mesh;part.material_override=materials[key]
  result.add_child(part);part.owner=result
 var packed:=PackedScene.new()
 var error:=packed.pack(result)
 if error==OK:error=ResourceSaver.save(packed,scene_path,ResourceSaver.FLAG_COMPRESS)
 if error!=OK:push_error("Regional bake save failed");result.free();quit(1);return
 var record={"fingerprint":signature,"source_records":count,"ownership":"UV2 contains canonical source chunk origin","model_owners":models,"batches":result.get_child_count(),"vertices":vertices,"scope":"Shared joined architecture, simplified shading for distant rendering; proprietary derived geometry stays local."}
 var file:=FileAccess.open(stamp_path,FileAccess.WRITE);file.store_string(JSON.stringify(record));file.close()
 print("REGIONAL BAKE COMPLETE: ",JSON.stringify(record))
 result.free()
 quit()
