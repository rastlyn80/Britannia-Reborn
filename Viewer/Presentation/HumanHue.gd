extends RefCounted
## Native RGB555 palette, retained as 32 entries instead of one RGB multiplier.
const Art = preload("res://Network/Artwork.gd")
static var cache := {}
static var pigmentation := {}
static func cosmetic_gain(texture: Texture2D) -> float:
	if texture==null: return 1.8
	var key:=texture.get_instance_id()
	if pigmentation.has(key): return pigmentation[key]
	var sample:=texture.get_image()
	if sample==null or sample.is_empty(): return 1.8
	sample=sample.duplicate()
	if sample.is_compressed(): sample.decompress()
	sample.resize(128,128,Image.INTERPOLATE_NEAREST)
	var histogram:=PackedInt32Array();histogram.resize(256)
	var count:=0
	for y in sample.get_height():
		for x in sample.get_width():
			var pixel:=sample.get_pixel(x,y)
			if pixel.a<.35: continue
			histogram[clampi(roundi(maxf(pixel.r,maxf(pixel.g,pixel.b))*255),0,255)]+=1
			count+=1
	var accumulated:=0
	var level:=255
	for i in 256:
		accumulated+=histogram[i]
		if accumulated>=maxi(1,ceili(count*.75)):
			level=i;break
	# Normalize differing authored pigmentation before applying the same native
	# dye; keep each texture's relative strand shading and alpha silhouette.
	var gain:=clampf(.65/maxf(.05,float(level)/255),1.,12.)
	pigmentation[key]=gain
	return gain
static func palette(hue: int) -> Texture2D:
	Art.load_local()
	var key := (hue&0x3fff)-1
	if key<0 or not Art.hues.has(str(key)): return null
	if cache.has(key): return cache[key]
	var colours: Array = Art.hues[str(key)]
	if colours.size()!=32: return null
	var picture := Image.create(32,1,false,Image.FORMAT_RGBA8)
	for i in 32: picture.set_pixel(i,0,Art.rgb(int(colours[i])))
	cache[key] = ImageTexture.create_from_image(picture)
	return cache[key]
static func material(original: StandardMaterial3D, hue: int, cosmetic: bool = false) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://Presentation/HumanHue.gdshader")
	result.set_shader_parameter("source_texture",original.albedo_texture)
	result.set_shader_parameter("base_colour",original.albedo_color)
	result.set_shader_parameter("has_texture",original.albedo_texture!=null)
	result.set_shader_parameter("normal_texture",original.normal_texture)
	result.set_shader_parameter("has_normal",original.normal_enabled and original.normal_texture!=null)
	result.set_shader_parameter("normal_strength",original.normal_scale)
	var colours := palette(hue)
	result.set_shader_parameter("use_hue",colours!=null)
	result.set_shader_parameter("hue_palette",colours)
	result.set_shader_parameter("partial_hue",(hue&0x8000)!=0 and not cosmetic)
	result.set_shader_parameter("cutout",cosmetic or original.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	result.set_shader_parameter("cutout_threshold",.35 if cosmetic else original.alpha_scissor_threshold)
	result.set_shader_parameter("cosmetic",cosmetic)
	result.set_shader_parameter("pigmentation_gain",cosmetic_gain(original.albedo_texture) if cosmetic else 1.)
	result.set_shader_parameter("roughness",.82 if cosmetic else original.roughness)
	result.set_shader_parameter("metalness",0. if cosmetic else original.metallic)
	result.set_shader_parameter("emission_colour",original.emission*original.emission_energy_multiplier if original.emission_enabled else Color.BLACK)
	return result
