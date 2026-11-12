# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted


static func present(presenter: Node3D, at: Vector3, tint: Color, effect: Dictionary, follow := 0) -> void:
	var seconds := clampf(float(effect.get("duration",10))*0.1,0.6,3.0)
	var bloom: GPUParticles3D = presenter.sparks(tint,70,0.9,0.35,1.2)
	bloom.position = at
	presenter.add_child(bloom)
	# A soft halo at the heart of the effect.
	var halo := MeshInstance3D.new()
	halo.mesh = QuadMesh.new()
	halo.mesh.size = Vector2(1.4,1.4)
	halo.material_override = presenter._glow(Color(tint,0.55),2.5)
	bloom.add_child(halo)
	var light: OmniLight3D = presenter._light(at+Vector3.UP*0.3,tint,2.2,4.5)
	if follow and presenter.scene.avatars.has(follow):
		var tree := presenter.get_tree()
		var target_ref: WeakRef = weakref(presenter.scene.avatars[follow])
		var cloud_ref: WeakRef = weakref(bloom)
		var light_ref: WeakRef = weakref(light)
		var track := func():
			var target := target_ref.get_ref() as Node3D
			var cloud := cloud_ref.get_ref() as Node3D
			var lamp := light_ref.get_ref() as OmniLight3D
			if target != null and cloud != null:
				cloud.global_position = target.global_position + Vector3.UP
				if lamp != null:
					lamp.global_position = cloud.global_position
		tree.process_frame.connect(track)
		bloom.tree_exiting.connect(func():
			if tree.process_frame.is_connected(track):
				tree.process_frame.disconnect(track), CONNECT_ONE_SHOT)
	var stop := bloom.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	stop.tween_interval(seconds)
	stop.tween_callback(bloom.set.bind("emitting", false))
	presenter.create_tween().tween_property(light,"light_energy",0.0,seconds+0.4)
	presenter._expire(bloom,seconds+1.0)
	presenter._expire(light,seconds+0.5)
