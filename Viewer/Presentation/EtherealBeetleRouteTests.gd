extends SceneTree
## Item-only route and exact hue/atlas contract. Native summon is a separate test.
const Mounts = preload("res://Presentation/MountVisual.gd")
const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const Surface = preload("res://Presentation/SourceEtherealBeetleSurface.gdshader")
const BODY := 195
const ITEM := 0x3e97
const PREPARATION := "res://local-art/creatures/giant_beetle_ethereal/preparation.json"
const PROOF := "res://../work/creatures/giant-beetle/ethereal-final/item-route.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	Registry.load_index()
	var candidate := "--candidate" in OS.get_cmdline_user_args()
	if candidate:
		var preparation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREPARATION))
		Registry.entries[BODY] = preparation.models[0]
	check(Mounts.horse_body(ITEM) == BODY, "Native mounted item resolves original art key")
	check(Mounts.mount_available(BODY, ITEM), "Native mounted item can create the Ethereal Beetle")
	check(not Mounts.mount_available(BODY, 0x3ebc), "Other mount items cannot use this item-only art")
	var unexpected := Mounts.create(BODY)
	check(unexpected == null, "An unmounted caller cannot create this item-only art")
	if unexpected != null:
		unexpected.free()
	check(not Mounts.supports_body(BODY), "Item-only art never becomes a loose mobile")
	check(not Corpses.supports(BODY), "Item-only art never becomes a static corpse")
	check(not Corpses.catalogue().any(func(row: Dictionary): return int(row.body) == BODY),
		"Item-only art is absent from the corpse catalogue")
	var actor := Mounts.create(BODY, ITEM)
	if actor == null:
		quit(1)
		return
	root.add_child(actor)
	var mesh: MeshInstance3D = actor.model.find_children("*", "MeshInstance3D", true, false)[0]
	for hue in [0x4001, 53, 0x8000 | 53]:
		actor.apply_identity(BODY, hue, ITEM)
		var material := mesh.get_active_material(0) as ShaderMaterial
		check(actor.native_hue == hue and actor.native_mount_item == ITEM, "Raw native hue and item survive dispatch")
		check(material != null and material.shader == Surface, "The original beetle uses the spectral surface")
		if material == null:
			continue
		check(bool(material.get_shader_parameter("use_hue")) == (hue != 0x4001), "Default spectral flag leaves source colours")
		check(bool(material.get_shader_parameter("partial_hue")) == ((hue & 0x8000) != 0), "Partial dye flag reaches spectral surface")
		var atlas: Texture2D = material.get_shader_parameter("atlas")
		check(atlas != null and atlas.get_size() == Vector2(128, 128), "Original atlas dimensions retained")
		if atlas != null:
			var alpha := atlas.get_image().get_pixel(64, 64).a
			check(alpha >= 179.0 / 255.0 and alpha <= 213.0 / 255.0, "Original translucency retained in the shader texture")
	actor.free()
	var proof := FileAccess.open(PROOF if candidate else PROOF.replace(".json", "-active.json"), FileAccess.WRITE)
	proof.store_string(JSON.stringify({
		"checks": checks,
		"failures": failures,
		"candidate": candidate,
		"body_art_key": BODY,
		"mounted_item": ITEM,
		"preparation_sha256": FileAccess.get_sha256(PREPARATION),
		"runtime_sha256": {
			"MountVisual.gd": FileAccess.get_sha256("res://Presentation/MountVisual.gd"),
			"CorpseModels.gd": FileAccess.get_sha256("res://Presentation/CorpseModels.gd"),
			"EtherealBeetleRouteTests.gd": FileAccess.get_sha256("res://Presentation/EtherealBeetleRouteTests.gd"),
			"SourceEtherealBeetleVisual.gd": FileAccess.get_sha256("res://Presentation/SourceEtherealBeetleVisual.gd"),
			"SourceEtherealBeetleSurface.gdshader": FileAccess.get_sha256("res://Presentation/SourceEtherealBeetleSurface.gdshader"),
		},
	}, "\t"))
	proof.close()
	print("ETHEREAL BEETLE ITEM ROUTE: ", checks, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
