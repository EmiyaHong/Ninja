extends Node

const BattleScene = preload("res://scenes/battle.tscn")
var battle: Node
var sample_time := 0.0
var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	battle = BattleScene.instantiate()
	battle.tuning = preload("res://scripts/combat_tuning.gd").new()
	add_child(battle)
	battle.set_process(false)
	battle.gesture.clock = func() -> float: return sample_time
	_run()
	print("MOVEMENT_TESTS: %d checks, %d failures: %s" % [checks, failures.size(), failures])

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("TEST FAILED: " + label)

func fresh() -> void:
	battle.mode = 0
	battle.restart()
	battle.set_process(false)
	sample_time = battle.now() + 1.0

func press(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	battle.gesture._input(event)

func move_mouse(point: Vector2, delta: float = 0.04) -> void:
	sample_time += delta
	var event := InputEventMouseMotion.new()
	event.position = point
	battle.gesture._input(event)

func release() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	battle.gesture._input(event)

func _run() -> void:
	# 1. Initial framing and mode-0 defaults
	fresh()
	check(battle.player_view.position == Vector2(576, 578), "initial player position is (576, 578)")
	check(battle.camera.position == Vector2(576, 384), "initial camera center matches original viewport center")
	check(battle.gesture.screen_to_world(Vector2(250, 450)).is_equal_approx(Vector2(250, 450)), "screen_to_world matches screen coords at default camera")

	# 2. Eight-way movement and diagonal normalization
	battle.move_player(Vector2.RIGHT, 1.0)
	check(battle.player_view.position.is_equal_approx(Vector2(576.0 + 320.0, 578.0)), "cardinal right moves by move_speed * delta")
	fresh()
	battle.move_player(Vector2(1.0, -1.0), 1.0)
	var expected_diag := Vector2(576, 578) + Vector2(1.0, -1.0).normalized() * 320.0
	check(battle.player_view.position.is_equal_approx(expected_diag), "diagonal movement is normalized")
	check((battle.player_view.position - Vector2(576, 578)).length() == 320.0, "diagonal displacement equals move_speed")

	# 3. Map boundary clamping
	fresh()
	battle.move_player(Vector2.LEFT, 20.0)
	var area: Rect2 = battle.map_rect.grow(-battle.player_map_margin)
	check(is_equal_approx(battle.player_view.position.x, area.position.x), "left boundary clamps player at map_rect + margin")
	battle.move_player(Vector2.UP, 20.0)
	check(is_equal_approx(battle.player_view.position.y, area.position.y), "top boundary clamps player at map_rect + margin")
	battle.move_player(Vector2.RIGHT, 40.0)
	battle.move_player(Vector2.DOWN, 40.0)
	check(battle.player_view.position.is_equal_approx(area.end), "bottom-right boundary clamps player at map_rect end - margin")

	# 4. Sword tip clamped inside vs outside sword_radius
	fresh()
	var inside_target := Vector2(576 + 120, 578 - 80)
	press(inside_target)
	check(battle.player_weapon.tip.is_equal_approx(inside_target), "tip inside radius stays at exact pointer world position")
	var outside_target := Vector2(576 + 600, 578)
	move_mouse(outside_target)
	check(battle.player_weapon.tip.is_equal_approx(Vector2(576 + battle.sword_radius, 578)), "tip outside radius clamps to circle perimeter")
	check(is_equal_approx(battle.player_weapon.tip.distance_to(battle.player_view.position), battle.sword_radius), "clamped tip distance equals sword_radius")
	var angled_outside := Vector2(576 + 300, 578 - 400)
	move_mouse(angled_outside)
	var expected_dir: Vector2 = (angled_outside - battle.player_view.position).normalized()
	check(((battle.player_weapon.tip - battle.player_view.position).normalized()).is_equal_approx(expected_dir), "clamped tip preserves direction from player to pointer")
	release()

	# 5. Moving body while mouse is held and stationary refreshes tip visually without settling damage
	fresh()
	battle.move_player(Vector2.UP, 0.9) # Move near boss (y = 578 - 288 = 290)
	press(Vector2(200, 384)) # Screen point left of boss
	var tip_before: Vector2 = battle.player_weapon.tip
	battle.move_player(Vector2.RIGHT, 0.5)
	check(not battle.player_weapon.tip.is_equal_approx(tip_before), "body movement with held stationary mouse updates visible blade tip")
	check(battle.settlement_count == 0 and battle.boss_hp == 300, "body movement alone never settles ordinary hit")
	release()

	# 6. Camera follow and screen-to-world conversion after movement
	fresh()
	battle.move_player(Vector2(1.0, 0.0), 1.0) # Player at (896, 578), camera at (896, 384)
	check(battle.camera.position.is_equal_approx(Vector2(896, 384)), "camera follows player with camera_offset in mode 0")
	var world_pt: Vector2 = battle.gesture.screen_to_world(Vector2(576, 384))
	check(world_pt.is_equal_approx(Vector2(896, 384)), "screen center maps to camera world center after walking")

	# 7. Combat distance: far away swing misses, walking close hits, parry ALSO requires Boss claws in sword_radius
	fresh()
	battle.move_player(Vector2.DOWN, 1.5) # Move far below boss (y = 578 + 480 = 1058)
	# Try slashing across boss's screen/world region while far away
	press(Vector2(420, 100))
	move_mouse(Vector2(730, 100))
	check(battle.boss_hp == 300 and battle.settlement_count == 0, "swinging when out of sword_radius reach of boss does not hit")
	release()
	# Parry from far away is now REJECTED because Boss claws are outside sword_radius
	battle.boss.phase = "windup"
	battle.boss.direction = Vector2.RIGHT
	battle.boss.resolved = false
	battle.boss.deadline = sample_time + 0.15
	check(not battle.is_boss_claw_in_sword_range(), "boss claws are outside sword_radius when player is far away")
	press(Vector2(600, 400))
	move_mouse(Vector2(480, 400))
	check(battle.parry_count == 0 and battle.posture == 100, "parry fails when Boss claws are outside player's sword_radius")
	release()
	# Walk back up within reach of boss and slash + parry
	fresh()
	battle.move_player(Vector2.UP, 0.5) # Player at (576, 418), well within 260px of boss hurtbox and claws
	check(battle.is_boss_claw_in_sword_range(), "boss claws are inside sword_radius when player is close")
	press(Vector2(420, 350))
	move_mouse(Vector2(730, 350))
	check(battle.boss_hp == 290 and battle.settlement_count == 1, "walking into range allows ordinary slash to hit boss")
	release()
	sample_time += 0.25
	battle.boss.phase = "windup"
	battle.boss.direction = Vector2.RIGHT
	battle.boss.resolved = false
	battle.boss.deadline = sample_time + 0.15
	press(Vector2(600, 400))
	move_mouse(Vector2(480, 400))
	check(battle.parry_count == 1 and battle.posture == 64, "parry succeeds when Boss claws are inside player's sword_radius")
	release()

	# 8. Other modes (1, 2, 3, 4) reset player/camera, ignore movement, and do not clamp sword radius
	battle.move_player(Vector2.LEFT, 1.0)
	check(battle.player_view.position.x < 576, "player moved away before mode switch")
	for m in [1, 2, 3, 4]:
		battle._switch_mode(m)
		battle.set_process(false)
		check(battle.player_view.position == Vector2(576, 578), "switching to mode %d resets player position" % m)
		check(battle.camera.position == Vector2(576, 384), "switching to mode %d resets camera to default center" % m)
		battle.move_player(Vector2.RIGHT, 1.0)
		check(battle.player_view.position == Vector2(576, 578), "mode %d ignores move_player" % m)
		if m != 4:
			press(Vector2(100, 100))
			check(battle.player_weapon.tip.is_equal_approx(Vector2(100, 100)), "mode %d does not clamp blade tip to sword_radius" % m)
			release()

	# 9. Pause blocks movement in _process
	fresh()
	battle.toggle_pause()
	check(battle.paused, "battle is paused")
	battle._process(0.5)
	check(battle.player_view.position == Vector2(576, 578), "paused _process does not move player")
	battle.toggle_pause()
	check(not battle.paused, "battle unpaused")

	# 10. Strict sword_radius max hit range (D017): trailing blade shaft outside circle cannot hit boss outside circle
	fresh()
	# Boss hurtbox bottom is at y = 292 - 100 + 214 = 406 (or 286 - 100 + 214 = 400).
	# Place player so distance from player to boss hurtbox bottom is ~300px (> sword_radius 260, but < sword_radius + blade_length 370).
	var hurtbox_bottom: float = battle.boss_hurtbox().end.y
	battle.player_view.position = Vector2(576, hurtbox_bottom + 300.0)
	battle.gesture.rest = battle.player_view.position + Vector2(84, -13)
	battle._update_camera()
	check(not battle.is_boss_in_sword_range(), "boss hurtbox is outside sword_radius when 300px away")
	# Swing downward near the top of the circle so the 110px trailing blade shaft would reach 370px upward into the boss if unclamped
	var screen_top_A: Vector2 = battle.get_viewport().get_canvas_transform() * (battle.player_view.position + Vector2(-30, -255))
	var screen_top_B: Vector2 = battle.get_viewport().get_canvas_transform() * (battle.player_view.position + Vector2(30, -245))
	press(screen_top_A)
	move_mouse(screen_top_B, 0.02)
	check(battle.boss_hp == 300 and battle.settlement_count == 0, "blade shaft extending beyond sword_radius cannot hit boss outside circle")
	release()
	# Now step closer so boss hurtbox enters sword_radius (distance 200px <= 260px)
	battle.player_view.position = Vector2(576, hurtbox_bottom + 200.0)
	battle._update_camera()
	check(battle.is_boss_in_sword_range(), "boss hurtbox is inside sword_radius when 200px away")

	# 11. Boss Chase AI and Player Hurtbox / Dodge (D018)
	fresh()
	battle.move_player(Vector2.DOWN, 1.5) # Player walks far down to (576, 1058)
	var boss_y_before: float = battle.boss_view.position.y
	battle.move_boss(1.0) # Boss chases in idle for 1 second
	check(battle.boss_view.position.y > boss_y_before, "boss chases player downward during idle")
	check(not battle.boss.can_start_attack, "boss does not start new windup while player is far outside engage distance")
	# If boss was already winding up and impacts while player is far away, player_hurtbox dodges it
	battle.boss.phase = "windup"
	battle.boss.direction = Vector2.DOWN
	battle.boss.resolved = false
	battle.boss.deadline = battle.now() - 0.01
	check(not battle._boss_attack_hits_player(), "boss claw strike misses player_hurtbox when player walked out of reach")
	battle._process(0.016)
	check(battle.player_hp == 100 and battle.hit_count == 0, "dodging out of boss claw reach avoids HP loss at impact")
	# When player is at default close position, boss claw strike hits player_hurtbox
	fresh()
	check(battle._boss_attack_hits_player(), "boss claw strike intersects player_hurtbox at close combat distance")
	check(battle.training_rule == 1, "default training_rule is confirmed as 1 (B strict opposite)")


