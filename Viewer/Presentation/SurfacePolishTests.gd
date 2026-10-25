extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,title: String) -> void:
 checks += 1
 if not ok: failures += 1
 print(("PASS " if ok else "FAIL ")+title)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var world := {"schema":1,"originX":100,"originY":200,"width":7,"height":7,"elevationScale":0.2,"landData":{"1":{"name":"grass"},"2":{"name":"cobblestones"}},"staticData":{},"terrain":[],"statics":[]}
 for y in range(200,207):
  for x in range(100,107):
   world.terrain.append({"x":x,"y":y,"z":20 if x<104 else -15,"id":2 if x==100 else 1})
   if x>=104 and y>200 and y<206: world.statics.append({"x":x,"y":y,"z":-5,"id":3})
 var original := JSON.stringify(world)
 var shore = preload("res://Presentation/ShorelinePlan.gd").new()
 shore.index(world,{"3":{"kind":"water"}})
 var terrain = preload("res://Presentation/TerrainSurface.gd").new()
 terrain.index(world,shore)
 var exact := true
 for tile in world.terrain: exact = exact and is_equal_approx(terrain.height_at(Vector2(tile.x,tile.y)),float(tile.z)*0.2)
 check(exact,"smoothed terrain retains every original coordinate/elevation anchor")
 var bounded := true
 for step in 81:
  var height: float = terrain.height_at(Vector2(103+step/80.0,202.25))
  bounded = bounded and height>=-3.00001 and height<=4.00001
 check(bounded,"steep-bank interpolation cannot overshoot source elevation limits")
 check(absf(terrain.height_at(Vector2(104-0.00001,202.25))-terrain.height_at(Vector2(104+0.00001,202.25)))<0.001,"curved banks remain continuous across source cell boundaries")
 check(is_equal_approx(terrain.height_at(Vector2(101.3,202.7)),4.0),"flat walkable ground is not eroded by shoreline smoothing")
 var cropped: Dictionary = world.duplicate(true)
 cropped.originX=101
 cropped.originY=201
 cropped.width=5
 cropped.height=5
 cropped.terrain=cropped.terrain.filter(func(tile: Dictionary):return tile.x>=101 and tile.x<=105 and tile.y>=201 and tile.y<=205)
 var other = preload("res://Presentation/TerrainSurface.gd").new()
 other.index(cropped)
 check(is_equal_approx(other.height_at(Vector2(103.4,203.3)),terrain.height_at(Vector2(103.4,203.3))),"overlapping region interiors produce identical terrain heights with shared neighbor context")
 var mesh: ArrayMesh = terrain.build()
 var arrays := mesh.surface_get_arrays(0)
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 var normalized := true
 for normal in normals: normalized=normalized and absf(normal.length()-1.0)<0.001 and normal.y>0
 check(normalized,"smooth terrain normals stay finite, normalized and upward")
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var area := 0.0
 for i in range(0,vertices.size(),3):
  var a := Vector2(vertices[i].x,vertices[i].z)
  var b := Vector2(vertices[i+1].x,vertices[i+1].z)
  var c := Vector2(vertices[i+2].x,vertices[i+2].z)
  area+=absf((b-a).cross(c-a))*0.5
 check(is_equal_approx(area,36.0) and vertices.size()>6*6*4*6,"adaptive bank subdivisions retain complete source-cell coverage")
 check(shore.field[Vector2i(103,202)].distance<0 and shore.field[Vector2i(104,202)].distance>0,"shore field distinguishes dry bank and water interior")
 check(is_equal_approx(shore.field[Vector2i(105,203)].depth,2.0) and is_equal_approx(shore.field[Vector2i(103,203)].level,-1.0),"shore depth and nearby wet-edge elevation use source water levels")
 check(shore.image.get_pixel(5,3).r>0 and shore.image.get_pixel(3,3).r<0,"linear floating-point shore texture preserves signed distances")
 check(JSON.stringify(world)==original,"surface reconstruction leaves all source IR data unchanged")
 var slope_world := world.duplicate(true)
 for tile in slope_world.terrain:
  tile.z=20
  if tile.x==102 and tile.y==202:tile.z=24
 var gentle = preload("res://Presentation/TerrainSurface.gd").new()
 gentle.index(slope_world)
 check(is_equal_approx(gentle.height_at(Vector2(101.5,201.5)),4.0),"gentle slopes preserve the original diagonal support height at character centres")
 var material := ShaderMaterial.new()
 material.shader=preload("res://Presentation/Timber.gdshader")
 preload("res://Presentation/SurfaceLibrary.gd").bind(material,"surface","brown_planks_03")
 check(material.get_shader_parameter("surface_normal_map") is Texture2D and material.get_shader_parameter("surface_albedo") is Texture2D,"PBR library binds the actual albedo and OpenGL normal maps")
 check(material.get_shader_parameter("surface_scale")==Vector2.ONE,"PBR texture scale follows measured physical dimensions")
 var library=preload("res://Presentation/SurfaceLibrary.gd")
 library.source_origin=Vector2(100,200)
 library.bind(material,"surface","brown_planks_03")
 var second_material:=ShaderMaterial.new()
 second_material.shader=material.shader
 library.source_origin=Vector2(300,400)
 library.bind(second_material,"surface","brown_planks_03")
 check(material.get_shader_parameter("source_origin")==Vector2(100,200) and second_material.get_shader_parameter("source_origin")==Vector2(300,400),"surface instances retain source-coordinate alignment across different crop origins")
 print("SURFACE POLISH: %d passed / %d total" % [checks-failures,checks])
 quit(failures)
