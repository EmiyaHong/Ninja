extends Node2D

const Gesture = preload("res://scripts/gesture_input.gd")
const BladeHitTest = preload("res://scripts/blade_hit_test.gd")
const Boss = preload("res://scripts/boss_controller.gd")
const TUNING = preload("res://data/combat_tuning.tres")
const ParryTrainer = preload("res://scripts/parry_trainer.gd")

@export_enum("战斗", "自由练刀", "下劈训练", "木桩测试") var initial_mode := 0
@export var initial_dummy_parry_training := false
@export_enum("A 双向接招", "B 严格反向") var training_rule := 0
@export_enum("同向三连 →→→", "交替三连 →←→") var training_pattern := 0
@export_group("Replaceable presentation scenes")
@export var player_view_scene: PackedScene = preload("res://scenes/player_view.tscn")
@export var boss_view_scene: PackedScene = preload("res://scenes/boss_view.tscn")
@export var player_weapon_scene: PackedScene = preload("res://scenes/player_weapon.tscn")
@export_group("Gameplay hurtbox, independent of art")
@export var boss_hurtbox_local := Rect2(-70, -100, 140, 214)
var tuning: Resource = TUNING
var gesture: Node
var boss: Node
var player_weapon: Node2D
var player_view: Node2D
var boss_view: Node2D
var hud: Label
var prompt: Label
var feedback: Label
var detail: Label
var vulnerability: Label
var training: Node
var dummy_parry_training := false
var training_panel: HBoxContainer
var static_dummy_button: Button
var parry_dummy_button: Button
var rule_a_button: Button
var rule_b_button: Button
var pattern_button: Button
var mode := 0
var player_hp := 100.0
var boss_hp := 300.0
var posture := 100.0
var result := ""
var paused := false
var pause_started := 0.0
var clock_offset := 0.0
var next_action := 0.0
var last_action_at := -INF
var effect := 0.0
var effect_color := Color.WHITE
var last_result := ""
var settlement_count := 0
var parry_count := 0
var hit_count := 0
var last_damage := 0.0
var last_posture_damage := 0.0

func now() -> float:
	return (pause_started if paused else Time.get_ticks_usec() / 1000000.0) - clock_offset

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("111c2a"))
	player_view = _existing_or_create("PlayerBody", player_view_scene, Vector2(576, 578))
	boss_view = _existing_or_create("BossBody", boss_view_scene, Vector2(576, 286))
	player_weapon = _existing_or_create("PlayerWeapon", player_weapon_scene, Vector2.ZERO)
	player_weapon.z_index = 20
	gesture = Gesture.new()
	gesture.name = "GestureInput"
	gesture.weapon = player_weapon
	gesture.rest = player_view.position + Vector2(84, -13)
	gesture.clock = now
	gesture.moved.connect(_settle_motion)
	add_child(gesture)
	boss = Boss.new()
	boss.name = "BossTimeline"
	boss.tuning = tuning
	add_child(boss)
	training = ParryTrainer.new()
	training.name = "ParryTrainer"
	add_child(training)
	training.knife_settled.connect(_on_training_result)
	gesture.began.connect(_begin_training_gesture)
	gesture.ended.connect(_cancel_training_gesture)
	_build_hud()
	mode = initial_mode
	dummy_parry_training = initial_dummy_parry_training
	restart()

func _existing_or_create(node_name: String, scene: PackedScene, default_position: Vector2) -> Node2D:
	var existing := get_node_or_null(NodePath(node_name)) as Node2D
	if existing != null: return existing
	var view := scene.instantiate() as Node2D
	view.name = node_name
	view.position = default_position
	add_child(view)
	return view

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_font_override("font", font)
	canvas.add_child(root)
	hud = _label(root, Vector2(40, 20), 22)
	vulnerability = _label(root, Vector2(800, 22), 18)
	prompt = _label(root, Vector2(40, 205), 21)
	prompt.custom_minimum_size.x = 350
	prompt.size.x = 350
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback = _label(root, Vector2(40, 480), 21)
	detail = _label(root, Vector2(40, 657), 17)
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(40, 112)
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	for index in range(4):
		var button := Button.new()
		button.text = ["1 战斗", "2 自由练刀", "3 下劈训练", "4 木桩测试"][index]
		button.pressed.connect(_switch_mode.bind(index))
		buttons.add_child(button)
	var restart_button := Button.new()
	restart_button.text = "R 重开"
	restart_button.pressed.connect(restart)
	buttons.add_child(restart_button)
	var pause_button := Button.new()
	pause_button.text = "Esc 暂停 / 继续"
	pause_button.pressed.connect(toggle_pause)
	buttons.add_child(pause_button)
	var random_button := CheckButton.new()
	random_button.text = "随机招式"
	random_button.toggled.connect(func(value: bool): boss.random_attacks = value; gesture.reset())
	buttons.add_child(random_button)
	training_panel = HBoxContainer.new()
	training_panel.position = Vector2(40, 151)
	training_panel.add_theme_constant_override("separation", 10)
	root.add_child(training_panel)
	static_dummy_button = _training_button("T 静止伤害测试", _select_dummy_training.bind(false))
	parry_dummy_button = _training_button("G 弹反训练", _select_dummy_training.bind(true))
	rule_a_button = _training_button("A 双向接招", _select_training_rule.bind(0))
	rule_b_button = _training_button("B 严格反向", _select_training_rule.bind(1))
	pattern_button = _training_button("C 同向三连 →→→", _toggle_training_pattern)

