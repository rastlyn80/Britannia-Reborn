extends PanelContainer
# Spellcasting feedback. When a spell is sent (quickbar, spellbook, Last
# Spell) a bar over the quickbar fills over its cast delay with the spell's
# name and words of power, and light gathers round your hands in the
# school's colour. When the server asks for a target the bar says so and the
# cursor becomes a reticle: red for harmful spells, blue for helpful ones,
# gold otherwise. A fizzle, a broken concentration or missing mana or
# reagents ends the cast with the reason and a puff of smoke. The server
# still decides everything; the delay is ModernUO's own (Cooldowns.gd).
const Look = preload("res://Network/ModernSkin.gd")
const Frame = preload("res://Network/ModernWindow.gd")
const Cooldowns = preload("res://Network/Cooldowns.gd")
const SCHOOL_COLOURS := {"Magery":Color("8fb6ff"),"Necromancy":Color("9fd67a"),"Chivalry":Color("f0d38a"),"Bushido":Color("f08a6a"),"Ninjitsu":Color("b9a2f0"),"Spellweaving":Color("7fe0cf"),"Mysticism":Color("d39af0")}
# Server messages that end a cast, and what the bar says.
const ENDINGS := {502632:"Fizzled",500641:"Concentration broken",502625:"Not enough mana",502630:"Missing reagents",502642:"Already casting",502644:"Not yet recovered",502646:"Cannot cast while frozen",1061091:"Cannot cast in this form"}
var scene: Node3D
var session: Node
var spell := {}
var started := 0
var delay := 1.0
var targeting := false
var title: Label
var words: Label
var bar: ProgressBar
var glow: Node3D
var reticles := {}

