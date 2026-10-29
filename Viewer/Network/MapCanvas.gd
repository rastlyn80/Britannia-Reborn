extends Control
# A view of a facet's radar map (scripts/prepare-world-map.py: one folder per
# facet of 512-tile PNGs, one pixel per map tile, local and git-ignored).
# `facet` picks the map (0 Felucca ... 5 Ter Mur), `view` the world rectangle
# shown; tiles load lazily and are cached for the session. Markers are drawn
# in world coordinates. Without the prepared map it says how to make it.
const Look = preload("res://Network/ModernSkin.gd")
const FOLDER := "res://local-worldmap"
static var indexes := {}
static var cache := {}
var facet := 1
var view := Rect2(0,0,7168,4096)
# {at: Vector2 (world), color, label, shape ("dot", "diamond", "player", "pin", "house"), size, facing}
var markers: Array = []
# Pins joined in order (a plotted course).
var course: Array = []
var tint := Color.WHITE
var loading: Array = []

static func index_of(map: int) -> Dictionary:
	if not indexes.has(map):
		var path := "%s/%d/index.json" % [FOLDER,map]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		indexes[map] = parsed if parsed is Dictionary else {}
	return indexes[map]

# Facet names and sizes, for windows that switch maps.
static func facets() -> Array:
	var root = JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"/index.json")) if FileAccess.file_exists(FOLDER+"/index.json") else null
	return root.get("facets",[]) if root is Dictionary else []

func available() -> bool:
	return not index_of(facet).is_empty()

func index() -> Dictionary:
	return index_of(facet)

static func tile_texture(map: int, at: Vector2i) -> Texture2D:
	var key := "%d/%d_%d" % [map,at.x,at.y]
	if cache.has(key): return cache[key]
	var image := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [FOLDER,key]))
	var texture: Texture2D = ImageTexture.create_from_image(image) if image else null
	cache[key] = texture
	return texture

# Markers draw on their own layer, so a parchment shader tints only the map.
var overlay := Control.new()
const PARCHMENT_SHADER := """
shader_type canvas_item;
// An old chart: pale sea, tan land shaded by the radar's lightness, inked coasts.
// (Samples are inlined: helper functions cannot take TEXTURE on every renderer.)
void fragment() {
	vec2 o = TEXTURE_PIXEL_SIZE * 1.5;
	vec3 c = texture(TEXTURE, UV).rgb;
	vec3 e = texture(TEXTURE, UV + vec2(o.x, 0.0)).rgb;
	vec3 w = texture(TEXTURE, UV - vec2(o.x, 0.0)).rgb;
	vec3 s = texture(TEXTURE, UV + vec2(0.0, o.y)).rgb;
	vec3 n = texture(TEXTURE, UV - vec2(0.0, o.y)).rgb;
	float wet = step(c.r + c.g * 0.55, c.b * 1.35);
	float edge = abs(step(e.r + e.g * 0.55, e.b * 1.35) - wet) + abs(step(w.r + w.g * 0.55, w.b * 1.35) - wet)
		+ abs(step(s.r + s.g * 0.55, s.b * 1.35) - wet) + abs(step(n.r + n.g * 0.55, n.b * 1.35) - wet);
	float light = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 land = mix(vec3(0.55, 0.42, 0.26), vec3(0.88, 0.78, 0.58), clamp(light * 2.4, 0.0, 1.0));
	vec3 col = mix(land, vec3(0.84, 0.81, 0.7), wet);
	col = mix(col, vec3(0.28, 0.18, 0.09), clamp(edge, 0.0, 1.0) * 0.9);
	COLOR = vec4(col, texture(TEXTURE, UV).a * COLOR.a);
}
"""

func parchment() -> void:
	var shader := Shader.new()
	shader.code = PARCHMENT_SHADER
	material = ShaderMaterial.new()
	material.shader = shader

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_markers)
	add_child(overlay)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW: overlay.queue_redraw()

func to_local_point(world: Vector2) -> Vector2:
	return (world-view.position)/view.size*size

func to_world(local: Vector2) -> Vector2:
	return view.position+local/size*view.size

