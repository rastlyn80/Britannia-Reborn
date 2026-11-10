# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Rabbit := preload("res://Presentation/RabbitVisual.gd")
const Dig := preload("res://Presentation/RabbitTunnelPose.gd")
const BODY := 205
const TUNNEL_NOTICE := 1114450

var scene: Node3D

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	scene.game.module("messages").localized_speech.connect(_localized_speech)

func _localized_speech(serial: int, body: int, kind: int, cliloc: int) -> void:
	if scene.game.phase != "world" or cliloc != TUNNEL_NOTICE or body != BODY or kind != 0:
		return
	var avatar := scene.avatars.get(serial) as Avatar
	if avatar == null or not avatar.horse_visual is Rabbit:
		return
	var rabbit := avatar.horse_visual as Rabbit
	if rabbit.native_body != BODY or rabbit.dead or rabbit.skeleton.has_node("NativeTunnelPose"):
		return
	var dig := Dig.new()
	dig.name = "NativeTunnelPose"
	dig.start(rabbit)
