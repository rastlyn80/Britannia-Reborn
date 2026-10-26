extends Node3D
var fixture_positions: Array[Vector3] = []
var fixture_spans: Array[Dictionary] = []
var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var server_environment := {}
var cloud_clock := 0.0
var precipitation: MultiMeshInstance3D
var shelter_check := 0.0
var sheltered := false
var visual_weather := 0.0
var visual_light := 0.0
var visual_minute := 900.0
var frozen := false
var sky_tick := 0.0

func configure(scene: Node3D,world: Dictionary,reconstruction,map_view: bool, derive_fixtures: bool = true) -> void:
 sun = DirectionalLight3D.new()
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
 sky_material = ShaderMaterial.new()
 sky_material.shader = preload("res://Presentation/Atmosphere.gdshader")
 var noise := FastNoiseLite.new()
 noise.seed = 4171
 noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
 noise.frequency = 0.012
 noise.fractal_octaves = 5
 var cloud_texture := NoiseTexture2D.new()
 cloud_texture.width = 512
 cloud_texture.height = 512
 cloud_texture.seamless = true
 cloud_texture.generate_mipmaps = true
 cloud_texture.noise = noise
 sky_material.set_shader_parameter("cloud_noise",cloud_texture)
 environment.sky.sky_material = sky_material
 frozen = map_view
 _apply_atmosphere(900.0,0.0,0.0,0.0)
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
 _create_precipitation()
 if not derive_fixtures: return
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

func receive_server_environment(state: Dictionary) -> void:
 server_environment = state.duplicate()

func reset_server_environment() -> void:
 server_environment.clear()
 visual_weather = 0.0
 visual_light = 0.0
 visual_minute = 900.0
 if sun and sky_material: _apply_atmosphere(900.0,0.0,0.0,0.0)
 if precipitation: precipitation.visible = false

static func weather_amount(state: Dictionary) -> float:
 # Upstream emits 0=rain, 2=snow, FE/FF=clear. Unknown types cannot invent storms.
 return clampf(float(state.get("density",0))/70.0,0.0,1.0) if int(state.get("weather_type",255)) in [0,2] else 0.0

static func regional_minute(state: Dictionary, now: int) -> float:
 if not state.has("minute_of_day"): return 900.0
 # Extrapolate only between recent server samples. A lost bridge freezes after 30s.
 var elapsed := clampf(float(now-int(state.get("sample_msec",now)))/1000.0,0.0,30.0)
 return fposmod(float(state.minute_of_day)+elapsed/float(state.seconds_per_minute),1440.0)

func _process(delta: float) -> void:
 if not sky_material or frozen: return
 cloud_clock += delta
 var minute := regional_minute(server_environment,Time.get_ticks_msec())
 var day_delta := fposmod(minute-visual_minute+720.0,1440.0)-720.0
 visual_minute = fposmod(visual_minute+day_delta*(1.0-exp(-delta*1.8)),1440.0)
 visual_weather = lerpf(visual_weather,weather_amount(server_environment),1.0-exp(-delta*0.65))
 visual_light = lerpf(visual_light,float(server_environment.get("global_light",0)),1.0-exp(-delta*2.0))
 sky_tick -= delta
 if sky_tick <= 0.0:
  sky_tick = 0.5
  _apply_atmosphere(visual_minute,visual_weather,visual_light,float(server_environment.get("personal_light",0)))
 _animate_precipitation(delta)

func _apply_atmosphere(minute: float, wet: float, level: float, personal: float) -> void:
 # Match upstream's unusually long day: dawn 04-06, daylight 06-22, dusk 22-24.
 var hour := minute/60.0
 var day := smoothstep(4.0,6.0,hour)*(1.0-smoothstep(22.0,24.0,hour))
 var phase := clampf((hour-5.0)/18.0,0.0,1.0)*PI
 var direction := Vector3(cos(phase),maxf(0.08,sin(phase)),0.35).normalized()
 sun.rotation = Vector3(-asin(direction.y),atan2(direction.x,direction.z),0)
 sun.light_color = Color("ffb978").lerp(Color("fff0d9"),smoothstep(0.05,0.6,direction.y))
 var visibility := clampf(1.0-level/32.0,0.12,1.0)
 sun.light_energy = day*1.2*visibility*(1.0-wet*0.65)
 environment.ambient_light_energy = lerpf(0.24,0.58,day)*visibility
 # Personal light improves local readability; it never changes astronomical time.
 environment.tonemap_exposure = 1.05+clampf(personal/31.0,0.0,1.0)*0.25
 environment.fog_light_color = Color("172238").lerp(Color("b4c9d5"),day).lerp(Color("758593"),wet*0.6)
 environment.fog_density = 0.0015+wet*0.009
 sky_material.set_shader_parameter("zenith",Color("071124").lerp(Color("3475a9"),day).lerp(Color("556a7e"),wet*0.75))
 sky_material.set_shader_parameter("horizon",Color("27334d").lerp(Color("d1dfe2"),day).lerp(Color("8b9ba5"),wet*0.7))
 sky_material.set_shader_parameter("sunlight",sun.light_color)
 sky_material.set_shader_parameter("sun_direction",direction)
 sky_material.set_shader_parameter("daylight",day)
 sky_material.set_shader_parameter("cloud_cover",0.30+wet*0.70)
 sky_material.set_shader_parameter("storm",wet)
 # Update at 2Hz, avoiding continual reflection-cubemap regeneration.
 sky_material.set_shader_parameter("cloud_clock",floorf(cloud_clock*2.0)/2.0)

func _create_precipitation() -> void:
 precipitation = MultiMeshInstance3D.new()
 precipitation.name = "ServerPrecipitation"
 var mesh := BoxMesh.new()
 mesh.size = Vector3(0.012,0.22,0.012)
 var material := StandardMaterial3D.new()
 material.albedo_color = Color("b9d6e6")
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 mesh.material = material
 precipitation.multimesh = MultiMesh.new()
 precipitation.multimesh.transform_format = MultiMesh.TRANSFORM_3D
 precipitation.multimesh.mesh = mesh
 precipitation.multimesh.instance_count = 256
 precipitation.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 precipitation.visible = false
 add_child(precipitation)

func _animate_precipitation(delta: float) -> void:
 if not precipitation: return
 var camera := get_viewport().get_camera_3d()
 if not camera: return
 shelter_check -= delta
 if shelter_check <= 0.0:
  shelter_check = 0.25
  var query := PhysicsRayQueryParameters3D.create(camera.global_position+Vector3.UP*0.15,camera.global_position+Vector3.UP*60.0,1)
  sheltered = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
 precipitation.visible = visual_weather > 0.02 and not sheltered
 if not precipitation.visible: return
 var snow := int(server_environment.get("weather_type",255)) == 2
 var amount := ceili(visual_weather*256.0)
 precipitation.multimesh.visible_instance_count = amount
 precipitation.global_position = camera.global_position
 for i in amount:
  var x := fposmod(float(i)*7.371,24.0)-12.0
  var z := fposmod(float(i)*13.517,24.0)-12.0
  var y := 9.0-fposmod(float(i)*3.671+cloud_clock*(1.4 if snow else 13.0),16.0)
  var scale := Vector3(3,0.14,3) if snow else Vector3.ONE
  var position := Vector3(x+sin(cloud_clock+i)*0.25,y,z)
  precipitation.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(scale),position))
