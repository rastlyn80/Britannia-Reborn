extends SceneTree
## Drives decoded packets through the staged World presentation and item handlers.

const Mounts := preload("res://Presentation/MountVisual.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const CorpseHue := 0x8455

var checks := 0
var failed := false


func _initialize() -> void:
	create_timer(200.).timeout.connect(func(): quit(1))
	run.call_deferred()


func run() -> void:
	var scene := load("res://Main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if not expect(world.enhanced_creature_actions == enhanced, "world initialized in requested mode"):
		return
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for body: int in Mounts.Horse.BODIES:
		if not await check_body(world, at, body, enhanced):
			return
	if not expect(not Mounts.Horse.supports_fitted_identity(200, 0x3eaa) and not Mounts.Horse.supports_fitted_identity(144, 0x3eb3),
			"ethereal and seahorse keep their own established visuals"):
		return
	print("ORDINARY HORSE WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit(0)


func check_body(world: Node3D, at: Vector2i, body: int, enhanced: bool) -> bool:
	var serial := 0x2000 + body * 3
	var mount_item: int = Mounts.Horse.BODIES[body]
	var rider := serial + 2
	world.game._handle(mobile_packet(at, rider, 400, 0))
	world.game._handle(wear_packet(rider, mount_item, CorpseHue))
	var rider_avatar: Node3D = world.avatars.get(rider)
	if not expect(is_instance_valid(rider_avatar) and rider_avatar.horse_visual != null, "native layer 25 creates rider"):
		return false
	var mounted: Node3D = rider_avatar.horse_visual
	if not expect(mounted.native_body == body and mounted.native_hue == CorpseHue \
			and mounted is Mounts.Horse and mounted.fitted_enabled() == enhanced, "ridden body and hue select the requested mode"):
		return false
	if not expect(mounted.seat().is_finite() and mounted.stirrup(true).is_finite(), "ridden sockets remain finite"):
		return false
	world.game._handle(action_packet(rider, 3, 1))
	if not expect(not mounted.dead, "a rider action packet cannot trigger the horse's own fall"):
		return false
	for parity in range(2 if enhanced else 1):
		if not await check_loose(world, at, body, serial + parity, enhanced, parity):
			return false
	return true


func check_loose(world: Node3D, at: Vector2i, body: int, serial: int, enhanced: bool, parity: int) -> bool:
	world.game._handle(mobile_packet(at, serial, body, 0x40))
	var avatar: Node3D = world.avatars.get(serial)
	if not expect(is_instance_valid(avatar), "packet creates loose horse avatar"):
		return false
	var actor: Node3D = avatar.horse_visual
	if not expect(actor is Mounts.Horse and actor.fitted_enabled() == enhanced and actor.native_body == body, "ordinary horse selects requested mode"):
		return false
	world.game._handle(action_packet(serial, 11, parity))
	var expected: String = ["DappleLongRear", "DappleStrikingRear"][int(body in [204, 228])] if enhanced else "idle"
	if not expect(actor.current_clip == expected, "gesture selects exact body-specific fit"):
		return false
	world.game._handle(action_packet(serial, 3, parity))
	expected = Mounts.Horse.Motion.FITS[parity + 2][0] if enhanced else "death"
	if not expect(actor.current_clip == expected and actor.dead, "packet selects death and holds action"):
		return false
	var corpse := 0x40000000 + serial
	world.game._handle(corpse_packet(at, corpse, body, 0))
	world.game._handle(death_packet(serial, corpse))
	var holder: Node3D = world.world_items.nodes.get(corpse)
	if not expect(is_instance_valid(holder), "native graphic 0x2006 builds corpse holder"):
		return false
	if enhanced:
		var state: Dictionary = world.creature_deaths.active.get(serial, {})
		if not expect(not state.is_empty() and not holder.visible and state.visual.current_clip == expected,
				"native death handoff continues the selected fall"):
			return false
		await create_timer(float(state.remaining) + .18).timeout
	var frozen := holder.get_node_or_null("CorpseVisual") as Node3D
	if not expect(frozen != null and holder.visible and frozen.get_meta("death_clip", "") == expected,
			"static corpse uses the expected fall"):
		return false
	var old_transform := frozen.global_transform
	var old_bounds: AABB = frozen.get_meta("corpse_bounds")
	world.game._handle(corpse_packet(at, corpse, body, CorpseHue))
	var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
	return expect(dyed.get_meta("native_hue") == CorpseHue and dyed.get_meta("death_clip") == expected
		and dyed.global_transform.is_equal_approx(old_transform) and dyed.get_meta("corpse_bounds") == old_bounds,
		"late partial hue retains static geometry and placement")


func mobile_packet(at: Vector2i, serial: int, body: int, flags: int) -> PackedByteArray:
	var bytes := PackedByteArray([0x77])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(body, 2))
	bytes.append_array(Wire.uint_be(at.x, 2))
	bytes.append_array(Wire.uint_be(at.y, 2))
	bytes.append_array(PackedByteArray([0, 0, 0, 0, flags, 1]))
	return bytes


func action_packet(serial: int, type: int, variation: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(PackedByteArray([0, type, 0, 0, variation]))
	return bytes


func wear_packet(owner: int, item: int, hue: int) -> PackedByteArray:
	var bytes := PackedByteArray([0x2e])
	bytes.append_array(Wire.uint_be(0x40010000 + owner, 4))
	bytes.append_array(Wire.uint_be(item, 2))
	bytes.append_array(PackedByteArray([0, 25]))
	bytes.append_array(Wire.uint_be(owner, 4))
	bytes.append_array(Wire.uint_be(hue, 2))
	return bytes


func corpse_packet(at: Vector2i, serial: int, body: int, hue: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xf3, 0, 1, 0])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(0x2006, 2))
	bytes.append(0)
	bytes.append_array(Wire.uint_be(body, 2))
	bytes.append_array(Wire.uint_be(body, 2))
	bytes.append_array(Wire.uint_be(at.x, 2))
	bytes.append_array(Wire.uint_be(at.y, 2))
	bytes.append_array(PackedByteArray([0, 1]))
	bytes.append_array(Wire.uint_be(hue, 2))
	bytes.append_array(PackedByteArray([0, 0, 0]))
	return bytes


func death_packet(serial: int, corpse: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xaf])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(corpse, 4))
	bytes.append_array(Wire.uint_be(0, 4))
	return bytes


func expect(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failed = true
		printerr("ORDINARY HORSE WORLD FAIL: ", message)
		quit(1)
	return value