func _process(_delta: float) -> void:
	# A few tiles per frame, so opening a big view never stalls the game.
	var done := 0
	while not loading.is_empty() and done < 3:
		var next: Array = loading.pop_front()
		tile_texture(int(next[0]),next[1])
		done += 1
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0d1a22"))
	if not available():
		draw_string(Look.ui_font(600),Vector2(16,size.y/2),"No map for this facet: run scripts/prepare-world-map.py",HORIZONTAL_ALIGNMENT_LEFT,size.x-32,14,Look.ASH)
		return
	var info := index()
	var step := int(info.get("tile",512))
	var bounds := Vector2(float(info.get("width",0)),float(info.get("height",0)))
	# Far out, the overview stands in for the full tiles.
	var overview_scale := float(info.get("overview",8))
	var overview_path := "%s/%d/overview.png" % [FOLDER,facet]
	if view.size.x/size.x > 4.0 and FileAccess.file_exists(overview_path):
		var key := "%d/overview" % facet
		if not cache.has(key):
			var image := Image.load_from_file(ProjectSettings.globalize_path(overview_path))
			cache[key] = ImageTexture.create_from_image(image) if image else null
		var overview: Texture2D = cache.get(key)
		if overview:
			var shown := view.intersection(Rect2(Vector2.ZERO,bounds))
			if shown.has_area(): draw_texture_rect_region(overview,Rect2(to_local_point(shown.position),shown.size/view.size*size),Rect2(shown.position/overview_scale,shown.size/overview_scale),tint)
	else:
		var first := Vector2i(floori(view.position.x/step),floori(view.position.y/step))
		var last := Vector2i(floori(view.end.x/step),floori(view.end.y/step))
		var columns := ceili(bounds.x/step)
		var rows := ceili(bounds.y/step)
		for ty in range(maxi(first.y,0),mini(last.y,rows-1)+1):
			for tx in range(maxi(first.x,0),mini(last.x,columns-1)+1):
				var at := Vector2i(tx*step,ty*step)
				var key := "%d/%d_%d" % [facet,at.x,at.y]
				if not cache.has(key):
					if not loading.any(func(e): return e[0] == facet and e[1] == at): loading.append([facet,at])
					continue
				var texture: Texture2D = cache[key]
				if texture == null: continue
				# Edge tiles are smaller than a full tile.
				var source := Rect2(Vector2(at),texture.get_size()).intersection(view)
				if not source.has_area(): continue
				draw_texture_rect_region(texture,Rect2(to_local_point(source.position),source.size/view.size*size),Rect2(source.position-Vector2(at),source.size),tint)

func _draw_markers() -> void:
	if not available(): return
	var target := overlay
	# Course lines between pins, then markers.
	for i in range(1,course.size()):
		target.draw_dashed_line(to_local_point(course[i-1]),to_local_point(course[i]),Color(0.25,0.12,0.05,0.85),2.0,6.0)
	var font := Look.ui_font(700)
	for marker in markers:
		var at := to_local_point(marker.at)
		if not Rect2(Vector2(-20,-20),size+Vector2(40,40)).has_point(at): continue
		var color: Color = marker.get("color",Look.GOLD)
		var radius: float = marker.get("size",6.0)
		match str(marker.get("shape","dot")):
			"player":
				var facing: float = marker.get("facing",0.0)
				var forward := Vector2.UP.rotated(facing)
				var side := forward.orthogonal()
				target.draw_circle(at,radius+3,Color(0,0,0,0.55))
				target.draw_colored_polygon(PackedVector2Array([at+forward*(radius+3),at-forward*radius+side*radius,at-forward*(radius*0.4),at-forward*radius-side*radius]),color)
			"diamond":
				target.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-radius-2),at+Vector2(radius,0),at+Vector2(0,radius+2),at+Vector2(-radius,0)]),color)
			"pin":
				target.draw_circle(at,radius+2,Color(0.2,0.1,0.04,0.9))
				target.draw_circle(at,radius,color)
				if marker.has("label"): target.draw_string(font,at+Vector2(-12,4),str(marker.label),HORIZONTAL_ALIGNMENT_CENTER,24,11,Color("2b1a0c"))
			"house":
				target.draw_rect(Rect2(at-Vector2(radius,radius*0.6),Vector2(radius*2,radius*1.4)),color)
				target.draw_colored_polygon(PackedVector2Array([at+Vector2(-radius-2,-radius*0.6),at+Vector2(0,-radius*1.5),at+Vector2(radius+2,-radius*0.6)]),color.darkened(0.3))
			_:
				target.draw_circle(at,radius+1.5,Color(0,0,0,0.6))
				target.draw_circle(at,radius,color)
		if marker.has("label") and str(marker.get("shape","")) != "pin":
			target.draw_string(font,at+Vector2(-60,radius+14),str(marker.label),HORIZONTAL_ALIGNMENT_CENTER,120,11,Look.IVORY)
