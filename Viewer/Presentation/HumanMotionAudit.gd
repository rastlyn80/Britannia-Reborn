extends SceneTree
## Feasibility probe only. Does not change the playable gait or robe bake.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage:=Node3D.new()
	root.add_child(stage)
	var source: Node3D=load("res://Art/Quaternius/Animation/UAL1_Standard.glb").instantiate()
	var source_rig: Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer=source.find_children("*","AnimationPlayer",true,false)[0]
	var results: Array=[]
	for female in [false,true]:
		var human:=preload("res://Presentation/HumanVisual.gd").new()
		human.female=female
		stage.add_child(human)
		var animator: AnimationPlayer=human.animator
		var library:=AnimationLibrary.new()
		var paths_valid:=true
		var omitted: Array[String]=[]
		for clip in ["Idle","Walk","Jog_Fwd","Sprint"]:
			var animation:=preload("res://Presentation/AnimationRetarget.gd").retarget(player.get_animation(clip),source_rig,human.skeleton,{"Head":"head"})
			for track in range(animation.get_track_count()-1,-1,-1):
				var path:=animation.track_get_path(track)
				if path.get_subname_count()==0: continue
				var bone:=str(path.get_subname(0))
				if human.skeleton.find_bone(bone)<0:
					if bone not in omitted: omitted.append(bone)
					animation.remove_track(track)
					continue
				animation.track_set_path(track,NodePath(str(animator.get_node(animator.root_node).get_path_to(human.skeleton))+":"+bone))
			library.add_animation(clip,animation)
		animator.add_animation_library("candidate",library)
		var rows: Array=[]
		for clip in ["Idle","Walk","Run","candidate/Idle","candidate/Walk","candidate/Jog_Fwd","candidate/Sprint"]:
			animator.play(clip,0.)
			var finite:=true
			var arm_points: Array[Vector3]=[]
			var foot_points: Array[Vector3]=[]
			for phase in 16:
				animator.seek(animator.current_animation_length*float(phase)/16.,true)
				for bone in human.skeleton.get_bone_count(): finite=finite and human.skeleton.get_bone_global_pose(bone).is_finite()
				arm_points.append(human.skeleton.get_bone_global_pose(human.skeleton.find_bone("hand_l")).origin)
				foot_points.append(human.skeleton.get_bone_global_pose(human.skeleton.find_bone("foot_l")).origin)
			var hand_travel:=0.
			var foot_travel:=0.
			for a in arm_points:
				for b in arm_points: hand_travel=maxf(hand_travel,a.distance_to(b))
			for a in foot_points:
				for b in foot_points: foot_travel=maxf(foot_travel,a.distance_to(b))
			rows.append({"clip":clip,"duration":animator.current_animation_length,"finite":finite,"hand_excursion_m":hand_travel,"foot_excursion_m":foot_travel,"root_stationary":human.position==Vector3.ZERO})
		results.append({"female":female,"all_candidate_tracks_resolve":paths_valid,"omitted_source_only_bones":omitted,"clips":rows})
		human.free()
	source.free()
	stage.free()
	var f:=FileAccess.open("res://../outputs/third-dawn/human-motion-feasibility.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"source":"Quaternius Universal Animation Library 1 / Standard, already bundled CC0","results":results,"status":"Candidates only; not installed as locomotion. Requires gait/foot-contact visual tuning and robe controls rebaked for new motion. Excursion does not establish natural movement."},"\t"))
	print("MOTION FEASIBILITY: bundled Idle/Walk/Jog_Fwd/Sprint retargeted and sampled on both human rigs; candidate only")
	quit(0)
