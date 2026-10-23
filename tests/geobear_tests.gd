extends Node

const RIG = preload("res://scenes/geobear_visual.tscn")
const BATTLE = preload("res://scenes/battle.tscn")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("TEST FAILED: " + label)

func _ready() -> void:
	var rig := RIG.instantiate()
	add_child(rig)
	rig.reset_visual()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/geometric/geobear/parts/front/pivots.json"))
	var joints := {
		"torso": rig.torso, "head": rig.head,
		"upper_arm_r": rig.arm_r, "upper_arm_l": rig.arm_l,
		"forearm_r": rig.forearm_r, "forearm_l": rig.forearm_l,
		"claw_r": rig.claw_r, "claw_l": rig.claw_l,
		"leg_foot_r": rig.get_node("Rig/Torso/LegR"), "leg_foot_l": rig.get_node("Rig/Torso/LegL"),
	}
	var source_origin: Vector2 = rig.get_node("Rig").to_global(Vector2(-627, -1164))
	for part in joints:
		var joint: Node2D = joints[part]
		var data: Dictionary = manifest.parts[part]
		var pivot := Vector2(data.pivot[0], data.pivot[1])
		var parent_pivot := Vector2(627, 1164)
		if data.parent != null:
			var parent: Dictionary = manifest.parts[data.parent]
			parent_pivot = Vector2(parent.pivot[0], parent.pivot[1])
			check(joint.get_parent() == joints[data.parent], part + " has JSON parent")
		check(joint.position.is_equal_approx(pivot - parent_pivot), part + " uses local pivot difference")
		var sprite: Sprite2D = joint.get_node("Sprite")
		check(sprite.position == -pivot and not sprite.centered, part + " uses full-canvas negative pivot offset")
		check(sprite.global_position.is_equal_approx(source_origin), part + " shares exact master canvas at rest")
		check(sprite.z_index == manifest.draw_order_back_to_front.find(part), part + " matches specified draw order")
		check(sprite.texture.get_size() == Vector2(1254, 1254), part + " uses untouched full-size source")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]:
		rig.animate("windup", direction, 0.16, 0.9, 0.16, 10, str(direction))
		var first_r: Vector2 = rig.tip_r.global_position
		var first_l: Vector2 = rig.tip_l.global_position
		rig.animate("windup", direction, 0, 0.9, 0.16, 10.16, str(direction))
		if direction == Vector2.RIGHT:
			check(rig.active_right and not rig.active_left and rig.tip_r.global_position.x - first_r.x > 100, "left-to-right uses character right claw sweeping right")
		elif direction == Vector2.LEFT:
			check(rig.active_left and not rig.active_right and rig.tip_l.global_position.x - first_l.x < -100, "right-to-left uses character left claw sweeping left")
		else:
			check(rig.active_right and rig.active_left and rig.tip_r.global_position.y - first_r.y > 100 and rig.tip_l.global_position.y - first_l.y > 100, "downward strike moves both attached claws down")
		for arm in [rig.arm_r, rig.arm_l]:
			var forearm: Node2D = arm.get_node("Forearm")
			var claw: Node2D = forearm.get_node("Claw")
			check(is_equal_approx(arm.global_position.distance_to(forearm.global_position), Vector2(30, 165).length() * 0.22), "shoulder-elbow length preserved during strike")
			check(is_equal_approx(forearm.global_position.distance_to(claw.global_position), Vector2(80, 267).length() * 0.22), "elbow-wrist length preserved during strike")
		check(rig.trails_r.is_empty() or rig.trails_r.back().p.is_equal_approx(rig.to_local(rig.tip_r.global_position)), "right VFX follows actual attached claw")
		check(rig.trails_l.is_empty() or rig.trails_l.back().p.is_equal_approx(rig.to_local(rig.tip_l.global_position)), "left VFX follows actual attached claw")
	rig.animate("parried", Vector2.DOWN, 0.7, 0.8, 0.16, 11, "recoil")
	check(rig.feedback_strength > 0 and not rig.striking, "parry cancels swing and shows recoil at claws")
	rig.animate("broken", Vector2.DOWN, 2, 2, 0.16, 12, "broken")
	check(rig.torso.position.y > -574 and rig.modulate.b < 1.01 and rig.modulate.r < 1, "broken state slouches with vulnerability color")
	var battle := BATTLE.instantiate()
	battle.tuning = preload("res://scripts/combat_tuning.gd").new()
	add_child(battle)
	battle.set_process(false)
	check(battle.get_node_or_null("BossWeapon") == null, "floating boss placeholder sword is absent")
	check(battle._boss_rig() != null, "default Boss uses articulated geometry bear")
	check(battle.boss_hurtbox().has_point(Vector2(576, 240)) and battle.boss_hurtbox().has_point(Vector2(576, 370)) and not battle.boss_hurtbox().has_point(Vector2(700, 350)), "intentional hurtbox covers head and torso rather than distant claws")
	battle.boss.phase = "windup"
	battle.boss.direction = Vector2.DOWN
	battle.boss.resolved = false
	battle.boss.deadline = battle.now() - 0.01
	battle._process(0.016)
	battle._process(0.016)
	check(battle.player_hp == 80 and battle.hit_count == 1, "two claws still cause only one Boss hit")
	check(battle._boss_rig().phase == "recovery", "visual enters recovery at the same impact that deals damage")
	battle.restart()
	battle.boss.phase = "broken"
	battle._update_boss_weapon()
	check(battle._boss_rig().phase == "broken", "combat broken phase reaches bear pose")
	battle.restart()
	check(battle._boss_rig().phase == "idle" and battle._boss_rig().trails_r.is_empty(), "restart clears attack poses and claw VFX")
	print("GEOBEAR_TESTS: %d checks, %d failures: %s" % [checks, failures.size(), failures])
