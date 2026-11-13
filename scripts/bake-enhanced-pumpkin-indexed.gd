# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-jack-o-lanterns.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Fits := {
	"EnhancedPumpkinCollapse": [1.84, 1.74],
	"EnhancedPumpkinLunge": [1.58, 1.58],
	"EnhancedPumpkinRecoil": [1.13, 1.13],
	"EnhancedPumpkinSway": [1.38, 1.38],
	"EnhancedPumpkinDormant": [.30, .30],
	"EnhancedPumpkinIgnition": [1.36, 1.42],
	"EnhancedPumpkinPlume": [0.0, 1.66],
}


func bake() -> void:
	var destination := OS.get_environment("BR_INDEXED_BAKE_DIRECTORY")
	assert(not destination.is_empty(), "Set BR_INDEXED_BAKE_DIRECTORY to the local build folder.")
	var folder := destination.path_join("pumpkin-head-enhanced")
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	for body: int in [1246, 1247]:
		var row := Registry.entry(body)
		var source := Registry.asset_path(row, "modern")
		assert(FileAccess.get_sha256(source) == row.asset_sha256.modern)
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var player := model.get_node("Actions") as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var count := 0
		for clip: String in Fits:
			var length: float = Fits[clip][body - 1246]
			if length > 0.0:
				assert(library.add_animation(clip, bake_clip(clip, length, false, body)) == OK)
				count += 1
		Exact.check_earlier_keys(player, source)
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, folder.path_join("%d.scn" % body), ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("ENHANCED PUMPKIN FIT: ", body, ", ", count, " fits")
	quit(0)


func sample(name: String, phase: float, blue: bool) -> Array:
	var idle := super.sample("Idle", 0.0, blue)
	var gourd := Vector3.ZERO
	var shift: Vector3 = idle[1]
	var turn: Vector3 = idle[2]
	var stretch: Vector3 = idle[3]
	var jaw: float = idle[4]
	var visible := true
	match name:
		"EnhancedPumpkinLunge", "EnhancedPumpkinPlume":
			var pull := wave(phase, .18)
			var crest := wave(phase, .40)
			var blast := smoothstep(.24, .51, phase) * (1.0 - smoothstep(.66, .99, phase))
			var reach := .82 if name == "EnhancedPumpkinLunge" else 1.17
			shift += Vector3(.17 * crest, .55 * crest - .29 * blast, reach * blast - .23 * pull)
			turn += Vector3(-.52 * crest + .61 * blast, -.29 * pull, .22 * crest)
			stretch *= Vector3(1.0 + .18 * pull, 1.0 + .25 * crest - .28 * blast, 1.0 + reach * blast)
			jaw += .62 * blast
		"EnhancedPumpkinRecoil":
			var recoil := wave(phase, .28)
			var recover := wave(phase, .64)
			shift += Vector3(.08 * recoil, .30 * recover - .18 * recoil, -.35 * recoil + .14 * recover)
			turn += Vector3(-.30 * recover + .22 * recoil, -.46 * recoil + .19 * recover, .25 * recoil)
			jaw += .26 * recoil
		"EnhancedPumpkinSway":
			var round := wave(phase, .47)
			shift += Vector3(.23 * sin(TAU * phase), .28 * round, -.19 * round)
			turn += Vector3(-.19 * round, (.83 if blue else -.46) * round, .21 * round)
			stretch *= Vector3(1.0 + .15 * round, 1.0 - .12 * round, 1.0 + .18 * round)
		"EnhancedPumpkinDormant":
			visible = false
			gourd.z = .015 * sin(TAU * phase)
		"EnhancedPumpkinIgnition":
			var awaken := smoothstep(.25 if blue else .19, .74, phase)
			var overshoot := wave(phase, .72) * awaken
			shift.y = lerpf(.27, shift.y, awaken) + .41 * overshoot
			stretch *= Vector3.ONE * (.06 + .94 * awaken + .16 * overshoot)
			turn.x -= .42 * overshoot
			jaw += .45 * overshoot
			visible = phase >= (.31 if blue else .22)
		"EnhancedPumpkinCollapse":
			var rise := wave(phase, .56 if blue else .62)
			var fade := smoothstep(.50, .92, phase)
			shift += Vector3(.06 * rise, (.66 if blue else .84) * rise, -.12 * rise)
			turn += Vector3(-.46 * rise, (.36 if blue else .75) * rise, .31 * rise)
			stretch *= Vector3(1.0 - .70 * fade, 1.0 + .57 * rise - .75 * fade, 1.0 - .77 * fade)
			jaw += .38 * rise
			visible = phase < (.84 if blue else .89)
	return [gourd, shift, turn, stretch, jaw, visible]
