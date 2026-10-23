extends Node

const BattleScene = preload("res://scenes/battle.tscn")
var battle: Node
var sample_time := 0.0
var start := 0.0
var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	battle = BattleScene.instantiate()
	battle.initial_mode = 3
	battle.initial_dummy_parry_training = true
	add_child(battle)
	battle.set_process(false)
	battle.gesture.clock = func() -> float: return sample_time
	_run()
	print("PARRY_AB_TESTS: %d checks, %d failures: %s" % [checks, failures.size(), failures])

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("TEST FAILED: " + label)

func fresh(rule: int = 0, pattern: int = 0) -> void:
	battle.mode = 3
	battle.dummy_parry_training = true
	battle.training_rule = rule
	battle.training_pattern = pattern
	battle.restart()
	start = battle.now() + 10.0
	sample_time = start
	battle.training.reset(start, rule, pattern)

func press(point: Vector2, offset: float) -> void:
	sample_time = start + offset
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	battle.gesture._input(event)

func move(point: Vector2, offset: float) -> void:
	sample_time = start + offset
	var event := InputEventMouseMotion.new()
	event.position = point
	battle.gesture._input(event)

func finish_group() -> void:
	battle.training.step(start + 3.21)

func left_right_left() -> void:
	press(Vector2(640, 430), 1.04)
	move(Vector2(610, 430), 1.08)
	move(Vector2(610, 430), 2.04)
	move(Vector2(640, 430), 2.08)
	move(Vector2(640, 430), 3.04)
	move(Vector2(610, 430), 3.08)
	finish_group()

func _run() -> void:
	fresh()
	var timeline: Array = battle.training.impact_times.duplicate()
	var original_hp: float = battle.player_hp
	var original_boss_hp: float = battle.boss_hp
	var original_posture: float = battle.posture
	check(battle.training.tuning != battle.tuning, "training has an independent tuning resource")
	check(battle.training.tuning.parry_window == 0.2 and battle.training.tuning.direction_tolerance_degrees == 35 and battle.training.tuning.minimum_distance_ratio == 0.02, "training uses intended thresholds regardless of formal Inspector values")
	left_right_left()
	check(battle.training.results == ["成功", "成功", "成功"], "A same-direction three hits accept left/right/left")
	check(battle.gesture.held, "A can finish a group in one held press")
	check(battle.training.impact_times == timeline, "early successful parry cannot reschedule the combo")
	check(battle.training.completed_groups == 1 and battle.training.total_success == 3, "complete three-hit group has correct summary")
	check(battle.player_hp == original_hp and battle.boss_hp == original_boss_hp and battle.posture == original_posture, "training does not damage life or posture")
	check(battle.next_action == 0, "training movement does not spend formal combat cooldown")
	fresh()
	battle.gesture.clock = func() -> float:
		sample_time += 0.00001
		return sample_time
	press(Vector2(640, 430), 1.04)
	move(Vector2(610, 430), 1.08)
	check(battle.training.results[0] == "成功", "real advancing clock cannot exclude the initial pressed sample")
	battle.gesture.clock = func() -> float: return sample_time
	fresh(1)
	var strict_timeline: Array = battle.training.impact_times.duplicate()
	check(is_equal_approx(strict_timeline[0] - start, 1.2) and is_equal_approx(strict_timeline[1] - strict_timeline[0], 1.0) and is_equal_approx(strict_timeline[2] - strict_timeline[1], 1.0), "B has the exact same relative timeline as A")
	left_right_left()
	check(battle.training.results == ["成功", "失败", "成功"], "B same sequence rejects same-direction middle stroke")
	check(battle.training.impact_times == strict_timeline, "failed direction cannot reschedule later impacts")
	fresh(1)
	press(Vector2(640, 430), 1.04)
	move(Vector2(610, 430), 1.08)
	move(Vector2(640, 430), 1.5) # Return outside the next window.
	check(battle.training.total_failure == 0 and battle.next_action == 0, "return stroke outside window causes no failure or cooldown")
	move(Vector2(640, 430), 2.04)
	move(Vector2(610, 430), 2.08)
	move(Vector2(640, 430), 2.5)
	move(Vector2(640, 430), 3.04)
	move(Vector2(610, 430), 3.08)
	finish_group()
	check(battle.training.results == ["成功", "成功", "成功"] and battle.gesture.held, "B return-left-return-left correctly completes group without release")
	fresh(1, 1)
	left_right_left()
	check(battle.training.results == ["成功", "成功", "成功"], "alternating incoming combo permits natural strict opposite left/right/left")
	for rule in [0, 1]:
		fresh(rule)
		press(Vector2(640, 430), 1.04)
		move(Vector2(640, 390), 1.08)
		check(battle.training.results[0] == "失败", "wrong axis fails mode %d" % rule)
		check(battle.training.matches(Vector2.UP, Vector2.DOWN) and not battle.training.matches(Vector2.RIGHT, Vector2.DOWN), "vertical matching respects direction axis")
		check(battle.training.matches(Vector2.DOWN, Vector2.DOWN) == (rule == 0), "vertical same direction allowed only in A")
	fresh()
	press(Vector2(640, 430), 0.5)
	move(Vector2(610, 430), 0.54)
	battle.training.step(start + 1.201)
	check(battle.training.results[0] == "失败", "early stroke is not stored until window")
	fresh()
	press(Vector2(640, 430), 1.23)
	move(Vector2(610, 430), 1.27)
	check(battle.training.results[0] == "失败", "late stroke cannot rewind an impact")
	fresh()
	press(Vector2(640, 430), 1.04)
	move(Vector2(610, 430), 1.08)
	move(Vector2(580, 430), 1.11)
	move(Vector2(550, 430), 1.14)
	check(battle.training.total_success == 1, "one stroke cannot repeatedly settle the same knife")
	fresh()
	press(Vector2(100, 430), 0.05)
	for index in range(1, 161):
		move(Vector2(100 + index * 6, 430), 0.05 + index * 0.02)
	finish_group()
	check(battle.training.results == ["成功", "失败", "失败"], "continuous long straight drag can parry at most one knife")
	check(battle.training.stroke_used, "continuous motion cannot rearm itself merely when time advances")
	fresh()
	press(Vector2(576, 280), 1.01)
	check(battle.training.total_success == 0 and battle.boss_hp == original_boss_hp, "press teleport inside target never parries or causes ordinary damage")
	for index in range(1, 10):
		move(Vector2(576 + (0.1 if index % 2 == 0 else 0), 280), 1.01 + index * 0.02)
	finish_group()
	check(battle.training.total_success == 0, "stationary and tiny jitter cannot parry")
	fresh()
	press(Vector2(640, 430), 1.04)
	move(Vector2(610, 430), 1.08)
	move(Vector2(610, 430), 2.04)
	move(Vector2(580, 430), 2.08)
	check(battle.training.results[1] == "成功", "pause then fresh movement rearms a new stroke without release")
	fresh()
	press(Vector2(640, 430), 1.04)
	move(Vector2(610, 430), 1.08)
	# Short continuous samples, then a real turn inside the second window.
	for index in range(1, 48):
		move(Vector2(610 - index * 3, 430), 1.08 + index * 0.02)
	move(Vector2(499, 430), 2.05)
	move(Vector2(529, 430), 2.09)
	check(battle.training.results[1] == "成功", "direction turn rearms even without a pause")
	fresh()
	press(Vector2(640, 430), 1.04)
	move(Vector2(610, 430), 1.08)
	battle._select_training_rule(1)
	check(not battle.gesture.held and battle.training.total_success == 0 and battle.training.rule == 1, "A/B switch clears old gesture, count, and schedule")
	move(Vector2(580, 430), 1.10)
	check(battle.training.total_success == 0, "old held mouse motion cannot settle after mode switch")
	battle._toggle_training_pattern()
	check(battle.training.pattern == 1 and battle.training.results == ["等待", "等待", "等待"], "combo switch clears all previous knife results")
	battle.restart()
	check(not battle.training.has_gesture and battle.training.completed_groups == 0, "restart invalidates gesture and prior group state")
	fresh()
	press(Vector2(640, 430), 1.04)
	battle.toggle_pause()
	check(not battle.training.has_gesture and not battle.gesture.held, "pause cancels training gesture")
	battle.toggle_pause()
	check(not battle.training.has_gesture, "resume cannot reuse a pre-pause stroke")
	fresh()
	finish_group()
	check(battle.training.results == ["失败", "失败", "失败"] and battle.training.completed_groups == 1, "missing all three still completes a full group")
	battle.training.step(start + 5.201)
	check(battle.training.group_number == 2 and is_equal_approx(battle.training.impact_times[0], start + 6.4), "next group starts after fixed recovery without schedule drift")
	check(battle.training.total_failure == 3, "one miss per knife across rest period")
	battle._select_dummy_training(false)
	check(not battle.is_parry_training() and battle.mode == 3 and not battle.boss.attacks_enabled, "static damage dummy remains independently selectable")
	battle._switch_mode(0)
	check(not battle.is_parry_training() and battle.boss.attacks_enabled, "formal combat exits experiment and uses its original boss logic")
