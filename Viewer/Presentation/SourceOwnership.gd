extends RefCounted
# Render ownership is the source chunk, independent of a roof overhang or an
# assembled prop's visible bounds. Chunk origins remain exact in packed UV2.
static func chunk(source:Dictionary)->Vector2:
 return Vector2(floori(float(source.x)/64)*64,floori(float(source.y)/64)*64)
static func mesh(input:Mesh,surface:int,source:Dictionary)->ArrayMesh:
 var arrays:=input.surface_get_arrays(surface)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var owners:=PackedVector2Array();owners.resize(vertices.size());owners.fill(chunk(source))
 arrays[Mesh.ARRAY_TEX_UV2]=owners
 var result:=ArrayMesh.new()
 result.add_surface_from_arrays(input.surface_get_primitive_type(surface) if input is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES,arrays)
 return result