func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -250
	custom_minimum_size = Vector2(300,0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",Look.box(Color(0.045,0.05,0.065,0.92),Look.EDGE,10,1,10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	title = Look.label("",14,Look.IVORY,700)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	words = Look.label("",12,Look.ASH,500)
	row.add_child(words)
	bar = Frame.meter(Look.GOLD,8)
	bar.max_value = 1.0
	column.add_child(bar)
	hide()

func configure(world_scene: Node3D, runner: Node) -> void:
	scene = world_scene
	session = runner.session
	runner.cast_started.connect(begin)
	session.target_changed.connect(_target)
	session.message_received.connect(_message)
	session.ended.connect(func(): finish("",false))

func colour() -> Color:
	return SCHOOL_COLOURS.get(str(spell.get("school","Magery")),Look.GOLD)

func begin(cast: Dictionary) -> void:
	spell = cast
	started = Time.get_ticks_msec()
	# Cast delay alone (the recovery after it is the quickbar's timer).
	delay = maxf(0.5,Cooldowns.spell_delay(int(cast.get("id",0)))-1.5)
	targeting = false
	title.text = "Casting %s" % str(cast.name)
	words.text = str(cast.get("words",""))
	bar.add_theme_stylebox_override("fill",Look.box(colour(),Color(0,0,0,0),4,0,0))
	bar.value = 0.0
	modulate = Color.WHITE
	show()
	_glow(true)

func _process(_delta: float) -> void:
	if not visible or spell.is_empty() or targeting: return
	var age := (Time.get_ticks_msec()-started)/1000.0
	bar.value = clampf(age/delay,0.0,1.0)
	# Spells without a target (or a refused cast with no message) end here.
	if age > delay+1.6: finish("",true)

func _target(active: bool) -> void:
	if active and not spell.is_empty() and (Time.get_ticks_msec()-started)/1000.0 < delay+6.0:
		targeting = true
		bar.value = 1.0
		title.text = "%s — choose a target" % str(spell.name)
		var kind := int(session.target_request[6]) if session.target_request.size() > 6 else 0
		Input.set_custom_mouse_cursor(reticle(kind),Input.CURSOR_ARROW,Vector2(16,16))
		var pulse := create_tween().set_loops(3)
		pulse.tween_property(self,"modulate",Color(1.25,1.2,1.1),0.25)
		pulse.tween_property(self,"modulate",Color.WHITE,0.25)
	elif not active and targeting:
		Input.set_custom_mouse_cursor(null)
		finish("",true)

func _message(text: String) -> void:
	if spell.is_empty() or session.labels == null: return
	for number in ENDINGS:
		# The message's own text up to its first argument (mana amounts vary).
		var known: String = str(session.labels.strings.get(str(number),"")).get_slice("~",0).strip_edges()
		if known != "" and text.begins_with(known):
			finish(ENDINGS[number],false)
			return

# Ends the cast: quietly when it went off, with the reason and smoke when not.
func finish(reason: String, success: bool) -> void:
	if spell.is_empty(): return
	if targeting: Input.set_custom_mouse_cursor(null)
	targeting = false
	_glow(false)
	if not success and reason != "":
		title.text = "%s — %s" % [str(spell.name),reason.to_lower()]
		bar.add_theme_stylebox_override("fill",Look.box(Color("8a8a8a"),Color(0,0,0,0),4,0,0))
		_smoke()
		var shake := create_tween()
		for step in [6.0,-6.0,4.0,-4.0,0.0]: shake.tween_property(self,"position:x",position.x+step,0.04)
	spell = {}
	var fade := create_tween()
	fade.tween_interval(0.9 if reason != "" else 0.15)
	fade.tween_property(self,"modulate:a",0.0,0.35)
	fade.tween_callback(func(): if spell.is_empty(): hide())

func _caster() -> Node3D:
	if scene == null: return null
	var avatar: Node3D = scene.avatars.get(int(session.player.get("serial",0)),null)
	return avatar if avatar and is_instance_valid(avatar) else null

# Light and sparks gathering at hand height while the spell is cast.
func _glow(on: bool) -> void:
	if glow and is_instance_valid(glow): glow.queue_free()
	glow = null
	var avatar := _caster()
	if not on or avatar == null: return
	glow = Node3D.new()
	glow.position = Vector3(0,1.15,0)
	var light := OmniLight3D.new()
	light.light_color = colour()
	light.omni_range = 2.4
	light.light_energy = 0.0
	glow.add_child(light)
	light.create_tween().tween_property(light,"light_energy",1.6,delay)
	glow.add_child(_sparks(colour(),56,0.9,Vector3(0,0.6,0),true))
	avatar.add_child(glow)

func _smoke() -> void:
	var avatar := _caster()
	if avatar == null: return
	var puff := _sparks(Color(0.5,0.5,0.52,0.55),22,1.1,Vector3(0,0.7,0),false)
	puff.position = Vector3(0,1.2,0)
	puff.one_shot = true
	puff.explosiveness = 0.9
	avatar.add_child(puff)
	get_tree().create_timer(1.5).timeout.connect(puff.queue_free)

# Soft round motes: additive light for a spell, alpha smoke for a fizzle.
static func _sparks(tone: Color, amount: int, life: float, rise: Vector3, light: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = life
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.35
	process.direction = rise.normalized()
	process.spread = 35.0
	process.initial_velocity_min = rise.length()*0.4
	process.initial_velocity_max = rise.length()
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5 if light else 2.0
	process.scale_max = 1.0 if light else 4.0
	var fade := Gradient.new()
	fade.set_color(0,Color(tone,tone.a))
	fade.set_color(1,Color(tone,0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13,0.13)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if light: look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5,0.5)
	dot.fill_to = Vector2(1.0,0.5)
	var soft := Gradient.new()
	soft.set_color(0,Color(1,1,1,1))
	soft.set_color(1,Color(1,1,1,0))
	dot.gradient = soft
	look.albedo_texture = dot
	quad.material = look
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

# A ring-and-cross targeting cursor in the cast's colour (0x6C cursor type:
# 1 harmful, 2 helpful).
func reticle(kind: int) -> Texture2D:
	if reticles.has(kind): return reticles[kind]
	var tone: Color = Color("ff6b5e") if kind == 1 else (Color("8fc1ff") if kind == 2 else Look.GOLD)
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x-15.5,y-15.5)
			var r := d.length()
			var on := (absf(r-10.5) < 1.3) or ((absi(x-16) <= 0 or absi(y-16) <= 0 or absi(x-15) <= 0 or absi(y-15) <= 0) and r > 4.0 and r < 15.0 and (absf(d.x) < 1.2 or absf(d.y) < 1.2))
			var edge := (absf(r-10.5) < 2.4) or ((absf(d.x) < 2.2 or absf(d.y) < 2.2) and r > 3.0 and r < 15.5)
			if on: image.set_pixel(x,y,tone)
			elif edge: image.set_pixel(x,y,Color(0,0,0,0.7))
	reticles[kind] = ImageTexture.create_from_image(image)
	return reticles[kind]
