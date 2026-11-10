# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/goat-eagle/"
const GoatClips := {25: "GoatQuietStand", 26: "GoatLoweredHornCheck"}
const GoatLengths := {25: 1.0, 26: 1.10}

func run() -> void:
	prepare_body(209, GoatClips, GoatLengths, CommonJoints + ["bip01 neck1"], pose_goat, Stage)
	quit()

func pose_goat(rig: Skeleton3D, phase: float, group: int) -> void:
	var breath := sin(TAU * phase)
	var dip := envelope(phase, .02, .25, .71, .95) if group == 26 else 0.0
	var turn := .24 * sin(PI * phase) * dip
	var anchor := hind_midpoint(rig)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .03 * breath + .15 * dip)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .43 * dip)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .50 * dip)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .21 * dip)
	turn_world(rig, "bip01 head", Vector3.UP, turn)
	turn_world(rig, "bip01 ponytail1", Vector3.BACK, .14 * dip)
	turn_world(rig, "bip01 ponytail2", Vector3.BACK, -.12 * dip)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.15 * dip + .055 * breath)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.19 * dip)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .26 * dip)
	anchor_hind_paws(rig, anchor)
