extends RefCounted
# Runtime field only. Proprietary input remains in the immutable IR.
var wet := {}
var terrain := {}
var bounds := Rect2i()
var texture: ImageTexture
var image: Image
var field := {}
const DIRECTIONS = [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
func index(world: Dictionary, catalog: Dictionary) -> void:
 wet.clear()
 terrain.clear()
 field.clear()
 bounds = Rect2i(int(world.originX),int(world.originY),int(world.width),int(world.height))
 for tile in world.terrain: terrain[Vector2i(tile.x,tile.y)] = float(tile.z)*float(world.elevationScale)
 for tile in world.statics:
  if catalog.get(str(int(tile.id)),{}).get("kind") == "water": wet[Vector2i(tile.x,tile.y)] = float(tile.z)*float(world.elevationScale)
 var to_wet := {}
 var to_dry := {}
 var nearest_level := {}
 var wet_queue: Array[Vector2i] = []
 var dry_queue: Array[Vector2i] = []
 for y in range(bounds.position.y,bounds.end.y):
  for x in range(bounds.position.x,bounds.end.x):
   var cell := Vector2i(x,y)
   if wet.has(cell):
    to_wet[cell] = 0
    nearest_level[cell] = wet[cell]
    wet_queue.append(cell)
   else:
    to_dry[cell] = 0
    dry_queue.append(cell)
 _flood(wet_queue,to_wet,nearest_level)
 var unused := {}
 _flood(dry_queue,to_dry,unused)
 image = Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBAF)
 for y in bounds.size.y:
  for x in bounds.size.x:
   var cell := bounds.position+Vector2i(x,y)
   var distance: float = float(to_dry.get(cell,32)) if wet.has(cell) else -float(to_wet.get(cell,32))
   var level := float(nearest_level.get(cell,-1000.0))
   var depth := maxf(0,level-float(terrain.get(cell,level)))
   field[cell] = {"distance":distance,"level":level,"depth":depth}
   image.set_pixel(x,y,Color(distance,level,depth,1))
 texture = ImageTexture.create_from_image(image)
func _flood(queue: Array[Vector2i], distances: Dictionary, levels: Dictionary) -> void:
 var cursor := 0
 while cursor < queue.size():
  var cell: Vector2i = queue[cursor]
  cursor += 1
  for direction in DIRECTIONS:
   var next: Vector2i = cell+direction
   if not bounds.has_point(next) or distances.has(next): continue
   distances[next] = int(distances[cell])+1
   if levels.has(cell): levels[next] = levels[cell]
   queue.append(next)
func apply(material: ShaderMaterial) -> void:
 material.set_shader_parameter("shore_data",texture)
 material.set_shader_parameter("shore_rect",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
 material.set_shader_parameter("has_shore",not wet.is_empty())
