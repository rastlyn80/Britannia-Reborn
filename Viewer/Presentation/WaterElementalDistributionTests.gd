extends SceneTree
## Clean-clone checks; requires neither original game files nor source CC0 imports.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var registry=preload("res://Presentation/CreatureRegistry.gd");registry.load_index()
	check(not DirAccess.dir_exists_absolute("res://local-art"),"Isolated project has no private artwork")
	check(not DirAccess.dir_exists_absolute("res://Art/Quaternius"),"Prepared scene has no dependency on original CC0 source imports")
	check(registry.supports_body(16),"Public water elemental resolves")
	var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=16;root.add_child(actor);actor.set_physics_process(false)
	check(actor.human_visual==null and actor.horse_visual!=null,"Body 16 initializes the actual creature renderer")
	if actor.horse_visual==null:actor.free();quit(1);return
	var visual: Node3D=actor.horse_visual
	check(visual.skeleton.get_bone_count()==65,"Self-contained rig loads")
	for speed in [1.8,6.8]:
		actor.animate(true,0.,.016,speed);await process_frame
		check(visual.current_clip==("Walk" if speed<3.6 else "Run"),"Water movement replacement loads")
	for action in [4,5,6,12]:check(actor.receive_native_action({"protocol":"classic","action":action}),"Prepared attack/cast loads")
	for action: int in [7,8]:
		check(actor.receive_native_action({"protocol":"classic","action":action})
			and visual.current_clip == ("OverheadSurge" if action == 7 else "WaterHold"), "Legacy fluid action plays")
	for action: int in [17,18]:
		check(actor.receive_native_action({"protocol":"classic","action":action})
			and visual.current_clip == ("WaterArmSettle" if action == 17 else "Fidget2"),
			"Distinct Classic fluid fidget plays")
	if registry.entry(16).classic_action_categories.has("15"):
		for action: int in [10, 15, 16]:
			var clip: String = {10: "Hit", 15: "WaterRightRecoil", 16: "WaterLeftRecoil"}[action]
			check(actor.receive_native_action({"protocol":"classic","action":action}) and visual.current_clip == clip,
				"Distinct Classic water recoil plays from the public bundle")
		check(actor.receive_native_action({"protocol":"new","type":4}) and visual.current_clip == "LegacyHit",
			"New protocol retains the original licensed hit motion")
		check_recoil_shapes(visual)
	var corpse:=preload("res://Presentation/CorpseModels.gd").build(16)
	check(corpse!=null and corpse.get_meta("corpse_body")==16 and corpse.get_child_count()==1 and corpse.get_child(0).name=="Puddle","Matching static puddle builds with no private or source artwork")
	check(corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Corpse has no running skeleton")
	if corpse:root.add_child(corpse);corpse.queue_free()
	actor.queue_free();for frame in 2:await process_frame
	print("WATER DISTRIBUTION: ",checks-failures," / ",checks);quit(1 if failures else 0)

func check_recoil_shapes(visual: Node3D) -> void:
	var source := (load("res://Art/Creatures/Water/water-elemental.scn") as PackedScene).instantiate()
	var prior := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var player: AnimationPlayer = visual.animator
	var exact := true
	for label: String in prior.get_animation_list():
		var before := prior.get_animation(label)
		var after := player.get_animation("LegacyHit" if label == "Hit" else label)
		exact = exact and before.length == after.length and before.get_track_count() == after.get_track_count()
		for track in before.get_track_count():
			exact = exact and before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track)
	source.free()
	check(exact, "Previous licensed tracks survive the new motions")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var spans := {}
	var rig: Skeleton3D = visual.skeleton
	for clip: String in ["Hit", "WaterRightRecoil", "WaterLeftRecoil"]:
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for frame in 49:
			player.seek(player.current_animation_length * frame / 48.0, true)
			rig.force_update_all_bone_transforms()
			var hands := Vector2(rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand_l")).origin).y,
				rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand_r")).origin).y)
			low = low.min(hands)
			high = high.max(hands)
		spans[clip] = high - low
	check(spans.Hit.x > 0.25 and spans.Hit.y > 0.45, "Long hit keeps a distinct high recoil")
	check(spans.WaterRightRecoil.y - spans.WaterRightRecoil.x > 0.12, "Right recoil leads with the right arm")
	check(spans.WaterLeftRecoil.x - spans.WaterLeftRecoil.y > 0.12, "Left recoil leads with the left arm")
