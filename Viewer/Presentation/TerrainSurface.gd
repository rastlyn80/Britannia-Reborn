extends RefCounted
# Canonical input is immutable. The displayed surface removes narrow natural
# spurs and interpolates banks without overshoot; broad walkable ground is kept.
const SUBDIVISIONS := 4
# Open water in map.mul is land named "water" at the sea surface. Present it as a
# shallow bed under a separate water surface; source Z stays canonical.
const SEABED_DEPTH := 1.5
var water_cells := {}
var static_water := {}
# Ground directly under a constructed floor at the same height is lowered a few
# centimetres so dock/plank tops never z-fight with the terrain they cover.
const COVERED_DROP := 0.06
var covered := {}
var samples := {}
var land_data := {}
var world: Dictionary
var shoreline
var heights := {}
var peak_repairs := {}
var floor_overrides := {}
var wooden_cells := {}
var source_ordinals := {}
func index(input: Dictionary, shore = null) -> void:
 world = input
 land_data = input.landData if input.get("landData") is Dictionary else {}
 shoreline = shore
 samples.clear()
 heights.clear()
 peak_repairs.clear()
 floor_overrides.clear()
 wooden_cells.clear()
 source_ordinals.clear()
 water_cells.clear()
 static_water.clear()
 covered.clear()
 for i in world.terrain.size():
  var tile: Dictionary = world.terrain[i]
  samples[Vector2i(tile.x,tile.y)] = tile
  source_ordinals[Vector2i(tile.x,tile.y)] = i
 for tile in world.get("terrainHalo",[]):
  var cell := Vector2i(tile.x,tile.y)
  if not samples.has(cell): samples[cell] = tile
 for cell in samples:
  if str(land_data.get(str(int(samples[cell].id)),{}).get("name","")).to_lower() == "water": water_cells[cell] = SEABED_DEPTH
 # The bed shelves away from the shore (0.45 m per tile, to 6 m) so open sea
 # reads deep while banks and shallows stay visible through the water.
 var frontier: Array = []
 var distance := {}
 for cell in water_cells:
  for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   if samples.has(cell+offset) and not water_cells.has(cell+offset):
    distance[cell] = 0
    frontier.append(cell)
    break
 while not frontier.is_empty():
  var next: Array = []
  for cell in frontier:
   for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var other: Vector2i = cell+offset
    if water_cells.has(other) and not distance.has(other) and int(distance[cell]) < 10:
     distance[other] = int(distance[cell])+1
     next.append(other)
  frontier = next
 for cell in water_cells: water_cells[cell] = SEABED_DEPTH+0.45*float(distance.get(cell,10))
 # Zero-height source board floors own the top surface where map.mul also
 # supplies the same flat floor. Keep the canonical samples, emit only one mesh.
 var static_data = world.get("staticData",{})
 if static_data is Dictionary:
  for source in world.get("statics",[]):
   var detail: Dictionary = static_data.get(str(int(source.id)),{})
   var floor_name := str(detail.get("name","")).to_lower()
   if floor_name == "water": static_water[Vector2i(source.x,source.y)] = true
   if (floor_name in ["wooden boards","wooden planks","wooden plank","wooden bridge","cobblestones","stone pavers","stone pavers dark","marble floor","flagstones"] or int(detail.get("flags",0)) & 0x200) and int(detail.get("height",0)) <= 1:
    var under := Vector2i(source.x,source.y)
    if samples.has(under) and absi(int(samples[under].z)-int(source.z)) <= 1:
     for corner in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]: covered[under+corner] = true
   if detail.get("name","").to_lower() not in ["wooden boards","wooden planks","wooden plank","wooden bridge","cobblestones","stone pavers","stone pavers dark","marble floor","flagstones"] or int(detail.get("height",0)) != 0: continue
   var cell := Vector2i(source.x,source.y)
   var flat := true
   for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
    if not samples.has(cell+offset) or int(samples[cell+offset].z) != int(source.z): flat = false
   if flat: floor_overrides[cell] = true
 # Indoor land is a constructed floor, not a blended landscape material.
 for cell in source_ordinals:
  var source: Dictionary = samples[cell]
  if land_data.get(str(int(source.id)),{}).get("name","").to_lower() == "wooden floor" and not floor_overrides.has(cell):
   wooden_cells[cell] = source
   floor_overrides[cell] = true
 # Conservative isolated natural outlier filter. Keep IR/navigation untouched,
 # protect broad ridges, buildings and paving; use neighbor halos at crop edges.
 var protected := {}
 for source in world.get("statics",[])+world.get("staticHalo",[]):
  var data = world.get("staticData",{})
  if not data is Dictionary: continue
  var name := str(data.get(str(int(source.id)),{}).get("name","")).to_lower()
  if "wall" in name or "floor" in name or "stairs" in name:
   for y in range(-1,2):
    for x in range(-1,2): protected[Vector2i(source.x+x,source.y+y)] = true
 # Grayscale opening removes narrow one/two-cell spurs while retaining wide
 # plateaus and cliff edges. Walkable correction is capped at 8Z; impassable
 # coastal needles can be removed fully. Canonical source Z is never edited.
 var erosion := {}
 for cell in samples:
  var low := INF
  var complete := true
  for y in range(-1,2):
   for x in range(-1,2):
    if not samples.has(cell+Vector2i(x,y)): complete = false
    else: low = minf(low,float(samples[cell+Vector2i(x,y)].z))
  if complete: erosion[cell] = low
 for cell in samples:
  var source: Dictionary = samples[cell]
  var name := str(land_data.get(str(int(source.id)),{}).get("name","")).to_lower()
  if name not in ["grass","forest","dirt"] or protected.has(cell): continue
  var opened := -INF
  var complete := true
  for y in range(-1,2):
   for x in range(-1,2):
    if not erosion.has(cell+Vector2i(x,y)): complete = false
    else: opened = maxf(opened,float(erosion[cell+Vector2i(x,y)]))
  if not complete: continue
  if float(source.z)-opened >= 4:
   var impassable := bool(int(land_data.get(str(int(source.id)),{}).get("flags",0)) & 0x40)
   peak_repairs[cell] = opened+1 if impassable else maxf(opened+1,float(source.z)-8)