func _training_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	training_panel.add_child(button)
	return button

func is_parry_training() -> bool:
	return mode == 3 and dummy_parry_training

func _select_dummy_training(enabled: bool) -> void:
	mode = 3
	dummy_parry_training = enabled
	restart()

func _select_training_rule(value: int) -> void:
	training_rule = value
	_select_dummy_training(true)

func _toggle_training_pattern() -> void:
	training_pattern = 1 - training_pattern
	_select_dummy_training(true)

func _begin_training_gesture() -> void:
	if is_parry_training():
		training.begin_gesture(gesture.samples.back().t)

func _cancel_training_gesture() -> void:
	if is_instance_valid(training):
		training.cancel_gesture()

func _on_training_result(index: int, success: bool, reason: String) -> void:
	_message("第 %d 刀：%s · %s" % [index + 1, "成功" if success else "失败", reason], Color("ffe09a") if success else Color("fa8d8d"))
	if success:
		boss_view.flash = 0.15

func _label(parent: Node, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _switch_mode(value: int) -> void:
	mode = value
	restart()

func restart() -> void:
	paused = false
	clock_offset = 0.0
	player_hp = tuning.player_health
	boss_hp = tuning.boss_health
	posture = tuning.boss_posture
	result = ""
	next_action = 0.0
	last_action_at = -INF
	last_result = ""
	settlement_count = 0
	parry_count = 0
	hit_count = 0
	last_damage = 0.0
	last_posture_damage = 0.0
	effect = 0.0
	gesture.enabled = true
	gesture.reset()
	boss.fixed_down = mode == 2
	boss.attacks_enabled = mode != 1 and mode != 3
	boss.reset(now())
	training.reset(now(), training_rule, training_pattern)
	boss_view.flash = 0.0
	var visual := _boss_rig()
	if visual != null: visual.reset_visual()
	_update_boss_weapon()
	_message("按住左键持续挥刀，可连续命中与弹反。", Color("76e9ed"))
	_refresh_hud()
	queue_redraw()

func toggle_pause() -> void:
	if paused:
		clock_offset += Time.get_ticks_usec() / 1000000.0 - pause_started
		paused = false
	else:
		pause_started = Time.get_ticks_usec() / 1000000.0
		paused = true
	gesture.reset()
	_cancel_training_gesture()
	gesture.enabled = not paused and result.is_empty()
	_refresh_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(gesture):
		if not paused and result.is_empty():
			toggle_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: restart()
			KEY_ESCAPE: toggle_pause()
			KEY_1: _switch_mode(0)
			KEY_2: _switch_mode(1)
			KEY_3: _switch_mode(2)
			KEY_4: _switch_mode(3)
			KEY_T: _select_dummy_training(false)
			KEY_G: _select_dummy_training(true)
			KEY_A:
				if mode == 3: _select_training_rule(0)
			KEY_B:
				if mode == 3: _select_training_rule(1)
			KEY_C:
				if mode == 3: _toggle_training_pattern()

func _process(delta: float) -> void:
	if not is_instance_valid(boss):
		return
	if paused or not result.is_empty():
		return
	if is_parry_training():
		training.step(now())
		_update_training_weapon()
		effect = maxf(0.0, effect - delta)
		_refresh_hud()
		queue_redraw()
		return
	# Mouse events settle immediately, before this frame's impact deadline.
	if mode != 1:
		var transition: String = boss.step(now())
		if transition == "hit":
			player_hp = maxf(0, player_hp - tuning.boss_damage)
			hit_count += 1
			player_view.flash = 0.25
			_message("受伤！下次在金色窗口内反向划。", Color("fa8d8d"))
			if player_hp <= 0:
				_finish("失败 · 按 R 重开")
		elif transition == "restore":
			posture = tuning.boss_posture
	_update_boss_weapon()
	effect = maxf(0.0, effect - delta)
	_refresh_hud()
	queue_redraw()

func _valid_motion(motion: Dictionary) -> bool:
	var short_side := minf(get_viewport_rect().size.x, get_viewport_rect().size.y)
	return not motion.is_empty() and motion.distance >= short_side * tuning.minimum_distance_ratio and motion.speed >= tuning.minimum_speed

func boss_hurtbox() -> Rect2:
	return Rect2(boss_view.position + boss_hurtbox_local.position, boss_hurtbox_local.size)

func _settle_motion(at: float) -> void:
	if mode == 1 or paused or not gesture.held or not result.is_empty():
		return
	if is_parry_training():
		training.handle_motion(at, gesture, minf(get_viewport_rect().size.x, get_viewport_rect().size.y))
		_refresh_hud()
		return
	if at < next_action:
		return
	# Each result needs fresh movement after the previous result, even in one hold.
	var motion: Dictionary = gesture.local_motion(at, tuning.local_window, last_action_at)
	if not _valid_motion(motion):
		return
	# Expire vulnerability using the input timestamp even before this frame updates.
	if boss.phase == "broken" and at >= boss.deadline:
		if boss.step(at) == "restore":
			posture = tuning.boss_posture
	var parried := false
	if boss.phase == "windup" and not boss.resolved and at >= boss.deadline - tuning.parry_window and at <= boss.deadline:
		var fresh: Dictionary = gesture.local_motion(at, tuning.local_window, maxf(boss.deadline - tuning.parry_window, last_action_at))
		if _valid_motion(fresh):
			parried = fresh.direction.dot(-boss.direction) >= cos(deg_to_rad(tuning.direction_tolerance_degrees))
	# Empty swings do not start a cooldown. Parry remains spatially unrestricted.
	if not parried and not BladeHitTest.swept_hits(gesture.motion_segment, player_weapon.blade_length, player_weapon.blade_width, boss_hurtbox()):
		return
	settlement_count += 1
	last_action_at = at
	next_action = at + maxf(0.0, tuning.action_interval)
	last_damage = 0.0
	last_posture_damage = 0.0
	var was_broken: bool = boss.phase == "broken"
	if parried:
		parry_count += 1
		last_posture_damage = minf(posture, tuning.parry_posture)
		posture -= last_posture_damage
		boss.interrupt(at, false)
		_message("弹反成功！架势 -%.1f" % last_posture_damage, Color("ffe09a"))
		last_result = "parry"
	else:
		var damage: float = tuning.normal_damage * (tuning.broken_multiplier if was_broken else 1.0)
		last_damage = minf(boss_hp, damage)
		last_posture_damage = 0.0 if was_broken else minf(posture, tuning.normal_posture)
		boss_hp = maxf(0, boss_hp - damage)
		posture -= last_posture_damage
		boss_view.flash = 0.2
		_message("命中！生命 -%.1f · 架势 -%.1f" % [last_damage, last_posture_damage], Color("76e9ed"))
		last_result = "hit"
	posture = maxf(0, posture)
	if boss_hp <= 0:
		_finish("胜利 · 按 R 再战")
	elif posture <= 0 and boss.phase != "broken":
		boss.interrupt(at, true)
		_message("破防！%.1f 秒内攻击造成 %.1f 倍伤害" % [tuning.broken_duration, tuning.broken_multiplier], Color("c2a0ff"))
	_refresh_hud()
	queue_redraw()

func _finish(text: String) -> void:
	result = text
	boss.resolved = true
	boss.phase = "ended"
	gesture.reset()
	gesture.enabled = false
	_update_boss_weapon()

func _message(text: String, color: Color) -> void:
	feedback.text = text
	feedback.modulate = color
	effect_color = color
	effect = 0.22

func _update_boss_weapon() -> void:
	var visual := _boss_rig()
	if visual == null: return
	var state: String = boss.phase
	var duration: float = tuning.windup * (1.5 if boss.fixed_down else 1.0)
	if state == "recovery":
		duration = tuning.recovery
		if boss.interrupted: state = "parried"
	elif state == "broken":
		duration = tuning.broken_duration
	elif state == "ended" and boss_hp > 0:
		state = "idle"
	visual.hit_amount = boss_view.flash
	visual.animate(state, boss.direction, boss.deadline - now(), duration, minf(0.16, tuning.parry_window), now(), "battle_%d" % boss.attack_id)

func _boss_rig() -> Node2D:
	if not is_instance_valid(boss_view) or boss_view.visual_root.get_child_count() == 0:
		return null
	var visual: Node2D = boss_view.visual_root.get_child(0)
	return visual if visual.has_method("animate") and visual.has_method("reset_visual") else null

func _refresh_hud() -> void:
	training_panel.visible = mode == 3
	static_dummy_button.text = ("● " if not dummy_parry_training else "") + "T 静止伤害测试"
	parry_dummy_button.text = ("● " if dummy_parry_training else "") + "G 弹反训练"
	rule_a_button.text = ("● " if training_rule == 0 else "") + "A 双向接招"
	rule_b_button.text = ("● " if training_rule == 1 else "") + "B 严格反向"
	pattern_button.text = "C " + ("同向三连 →→→" if training_pattern == 0 else "交替三连 →←→")
	if is_parry_training():
		_refresh_training_hud()
		return
	vulnerability.text = "易伤 ×%.1f\n剩余 %.2f 秒" % [tuning.broken_multiplier, maxf(0, boss.deadline - now())] if boss.phase == "broken" else "正常伤害 ×1.0"
	vulnerability.modulate = Color("c2a0ff") if boss.phase == "broken" else Color("bac9dc")
	hud.text = "%s   |   玩家生命 %.1f / %.1f\nBoss 生命 %.1f / %.1f    架势 %.1f / %.1f" % [["曲线挥刀 · 战斗", "曲线挥刀 · 自由练刀", "曲线挥刀 · 下劈训练", "曲线挥刀 · 木桩测试"][mode], player_hp, tuning.player_health, boss_hp, tuning.boss_health, posture, tuning.boss_posture]
	var state := "划过 Boss 头部 / 身体造成伤害"
	var color := Color("bac9dc")
	if mode == 1:
		state = "自由画圆弧、S 形与折返\n白点是实际刀尖 · Boss 不攻击"
	elif boss.phase == "broken":
		state = "易伤 ×%.1f · 剩余 %.2f 秒\n实际命中伤害提高 · 架势保持 0" % [tuning.broken_multiplier, maxf(0, boss.deadline - now())]
		color = Color("c2a0ff")
	elif mode == 3:
		state = "木桩不出招 · 划过框内测试数值\n空挥无伤害 · R 重置"
	elif boss.phase == "windup":
		var arrow := "左 → 右" if boss.direction == Vector2.RIGHT else ("右 → 左" if boss.direction == Vector2.LEFT else "上 ↓ 下")
		var counter := "向左 ←" if boss.direction == Vector2.RIGHT else ("向右 →" if boss.direction == Vector2.LEFT else "向上 ↑")
		var remaining: float = boss.deadline - now()
		state = "Boss：%s   %.2f 秒\n%s：%s" % [arrow, maxf(0, remaining), "现在弹反" if remaining <= tuning.parry_window else "准备反向", counter]
		color = Color("ffe09a") if remaining <= tuning.parry_window else Color("f1a58e")
	if not result.is_empty():
		state = result
	if paused:
		state = "已暂停 · Esc 继续\n请重新按住左键开始挥刀"
	prompt.text = state
	prompt.modulate = color
	var required_distance: float = minf(get_viewport_rect().size.x, get_viewport_rect().size.y) * tuning.minimum_distance_ratio
	detail.text = "按住左键持续挥刀，无需松开；实际划过 Boss 才普通命中。\n金色窗口反向划可弹反；需划≥%.1fpx / %.2fs（短边%.1f%%），间隔≥%.2fs。\n本次生命 -%.1f / 架势 -%.1f    %s    结算 %d · 弹反 %d · 受伤 %d\n1 战斗 · 2 自由练刀 · 3 下劈 · 4 木桩 · R 重置 · Esc 暂停" % [required_distance, tuning.local_window, tuning.minimum_distance_ratio * 100.0, maxf(0.0, tuning.action_interval), last_damage, last_posture_damage, "出刀冷却中" if gesture.held and now() < next_action else ("持续跟随中" if gesture.held else "未按住"), settlement_count, parry_count, hit_count]

func _refresh_training_hud() -> void:
	var at := now()
	var settings: Resource = training.tuning
	hud.text = "木桩 · 弹反 A/B 对照（正式战斗仍为原规则）\n%s · %s" % ["A 双向接招：同轴任一方向" if training_rule == 0 else "B 严格反向：必须逆着来刀", "同向三连 → → →" if training_pattern == 0 else "交替三连 → ← →"]
	vulnerability.text = "仅记录成功 / 失败\n不扣生命或架势"
	vulnerability.modulate = Color("bac9dc")
	var index: int = training.current_index(at)
	var state := "第 %d 组 · 回位休息 %.2f 秒\n%s" % [training.group_number, maxf(0.0, training.impact_times[2] + settings.group_rest - at), training.previous_group]
	var color := Color("bac9dc")
	if index >= 0:
		var direction: Vector2 = training.direction_for(index)
		var incoming := "左 → 右" if direction == Vector2.RIGHT else "右 → 左"
		var accepted := "← 或 →（双向）" if training_rule == 0 else ("← 向左" if direction == Vector2.RIGHT else "→ 向右")
		var remaining: float = training.impact_times[index] - at
		state = "第 %d 组 · 第 %d / 3 刀 · %.2f 秒\nBoss 来刀：%s\n玩家可弹：%s · %s" % [training.group_number, index + 1, maxf(0, remaining), incoming, accepted, training.results[index]]
		color = Color("ffe09a") if remaining <= settings.parry_window else Color("bac9dc")
	if paused:
		state = "已暂停 · Esc 继续（重新按下左键）\n" + state
	prompt.text = state
	prompt.modulate = color
	detail.text = "本组：%s    总成功 %d · 失败 %d    %s\n训练专用：窗口 %.2fs · 容差 %.0f° · 距离 短边%.0f%% · 速度≥%.0fpx/s\n可一直按住；每刀需折返或停顿≥%.2fs后重新划动，连续直拖不能连弹。\nT 静止伤害 · G 弹反 · A/B 规则 · C 连段 · R 重开 · Esc 暂停" % [" / ".join(training.results), training.total_success, training.total_failure, training.previous_group, settings.parry_window, settings.direction_tolerance_degrees, settings.minimum_distance_ratio * 100, settings.minimum_speed, settings.pause_to_rearm]

func _update_training_weapon() -> void:
	var visual := _boss_rig()
	if visual == null: return
	var at := now()
	var index: int = training.current_index(at)
	var state := "idle"
	var remaining := 0.0
	var duration: float = training.tuning.windup
	if index < 0 or (index > 0 and at < training.impact_times[index - 1] + 0.2):
		index = 2 if index < 0 else index - 1
		remaining = training.impact_times[index] + 0.2 - at
		duration = 0.2
		state = "parried" if training.results[index] == "成功" else "recovery"
		if remaining <= 0: state = "idle"
	else:
		remaining = training.impact_times[index] - at
		if remaining <= duration:
			state = "parried" if training.results[index] == "成功" else "windup"
			if state == "parried": duration = training.tuning.parry_window
	visual.hit_amount = boss_view.flash
	visual.animate(state, training.direction_for(index), remaining, duration, minf(0.16, training.tuning.parry_window), at, "training_%d_%d" % [training.group_number, index])

func _draw() -> void:
	for x in range(0, 1152, 48):
		draw_line(Vector2(x, 160), Vector2(x, 640), Color("192838"))
	for y in range(160, 641, 48):
		draw_line(Vector2(0, y), Vector2(1152, y), Color("192838"))
	draw_arc(Vector2(576, 575), 83, 0, TAU, 64, Color("29434d"), 2)
	draw_arc(Vector2(576, 285), 106, 0, TAU, 64, Color("533b42"), 2)
	if not is_instance_valid(boss):
		return
	if mode == 3 and not is_parry_training():
		draw_rect(boss_hurtbox(), Color("dcad72"), false, 2)
	_draw_bar(Vector2(40, 88), 310, player_hp / tuning.player_health, Color("76e9ed"))
	_draw_bar(Vector2(420, 88), 310, boss_hp / tuning.boss_health, Color("f1a58e"))
	_draw_bar(Vector2(790, 88), 310, posture / tuning.boss_posture, Color("ffe09a"))
	if effect > 0:
		draw_arc(Vector2(576, 440), 32 + (0.22 - effect) * 180, 0, TAU, 32, Color(effect_color, effect / 0.22), 4)

func _draw_bar(at: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 8)), Color("344154"))
	draw_rect(Rect2(at, Vector2(width * clampf(ratio, 0, 1), 8)), color)
