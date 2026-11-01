extends MeshInstance3D
# The open sea beyond the near districts (owner: past the detailed water the
# sea ended in a hard straight edge over bare seabed). The near districts carry
# their own water surfaces; around them this is one flat ring of water at UO
# sea level (Z -5), reaching 3 km, rebuilt only when the near window moves.
# Land and the far horizon are higher than the sea, so they cover it wherever
# there is land; the haze fades it into the horizon. Hidden underground.
# Just above UO sea level (Z -5): the far horizon's seabed lies exactly there.
const SEA_LEVEL := -5.0*0.2+0.06
const REACH := 3000.0
var window := Rect2(0,0,0,0)

func configure(material: ShaderMaterial) -> void:
	name = "OceanRing"
	# The near water's shoreline mask belongs to the loaded districts only.
	var sea := material.duplicate() as ShaderMaterial
	sea.set_shader_parameter("has_shore",false)
	sea.set_shader_parameter("min_depth",8.0)
	material_override = sea
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = REACH

# near: the near districts' extent in the scene frame (x, z as x, y).
func follow(near: Rect2, underground: float) -> void:
	visible = underground < 0.5
	if near == window or not near.has_area(): return
	window = near
	var outer := Rect2(near.get_center()-Vector2.ONE*REACH,Vector2.ONE*REACH*2.0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Four strips around the hole: north, south, west, east.
	for strip in [Rect2(outer.position.x,outer.position.y,outer.size.x,near.position.y-outer.position.y),
			Rect2(outer.position.x,near.end.y,outer.size.x,outer.end.y-near.end.y),
			Rect2(outer.position.x,near.position.y,near.position.x-outer.position.x,near.size.y),
			Rect2(near.end.x,near.position.y,outer.end.x-near.end.x,near.size.y)]:
		var a := Vector3(strip.position.x,SEA_LEVEL,strip.position.y)
		var b := Vector3(strip.end.x,SEA_LEVEL,strip.position.y)
		var c := Vector3(strip.end.x,SEA_LEVEL,strip.end.y)
		var d := Vector3(strip.position.x,SEA_LEVEL,strip.end.y)
		for point in [a,b,c,a,c,d]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(point)
	mesh = tool.commit()
