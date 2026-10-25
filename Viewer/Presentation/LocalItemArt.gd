extends RefCounted
var textures := {}
func _init() -> void:
 if not FileAccess.file_exists("res://item-art.local.json"): return
 var records: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://item-art.local.json"))
 if records is not Array: return
 for record in records:
  var width := int(record.width)
  var height := int(record.height)
  if width < 1 or height < 1 or width > 1024 or height > 1024: continue
  var bytes := Marshalls.base64_to_raw(record.rgba)
  if bytes.size() != width*height*4: continue
  var image := Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,bytes)
  # Classic signs are projected sprites. Undo the source face's vertical shear
  # before putting its artwork on a real plane; never shear the 3D sign itself.
  if int(record.id) in [2995,3011,3012]: image = face_image(image,0.5 if int(record.id)%2 else -0.5)
  image.generate_mipmaps()
  textures[int(record.id)] = ImageTexture.create_from_image(image)

static func face_image(source: Image, slope: float) -> Image:
 var padding := ceili(source.get_width()*absf(slope))
 var image := Image.create_empty(source.get_width(),source.get_height()+padding*2,false,Image.FORMAT_RGBA8)
 for y in source.get_height():
  for x in source.get_width():
   var destination := roundi(y-slope*(x-source.get_width()/2.0))+padding
   if destination >= 0 and destination < image.get_height(): image.set_pixel(x,destination,source.get_pixel(x,y))
 var bounds := image.get_used_rect()
 return image.get_region(bounds) if bounds.has_area() else source

func apply_face(root: Node3D, id: int, center: Vector3, dimensions: Vector2) -> bool:
 if not textures.has(id): return false
 for side in [-1,1]:
  var mesh := MeshInstance3D.new()
  mesh.name = "ClassicSignFace_"+str(side)
  var quad := QuadMesh.new()
  quad.size = dimensions
  mesh.mesh = quad
  mesh.position = center+Vector3(0,0,side*0.131)
  if side < 0: mesh.rotation.y = PI
  var material := StandardMaterial3D.new()
  material.albedo_texture = textures[id]
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
  material.alpha_scissor_threshold = 0.25
  material.roughness = 0.87
  material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  mesh.material_override = material
  root.add_child(mesh)
 return true
