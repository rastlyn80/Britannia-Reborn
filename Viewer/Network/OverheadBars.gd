extends Control
# Health bars over heads in a fight, as the classic client's overhead bars:
# your target (the server's attack target first, else the one you selected),
# anyone who hit or was hit near you in the last few seconds, and yourself
# in war mode. A bar sits under the name in the notoriety colour's frame,
# red (green when poisoned, gold when it cannot be harmed). A ring on the
# ground marks the target: red when attacking, gold when only selected.
# Screen drawing, like the names, so it stays sharp at any distance.
const Look = preload("res://Network/ModernSkin.gd")
const Runner = preload("res://Network/ActionRunner.gd")
const Names = preload("res://Network/MobileNames.gd")
const RANGE := 18
const RECENT_MS := 10000
const SIZE := Vector2(66,7)
var scene: Node3D
var game: Node
var combat: RefCounted
# serial -> last time it fought (ms)
var fighting := {}
# serial -> last status request (ms)
var asked := {}
var ring: MeshInstance3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	game = scene.game
	combat = game.module("combat")
	combat.damaged.connect(func(serial: int, _amount: int): fighting[serial] = Time.get_ticks_msec())
	combat.swung.connect(func(attacker: int, defender: int):
		fighting[attacker] = Time.get_ticks_msec()
		fighting[defender] = Time.get_ticks_msec())
	game.ended.connect(func():
		fighting.clear()
		asked.clear())
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.56
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	ring.scale = Vector3(1,0.12,1)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.no_depth_test = false
	ring.material_override = glow
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	scene.add_child(ring)

# The creature the target frame shows: the server's attack target, else the
# selected or last targeted one.
static func target_of(session: Node) -> int:
	var attacking: int = session.module("combat").attack_target
	if attacking != 0 and session.entities.has(attacking): return attacking
	return Runner.selected if Runner.selected != 0 else Runner.last_target

func _anchor(serial: int) -> Variant:
	var avatar: Node3D = scene.avatars.get(serial,null)
	if avatar == null or not is_instance_valid(avatar): return null
	var plate := avatar.get_node_or_null("Nameplate") as Node3D
	return plate.global_position if plate else avatar.global_position+Vector3.UP*2.1

func _process(_delta: float) -> void:
	queue_redraw()
	if game == null or game.phase != "world":
		ring.visible = false
		return
	var target := target_of(game)
	var avatar: Node3D = scene.avatars.get(target,null)
	ring.visible = avatar != null and is_instance_valid(avatar) and target != int(game.player.get("serial",0))
	if ring.visible:
		ring.global_position = avatar.global_position+Vector3.UP*0.04
		var attacking: bool = combat.attack_target == target
		var tone: Color = Color("e0574c") if attacking else Look.GOLD
		# A slow pulse keeps the ring noticeable without flashing.
		tone.a = 0.55+0.25*sin(Time.get_ticks_msec()/260.0)
		ring.material_override.albedo_color = tone

func shown_serials() -> Array:
	var now := Time.get_ticks_msec()
	var result := []
	var target := target_of(game)
	if target != 0: result.append(target)
	for serial in fighting.keys():
		if now-int(fighting[serial]) > RECENT_MS: fighting.erase(serial)
		elif not result.has(serial): result.append(serial)
	var me := int(game.player.get("serial",0))
	if bool(game.player.get("war",false)) or (int(game.player.get("flags",0)) & 0x40) != 0:
		if not result.has(me): result.append(me)
	return result

func _draw() -> void:
	if game == null or game.phase != "world" or scene == null: return
	var camera: Camera3D = scene.camera
	var me := Vector2i(int(game.player.get("x",0)),int(game.player.get("y",0)))
	var now := Time.get_ticks_msec()
	for serial in shown_serials():
		var mobile: Dictionary = game.player if serial == int(game.player.get("serial",0)) else game.entities.get(serial,{})
		if mobile.is_empty() or maxi(absi(int(mobile.get("x",0))-me.x),absi(int(mobile.get("y",0))-me.y)) > RANGE: continue
		var at: Variant = _anchor(serial)
		if at == null or camera.is_position_behind(at): continue
		var stats: Dictionary = game.player_status if serial == int(game.player.get("serial",0)) else game.mobile_statistics.get(serial,{})
		if not stats.has("hits") and now-int(asked.get(serial,-100000)) > 3000:
			asked[serial] = now
			game.send(Names.query(serial))
		var point := camera.unproject_position(at)+Vector2(0,12)
		var box := Rect2(point-Vector2(SIZE.x/2,0),SIZE).grow(1)
		var notoriety: Array = preload("res://Network/TargetFrame.gd").NOTORIETY.get(int(mobile.get("notoriety",0)),["b8b2a4",""])
		draw_rect(box.grow(1),Color(0.02,0.025,0.03,0.85))
		draw_rect(box,Color(notoriety[0]).darkened(0.25),false,1.0)
		var top := maxi(1,int(stats.get("hits_max",0)))
		var share := clampf(float(stats.get("hits",top))/top,0,1) if stats.has("hits") else 1.0
		var poisoned := bool(stats.get("poisoned",false)) or (int(mobile.get("flags",0)) & 0x04) != 0
		var fill: Color = Color("6dbe5a") if poisoned else (Look.GOLD if stats.get("yellow_bar",false) else Color("d8483d"))
		if not stats.has("hits"): fill = Color(0.6,0.6,0.6,0.5)
		draw_rect(Rect2(box.position+Vector2(1,1),Vector2((box.size.x-2)*share,box.size.y-2)),fill)