func raw_z(cell: Vector2i) -> float:
 var bounded := Vector2i(clampi(cell.x,int(world.originX),int(world.originX)+int(world.width)-1),clampi(cell.y,int(world.originY),int(world.originY)+int(world.height)-1))
 return float(samples.get(cell,samples[bounded]).z)*float(world.elevationScale)
func z(cell: Vector2i) -> float:
 var bounded := Vector2i(clampi(cell.x,int(world.originX),int(world.originX)+int(world.width)-1),clampi(cell.y,int(world.originY),int(world.originY)+int(world.height)-1))
 var key := cell if samples.has(cell) else bounded
 return float(peak_repairs.get(key,samples[key].z))*float(world.elevationScale)-float(water_cells.get(key,0.0))-(COVERED_DROP if covered.has(key) else 0.0)
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
 var bounded:=Vector2i(clampi(cell.x,int(world.originX),int(world.originX)+int(world.width)-1),clampi(cell.y,int(world.originY),int(world.originY)+int(world.height)-1))
 var fallback:Dictionary=samples.get(cell,samples[bounded])
 var colors: Array[Color] = []
 var masks: Array[Vector2] = []
 for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
  var tile: Dictionary = samples.get(cell+offset,fallback)
  var name := str(land_data.get(str(int(tile.id)),{}).get("name",""))
  colors.append(preload("res://Presentation/Reconstruction.gd").terrain_color(name).srgb_to_linear())
  masks.append(weights(cell+offset))
 return {"color":colors[0].lerp(colors[1],f.x).lerp(colors[2].lerp(colors[3],f.x),f.y),"mask":masks[0].lerp(masks[1],f.x).lerp(masks[2].lerp(masks[3],f.x),f.y)}
func build(region: Rect2i = Rect2i()) -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var origin := Vector2i(int(world.originX),int(world.originY))
 var draw := Rect2i(origin,Vector2i(int(world.width)-(0 if world.get("render_cells",false) else 1),int(world.height)-(0 if world.get("render_cells",false) else 1)))
 if region.has_area(): draw = draw.intersection(region)
 for source_y in range(draw.position.y,draw.end.y):
  for source_x in range(draw.position.x,draw.end.x):
   var source_cell := Vector2i(source_x,source_y)
   var tile: Dictionary = samples[source_cell]
   if floor_overrides.has(source_cell): continue
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

# Flat sea surface over water land at its source elevation, one quad per cell.
func sea_mesh(region: Rect2i) -> ArrayMesh:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var origin := Vector2i(int(world.originX),int(world.originY))
 var count := 0
 for cell in water_cells:
  if not region.has_point(cell) or not source_ordinals.has(cell) or static_water.has(cell): continue
  var level := float(samples[cell].z)*float(world.elevationScale)
  for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.ZERO,Vector2i.ONE,Vector2i.DOWN]:
   surface.set_normal(Vector3.UP)
   surface.add_vertex(Vector3(cell.x+offset.x-origin.x,level,cell.y+offset.y-origin.y))
  count += 1
 return surface.commit() if count > 0 else null
