extends RefCounted
const Reconstruction = preload("res://Presentation/Reconstruction.gd")
static func build(data: RefCounted) -> ArrayMesh:
 var points := {}
 var vertices := PackedVector3Array()
 var colors := PackedColorArray()
 var indices := PackedInt32Array()
 for tile in data.manifest.overview:
  var cell := Vector2i(tile[0],tile[1])
  points[cell] = vertices.size()
  vertices.append(Vector3(cell.x,float(tile[2])*0.2,cell.y))
  colors.append(Reconstruction.terrain_color(str(data.manifest.landData.get(str(int(tile[3])),{}).get("name",""))).srgb_to_linear())
 for cell in points:
  var next := Vector2i(mini(cell.x+8,int(data.manifest.originX+data.manifest.width)-1),mini(cell.y+8,int(data.manifest.originY+data.manifest.height)-1))
  if next.x==cell.x or next.y==cell.y or not points.has(next): continue
  var a: int=points[cell]
  var b: int=points[Vector2i(next.x,cell.y)]
  var c: int=points[Vector2i(cell.x,next.y)]
  var d: int=points[next]
  indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
 var normals := PackedVector3Array()
 normals.resize(vertices.size())
 for i in range(0,indices.size(),3):
  var a:=indices[i]
  var b:=indices[i+1]
  var c:=indices[i+2]
  var normal := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
  normals[a]+=normal;normals[b]+=normal;normals[c]+=normal
 for i in normals.size(): normals[i]=normals[i].normalized()
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_COLOR]=colors
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh
