extends Control
# North-up source radar, independent of the 3D camera. No second viewport.
const MAP := Rect2(10,34,220,200)
const MAX_TEXTURES := 36
var scene: Node3D
var folder := ""
var bounds := Rect2i()
var known: Dictionary={}
var textures: Dictionary={}
var needed: Array[Vector2i]=[]
var pixels_per_cell:=1.0
var location:=Vector2.ZERO
var direction:=0
var footer: Label

func configure(owner_scene: Node3D, path: String) -> bool:
 scene=owner_scene
 if not FileAccess.file_exists(path):return false
 var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not index is Dictionary or int(index.get("schema",0))!=1:return false
 folder=path.get_base_dir()
 bounds=Rect2i(index.originX,index.originY,index.width,index.height)
 for at in index.tiles:known[Vector2i(int(at[0]),int(at[1]))]=true
 return true

func _ready() -> void:
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 name="OriginalRadarMinimap"
 set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 offset_left=-260;offset_top=-290;offset_right=-20;offset_bottom=-20
 mouse_filter=Control.MOUSE_FILTER_STOP
 tooltip_text="Original Trammel radar · North up\nWheel or + / − to zoom · arrow follows your character"
 var title:=Label.new();title.text="TRAMMEL  ·  N ↑";title.position=Vector2(12,8);add_child(title)
 for i in 2:
  var button:=Button.new();button.text="−" if i==0 else "+"
  button.position=Vector2(168+i*30,3);button.size=Vector2(28,28)
  button.pressed.connect(func():zoom(0.5 if i==0 else 2.0))
  add_child(button)
 footer=Label.new()
 footer.position=Vector2(10,238);footer.add_theme_font_size_override("font_size",13);add_child(footer)

func zoom(factor: float) -> void:
 pixels_per_cell=clampf(pixels_per_cell*factor,0.25,4.0)
 queue_redraw()

static func marker(point: Vector2, center: Vector2, scale: float) -> Vector2:
 return MAP.get_center()+(point-center)*scale

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom(2.0);accept_event()
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom(0.5);accept_event()

func _process(_delta: float) -> void:
 visible=scene!=null and scene.game.phase=="world" and int(scene.game.player.get("facet",1))==1
 if not visible:return
 location=Vector2(scene.game.player.x+0.5,scene.game.player.y+0.5)
 direction=int(scene.game.player.direction)&7
 footer.text="X %d  Y %d  ·  %.2f×" % [scene.game.player.x,scene.game.player.y,pixels_per_cell]
 var loaded:=0
 for at in needed:
  if textures.has(at):continue
  var image:=Image.load_from_file(folder.path_join("%d_%d.png" % [at.x,at.y]))
  if image:textures[at]=ImageTexture.create_from_image(image)
  loaded+=1
  if loaded>=2:break
 for at in textures.keys():
  if not needed.has(at):textures.erase(at)
 assert(textures.size()<=MAX_TEXTURES)
 queue_redraw()

func _draw() -> void:
 draw_style_box(panel_style(),Rect2(Vector2.ZERO,Vector2(240,270)))
 draw_rect(MAP,Color("101d24"))
 needed.clear()
 var view:=Rect2(location-MAP.size/(2*pixels_per_cell),MAP.size/pixels_per_cell)
 var first:=Vector2i(floori((view.position.x-bounds.position.x)/256),floori((view.position.y-bounds.position.y)/256))
 var last:=Vector2i(floori((view.end.x-bounds.position.x)/256),floori((view.end.y-bounds.position.y)/256))
 for y in range(first.y,last.y+1):
  for x in range(first.x,last.x+1):
   var at:=bounds.position+Vector2i(x,y)*256
   if not known.has(at):continue
   needed.append(at)
   if not textures.has(at):continue
   var texture: Texture2D=textures[at]
   var source:=Rect2(Vector2(at),texture.get_size()).intersection(view)
   if source.has_area():draw_texture_rect_region(texture,Rect2(marker(source.position,location,pixels_per_cell),source.size*pixels_per_cell),Rect2(source.position-Vector2(at),source.size))
 var center:=MAP.get_center()
 var north:=Vector2(0,-1).rotated(direction*PI/4)
 var side:=north.orthogonal()
 draw_circle(center,9,Color(0,0,0,0.8))
 draw_colored_polygon(PackedVector2Array([center+north*9,center-north*6+side*5,center-north*3,center-north*6-side*5]),Color("ffe3a1"))
 draw_rect(MAP,Color("a89b74"),false,1)

func panel_style() -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=Color(0.025,0.045,0.06,0.94)
 style.corner_radius_top_left=8;style.corner_radius_top_right=8;style.corner_radius_bottom_left=8;style.corner_radius_bottom_right=8
 return style
