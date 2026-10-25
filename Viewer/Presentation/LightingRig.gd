extends Node3D
var fixture_positions: Array[Vector3] = []
var fixture_spans: Array[Dictionary] = []
var environment: Environment
func configure(scene: Node3D,world: Dictionary,reconstruction,map_view: bool) -> void:
 var sun := DirectionalLight3D.new()
 sun.name = "AfternoonSun"
 sun.rotation_degrees = Vector3(-43,-32,0)
 sun.light_color = Color("ffebce")
 sun.light_energy = 1.15
 sun.light_angular_distance = 1.1
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 115
 sun.directional_shadow_blend_splits = true
 sun.shadow_blur = 1.3
 add_child(sun)
 var node := WorldEnvironment.new()
 environment = Environment.new()
 node.environment = environment
 environment.background_mode = Environment.BG_SKY
 environment.sky = Sky.new()
 var sky := ProceduralSkyMaterial.new()
 sky.sky_top_color = Color("688b9f")
 sky.sky_horizon_color = Color("c7d2ca")
 sky.ground_horizon_color = Color("c7d2ca")
 sky.ground_bottom_color = Color("727765")
 environment.sky.sky_material = sky
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
 environment.ambient_light_color = Color("c6d4dc")
 environment.ambient_light_energy = 0.55
 environment.ambient_light_sky_contribution = 0.65
 environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
 environment.tonemap_mode = Environment.TONE_MAPPER_ACES
 environment.tonemap_exposure = 1.05
 environment.ssao_enabled = not map_view
 environment.ssao_radius = 1.1
 environment.ssao_intensity = 1.2
 environment.ssao_power = 1.3
 environment.ssao_detail = 0.6
 environment.ssil_enabled = false # Screen-space bounce leaks across stacked floors and door silhouettes.
 environment.ssil_intensity = 0.55
 environment.ssil_radius = 3.0
 environment.ssr_enabled = false # Rough timber uses stable sky lighting, not unstable screen-space reflections.
 environment.ssr_max_steps = 48
 environment.glow_enabled = not map_view
 environment.glow_intensity = 0.25
 environment.glow_bloom = 0.02
 environment.glow_hdr_threshold = 1.7
 environment.fog_enabled = not map_view
 environment.fog_light_color = Color("aabbb8")
 environment.fog_density = 0.0015
 environment.fog_aerial_perspective = 0.22
 add_child(node)
 if map_view: return
 # Use sky/SSR reflections; Godot 4.7 reflection atlases retain seven texture
 # RIDs on scene teardown (upstream #122498). Do not allocate probe atlases.
 # Derive client-only fixtures from existing indoor furniture, never map coordinates.
 var candidates: Array[Vector3] = []
 for ordinal in reconstruction.groups:
  var group: Dictionary = reconstruction.groups[ordinal]
  if group.owner != ordinal or group.kind not in ["table","counter","bed"]: continue
  if reconstruction.presentation_adjustments.get(ordinal,{}).get("suppress",false): continue
  var source: Dictionary = world.statics[ordinal]
  var center := Vector2(group.low)+Vector2(group.size)*0.5
  candidates.append(Vector3(center.x,float(source.z)*float(world.elevationScale),center.y))
 candidates.sort_custom(func(a: Vector3,b: Vector3): return a.z < b.z if a.z != b.z else (a.x < b.x if a.x != b.x else a.y < b.y))
 for at in candidates:
  var roof := INF
  for ordinal in reconstruction.roofs.tiles:
   var source: Dictionary = world.statics[ordinal]
   var rule: Dictionary = reconstruction.rule_for(int(source.id))
   var anchor: Array = rule.get("anchorOffset",[-1,-1])
   var low := Vector2(float(source.x)+float(anchor[0]),float(source.y)+float(anchor[1]))
   if at.x < low.x or at.x > low.x+1 or at.z < low.y or at.z > low.y+1: continue
   var top := float(reconstruction.roofs.tiles[ordinal].heights[4])
   if top > at.y+2.8: roof = minf(roof,top)
  # Stop at the first real floor/ceiling above the fitting. A basement lamp
  # must not suspend its cable all the way through the bedroom above it.
  for floor in world.statics:
   if reconstruction.rule_for(floor.id).get("kind") != "floor": continue
   if int(floor.x) == floori(at.x) and int(floor.y) == floori(at.z) and float(floor.z)*float(world.elevationScale) > at.y+1.85: roof = minf(roof,float(floor.z)*float(world.elevationScale))
  for floor in world.terrain:
   if int(floor.x) != floori(at.x) or int(floor.y) != floori(at.z): continue
   if reconstruction.info(world,floor.id,false).get("name") == "NODRAW": continue
   if float(floor.z)*float(world.elevationScale) > at.y+1.85: roof = minf(roof,float(floor.z)*float(world.elevationScale))
  for ordinal in scene.interior_shell.ceilings:
   var floor: Dictionary = scene.interior_shell.floor_sources[ordinal]
   if int(floor.x) == floori(at.x) and int(floor.y) == floori(at.z):
    var height := float(floor.z)*float(world.elevationScale)+float(scene.interior_shell.ceilings[ordinal])
    if height > at.y+1.85: roof = minf(roof,height)
  if roof == INF: continue
  var local := Vector3(at.x-float(world.originX),at.y+minf(2.7,roof-at.y-0.35),at.z-float(world.originY))
  var clear := true
  for previous in fixture_positions:
   if previous.distance_to(local) < 4.5: clear = false
  if not clear: continue
  fixture_positions.append(local)
  fixture_spans.append({"source_x":at.x,"source_y":at.z,"lamp_y":local.y,"ceiling_y":roof,"floor_y":at.y})
  _fixture(local,roof-(local.y)-0.13)
  if fixture_positions.size() >= 12: break
func _fixture(at: Vector3, cable: float) -> void:
 var light := OmniLight3D.new()
 light.name = "WarmInteriorLamp"
 light.position = at
 light.light_color = Color("ffd4a0")
 light.light_energy = 1.3
 light.omni_range = 5.5
 light.omni_attenuation = 1.6
 light.shadow_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
 light.shadow_blur = 1.5
 add_child(light)
 var geometry = preload("res://Presentation/GeometryLibrary.gd").new()
 var housing := Node3D.new()
 housing.position = at
 add_child(housing)
 geometry.cylinder(housing,0.12,0.05,Vector3(0,0.13,0),"494537")
 geometry.cylinder(housing,0.10,0.045,Vector3(0,-0.12,0),"494537")
 if cable > 0.12: geometry.cylinder(housing,0.012,cable,Vector3(0,cable/2+0.13,0),"4b473b")
 var bulb := geometry.cylinder(housing,0.075,0.2,Vector3.ZERO,"ffd49b")
 var material := StandardMaterial3D.new()
 material.albedo_color = Color("efcd8f")
 material.emission_enabled = true
 material.emission = Color("ffd398")
 material.emission_energy_multiplier = 2.0
 bulb.material_override = material
 for mesh in housing.get_children():
  if mesh is MeshInstance3D: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
