extends RefCounted
# Monotone interpolation adds curved banks without overshoot or moving any
# source grid anchor. Gentle/walkable edges retain linear support heights.
const SUBDIVISIONS := 4
var samples := {}
var land_data := {}
var world: Dictionary
var shoreline
var heights := {}
func index(input: Dictionary, shore = null) -> void:
 world = input
 land_data = input.landData if input.get("landData") is Dictionary else {}
 shoreline = shore
 samples.clear()
 heights.clear()
 for tile in world.terrain: samples[Vector2i(tile.x,tile.y)] = tile
func z(cell: Vector2i) -> float:
 var bounded := Vector2i(clampi(cell.x,int(world.originX),int(world.originX)+int(world.width)-1),clampi(cell.y,int(world.originY),int(world.originY)+int(world.height)-1))
 return float(samples[bounded].z)*float(world.elevationScale)
static func curve(a: float,b: float,c: float,d: float,t: float) -> float:
 if absf(c-b) <= 0.8: return lerpf(b,c,t)
 var left := b-a
 var middle := c-b
 var right := d-c
 var m0 := 2.0*left*middle/(left+middle) if left*middle > 0 else 0.0
 var m1 := 2.0*right*middle/(right+middle) if right*middle > 0 else 0.0
 return clampf((2*t*t*t-3*t*t+1)*b+(t*t*t-2*t*t+t)*m0+(-2*t*t*t+3*t*t)*c+(t*t*t-t*t)*m1,minf(b,c),maxf(b,c))
func height_at(at: Vector2) -> float:
 var cell := Vector2i(floori(at.x),floori(at.y))
 var f := at-Vector2(cell)
 var a := z(cell)
 var b := z(cell+Vector2i.RIGHT)
 var c := z(cell+Vector2i.DOWN)
 var d := z(cell+Vector2i.ONE)
 if maxf(maxf(a,b),maxf(c,d))-minf(minf(a,b),minf(c,d)) <= 0.800001:
  # Keep the authoritative gentler diagonal on walkable slopes, including
  # the tile-centre support height used by UO movement.
  if absf(a-d)<=absf(b-c):
   return a+(b-a)*f.x+(d-b)*f.y if f.x>=f.y else a+(d-c)*f.x+(c-a)*f.y
  return a+(b-a)*f.x+(c-a)*f.y if f.x+f.y<=1 else d+(c-d)*(1-f.x)+(b-d)*(1-f.y)
 var rows: Array[float] = []
 for row in range(-1,3): rows.append(curve(z(cell+Vector2i(-1,row)),z(cell+Vector2i(0,row)),z(cell+Vector2i(1,row)),z(cell+Vector2i(2,row)),f.x))
 return curve(rows[0],rows[1],rows[2],rows[3],f.y)
func cached(grid: Vector2i) -> float:
 if not heights.has(grid): heights[grid] = height_at(Vector2(grid)/SUBDIVISIONS)
 return float(heights[grid])
func weights(cell: Vector2i) -> Vector2:
 var tile: Dictionary = samples.get(cell,{})
 var name := str(land_data.get(str(int(tile.get("id",0))),{}).get("name",""))
 return Vector2(1 if name in ["cobblestones","stone","brick"] else 0,1 if name == "wooden floor" else 0)
func attributes(at: Vector2) -> Dictionary:
 var cell := Vector2i(floori(at.x),floori(at.y))
 var f := at-Vector2(cell)
 var colors: Array[Color] = []
 var masks: Array[Vector2] = []
 for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
  var tile: Dictionary = samples.get(cell+offset,samples[cell])
  var name := str(land_data.get(str(int(tile.id)),{}).get("name",""))
  colors.append(preload("res://Presentation/Reconstruction.gd").terrain_color(name).srgb_to_linear())
  masks.append(weights(cell+offset))
 return {"color":colors[0].lerp(colors[1],f.x).lerp(colors[2].lerp(colors[3],f.x),f.y),"mask":masks[0].lerp(masks[1],f.x).lerp(masks[2].lerp(masks[3],f.x),f.y)}
func build() -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var origin := Vector2i(int(world.originX),int(world.originY))
 for source_y in range(origin.y,origin.y+int(world.height)-1):
  for source_x in range(origin.x,origin.x+int(world.width)-1):
   var source_cell := Vector2i(source_x,source_y)
   var tile: Dictionary = samples[source_cell]
   if land_data.get(str(int(tile.id)),{}).get("name") == "NODRAW": continue
   var corners := [z(source_cell),z(source_cell+Vector2i.RIGHT),z(source_cell+Vector2i.DOWN),z(source_cell+Vector2i.ONE)]
   var subdivisions := 4 if float(corners.max())-float(corners.min())>0.800001 else 2
   var step: int = SUBDIVISIONS/subdivisions
   for y in subdivisions:
    for x in subdivisions:
     var cell := source_cell*SUBDIVISIONS+Vector2i(x,y)*step
     var diagonal_a := absf(cached(cell)-cached(cell+Vector2i.ONE*step))
     var diagonal_b := absf(cached(cell+Vector2i.RIGHT*step)-cached(cell+Vector2i.DOWN*step))
     var offsets := [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.ZERO,Vector2i.ONE,Vector2i.DOWN] if diagonal_a<=diagonal_b else [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]
     for offset in offsets:
      var grid: Vector2i = cell+offset*step
      var at := Vector2(grid)/SUBDIVISIONS
      var data := attributes(at)
      var dx := (cached(grid+Vector2i.RIGHT)-cached(grid+Vector2i.LEFT))*SUBDIVISIONS*0.5
      var dy := (cached(grid+Vector2i.DOWN)-cached(grid+Vector2i.UP))*SUBDIVISIONS*0.5
      surface.set_normal(Vector3(-dx,1,-dy).normalized())
      surface.set_color(data.color)
      surface.set_uv(at)
      surface.set_uv2(data.mask)
      surface.add_vertex(Vector3(at.x-origin.x,cached(grid),at.y-origin.y))
 surface.generate_tangents()
 return surface.commit()
