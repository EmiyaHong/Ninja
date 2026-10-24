extends Node2D

const Gesture = preload("res://scripts/gesture_input.gd")
const BladeHitTest = preload("res://scripts/blade_hit_test.gd")
const Boss = preload("res://scripts/boss_controller.gd")
const TUNING = preload("res://data/combat_tuning.tres")
const ParryTrainer = preload("res://scripts/parry_trainer.gd")

@export_enum("战斗", "自由练刀", "下劈训练", "木桩测试", "方向手势") var initial_mode := 0
@export var initial_dummy_parry_training := false
@export_enum("A 双向接招", "B 严格反向") var training_rule := 1
@export_enum("同向三连 →→→", "交替三连 →←→") var training_pattern := 0
@export_group("Replaceable presentation scenes")
@export var player_view_scene: PackedScene = preload("res://scenes/player_view.tscn")
@export var boss_view_scene: PackedScene = preload("res://scenes/boss_view.tscn")
@export var player_weapon_scene: PackedScene = preload("res://scenes/player_weapon.tscn")
@export_group("Gameplay hurtbox, independent of art")
@export var boss_hurtbox_local := Rect2(-70, -100, 140, 214)
@export var player_hurtbox_local := Rect2(-32, -56, 64, 96)
@export var boss_claw_box_size := Vector2(124, 124)
@export var boss_attack_reach_local := Rect2(-220, -40, 440, 380)
@export_group("Mode 1 movement and sword range (D016/D018)")
@export var move_speed := 320.0
@export var sword_radius := 260.0
@export var boss_move_speed := 150.0
@export var boss_engage_distance := 250.0
@export var boss_standoff_offset := Vector2(0, -230)
@export var map_rect := Rect2(-1152, -768, 3456, 2304)
@export var player_map_margin := 48.0
@export var camera_offset := Vector2(0, -194)
const DEFAULT_CAMERA_CENTER := Vector2(576, 384)
const Directional = preload("res://scripts/directional_combat.gd")
var directional: Node
var original_tuning: Resource
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
var player_start := Vector2(576, 578)
var boss_start := Vector2(576, 286)
var camera: Camera2D
var hud_overlay: Node2D

func now() -> float:
	return (pause_started if paused else Time.get_ticks_usec() / 1000000.0) - clock_offset

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("111c2a"))
	player_view = _existing_or_create("PlayerBody", player_view_scene, Vector2(576, 578))
	boss_view = _existing_or_create("BossBody", boss_view_scene, Vector2(576, 286))
	player_weapon = _existing_or_create("PlayerWeapon", player_weapon_scene, Vector2.ZERO)
	player_weapon.z_index = 20
	player_start = player_view.position
	boss_start = boss_view.position
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = DEFAULT_CAMERA_CENTER
	camera.limit_left = int(map_rect.position.x)
	camera.limit_top = int(map_rect.position.y)
	camera.limit_right = int(map_rect.end.x)
	camera.limit_bottom = int(map_rect.end.y)
	add_child(camera)
	camera.make_current()
	gesture = Gesture.new()
	gesture.name = "GestureInput"
	gesture.weapon = player_weapon
	gesture.rest = player_view.position + Vector2(84, -13)
	gesture.clock = now
	gesture.tip_filter = clamp_tip
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
	directional = Directional.new()
	add_child(directional)
	directional.battle = self
	original_tuning = tuning
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
	# Bars and hit ring are screen-fixed so the follow camera cannot scroll them away.
	hud_overlay = Node2D.new()
	hud_overlay.name = "HudOverlay"
	hud_overlay.draw.connect(_draw_hud_overlay)
	canvas.add_child(hud_overlay)
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
	for index in range(5):
		var button := Button.new()
		button.text = ["1 战斗", "2 自由练刀", "3 下劈训练", "4 木桩测试", "5 方向手势"][index]
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
	if mode == 4:
		directional.used = false
		directional.stroke = Vector2.ZERO
		directional.last_at = -INF
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
	tuning = directional.settings if mode == 4 else original_tuning
	boss.tuning = tuning
	gesture.direct_control = mode != 4
	directional.cancel()
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
	player_view.position = player_start
	boss_view.position = boss_start
	gesture.rest = player_view.position + Vector2(84, -13)
	_update_camera()
	gesture.enabled = true
	gesture.reset()
	boss.fixed_down = mode == 2
	boss.attacks_enabled = mode != 1 and mode != 3
	boss.can_start_attack = true
	boss.reset(now())
	training.reset(now(), training_rule, training_pattern)
	boss_view.flash = 0.0
	var visual := _boss_rig()
	if visual != null: visual.reset_visual()
	_update_boss_weapon()
	_message("按住左键持续挥刀，可连续命中与弹反。", Color("76e9ed"))
	_refresh_hud()
	_redraw()

func _redraw() -> void:
	queue_redraw()
	if is_instance_valid(hud_overlay): hud_overlay.queue_redraw()

func movement_enabled() -> bool:
	return mode == 0

## Visible blade tip limit: within sword_radius of the body in mode 0 only.
func clamp_tip(world: Vector2) -> Vector2:
	if not movement_enabled():
		return world
	var offset := world - player_view.position
	if offset.length() <= sword_radius:
		return world
	return player_view.position + offset.normalized() * sword_radius

func movement_input() -> Vector2:
	var input := Vector2.ZERO
	if _key_down(KEY_D) or _key_down(KEY_RIGHT): input.x += 1
	if _key_down(KEY_A) or _key_down(KEY_LEFT): input.x -= 1
	if _key_down(KEY_S) or _key_down(KEY_DOWN): input.y += 1
	if _key_down(KEY_W) or _key_down(KEY_UP): input.y -= 1
	return input

func _key_down(code: Key) -> bool:
	return Input.is_physical_key_pressed(code) or Input.is_key_pressed(code)

## Eight-way movement; diagonal is normalized. Callers ensure not paused/ended.
func move_player(input: Vector2, delta: float) -> void:
	if not movement_enabled() or input.is_zero_approx():
		return
	var area := map_rect.grow(-player_map_margin)
	player_view.position = (player_view.position + input.normalized() * move_speed * delta).clamp(area.position, area.end)
	gesture.rest = player_view.position + Vector2(84, -13)
	_update_camera()
	if gesture.held:
		gesture.refresh_tip()
	elif gesture.direct_control:
		player_weapon.follow(gesture.rest, Vector2.ZERO, false)

func _update_camera() -> void:
	if not is_instance_valid(camera): return
	camera.position = player_view.position + camera_offset if movement_enabled() else DEFAULT_CAMERA_CENTER
	if camera.is_inside_tree():
		camera.force_update_scroll()

func toggle_pause() -> void:
	if paused:
		clock_offset += Time.get_ticks_usec() / 1000000.0 - pause_started
		paused = false
	else:
		pause_started = Time.get_ticks_usec() / 1000000.0
		paused = true
	gesture.reset()
	directional.cancel()
	_cancel_training_gesture()
	gesture.enabled = not paused and result.is_empty()
	_refresh_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(gesture):
		if not paused and result.is_empty():
			toggle_pause()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and movement_enabled():
		# Movement is polled in _process; keep arrow keys from moving GUI button focus.
		var move_code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if move_code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		# Global game commands precede GUI focus and use keyboard position under IME.
		if event.alt_pressed or event.ctrl_pressed or event.meta_pressed: return
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var keypad := {KEY_KP_1: KEY_1, KEY_KP_2: KEY_2, KEY_KP_3: KEY_3, KEY_KP_4: KEY_4, KEY_KP_5: KEY_5}
		code = keypad.get(code, code)
		if code not in [KEY_R, KEY_ESCAPE, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_T, KEY_G, KEY_A, KEY_B, KEY_C]: return
		get_viewport().set_input_as_handled()
		match code:
			KEY_R: restart()
			KEY_ESCAPE: toggle_pause()
			KEY_1: _switch_mode(0)
			KEY_2: _switch_mode(1)
			KEY_3: _switch_mode(2)
			KEY_4: _switch_mode(3)
			KEY_5: _switch_mode(4)
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
		_redraw()
		return
	if movement_enabled():
		move_player(movement_input(), delta)
		move_boss(delta)
	# Mouse events settle immediately, before this frame's impact deadline.
	if mode != 1:
		var transition: String = boss.step(now())
		if transition == "hit":
			if _boss_attack_hits_player():
				player_hp = maxf(0, player_hp - tuning.boss_damage)
				hit_count += 1
				player_view.flash = 0.25
				_message("受伤！下次在爪子范围内反向划弹反，或走位躲开。", Color("fa8d8d"))
				if player_hp <= 0:
					_finish("失败 · 按 R 重开")
			else:
				_message("闪避成功！走位躲开了 Boss 爪击。", Color("76e9ed"))
		elif transition == "restore":
			posture = tuning.boss_posture
	if mode == 4 and result.is_empty(): directional.step(now())
	_update_boss_weapon()
	effect = maxf(0.0, effect - delta)
	_refresh_hud()
	_redraw()

func _valid_motion(motion: Dictionary) -> bool:
	var short_side := minf(get_viewport_rect().size.x, get_viewport_rect().size.y)
	return not motion.is_empty() and motion.distance >= short_side * tuning.minimum_distance_ratio and motion.speed >= tuning.minimum_speed

func boss_hurtbox() -> Rect2:
	return Rect2(boss_view.position + boss_hurtbox_local.position, boss_hurtbox_local.size)

func player_hurtbox() -> Rect2:
	return Rect2(player_view.position + player_hurtbox_local.position, player_hurtbox_local.size)

## Returns the two claw hurtboxes of the Boss (right claw and left claw).
func boss_claw_hurtboxes() -> Array[Rect2]:
	var visual := _boss_rig()
	var half := boss_claw_box_size * 0.5
	if visual != null and is_instance_valid(visual.tip_r) and is_instance_valid(visual.tip_l):
		var center_r: Vector2 = 0.5 * (visual.claw_r.global_position + visual.tip_r.global_position)
		var center_l: Vector2 = 0.5 * (visual.claw_l.global_position + visual.tip_l.global_position)
		return [Rect2(center_r - half, boss_claw_box_size), Rect2(center_l - half, boss_claw_box_size)]
	return [
		Rect2(boss_view.position + Vector2(-95, 25) - half, boss_claw_box_size),
		Rect2(boss_view.position + Vector2(95, 25) - half, boss_claw_box_size),
	]

## Returns the active claw hurtboxes for the current incoming attack direction.
func boss_active_claw_hurtboxes() -> Array[Rect2]:
	var boxes := boss_claw_hurtboxes()
	if boss.direction == Vector2.RIGHT:
		return [boxes[0]]
	elif boss.direction == Vector2.LEFT:
		return [boxes[1]]
	return boxes

## True when at least one Boss claw hurtbox overlaps the player's sword_radius circle.
func is_boss_claw_in_sword_range() -> bool:
	_update_boss_weapon()
	for box in boss_claw_hurtboxes():
		if BladeHitTest.rect_overlaps_circle(box, player_view.position, sword_radius):
			return true
	return false

## Mode 0 requires Boss's active claw hurtbox (or either claw) to be inside the player's sword_radius
## in order to parry — the player cannot parry from far away out of claw reach.
func _parry_in_claw_range() -> bool:
	if not movement_enabled():
		return true
	_update_boss_weapon()
	for box in boss_active_claw_hurtboxes():
		if BladeHitTest.rect_overlaps_circle(box, player_view.position, sword_radius):
			return true
	return is_boss_claw_in_sword_range()

## Boss chase AI (mode 0): pursues a standoff position above the player during idle,
## and only starts windup when within engage range of the player.
func move_boss(delta: float) -> void:
	if not movement_enabled() or not is_instance_valid(boss):
		return
	var dist_to_player := boss_view.position.distance_to(player_view.position)
	boss.can_start_attack = dist_to_player <= boss_engage_distance + 80.0 or is_boss_in_sword_range()
	if boss.phase != "idle":
		return
	var target_pos := player_view.position + boss_standoff_offset
	var to_target := target_pos - boss_view.position
	if to_target.length() <= 12.0:
		return
	var area := map_rect.grow(-player_map_margin - 40.0)
	boss_view.position = (boss_view.position + to_target.normalized() * boss_move_speed * delta).clamp(area.position, area.end)

## Boss strike reach box in world space for the current attack direction.
func boss_attack_reach_box() -> Rect2:
	var rect := Rect2(boss_view.position + boss_attack_reach_local.position, boss_attack_reach_local.size)
	for box in boss_active_claw_hurtboxes():
		rect = rect.merge(box.grow(24.0))
	return rect

## Mode 0 checks whether the player's hurtbox is inside the Boss's claw strike reach at impact.
func _boss_attack_hits_player() -> bool:
	if not movement_enabled():
		return true
	_update_boss_weapon()
	return boss_attack_reach_box().intersects(player_hurtbox())

## True when the boss hurtbox intersects the player's sword_radius circle.
func is_boss_in_sword_range() -> bool:
	return BladeHitTest.rect_overlaps_circle(boss_hurtbox(), player_view.position, sword_radius)

## Mode 0 strictly limits ordinary attack judgment to sword_radius; other modes use full-screen sweep.
func _ordinary_sweep_hits() -> bool:
	if movement_enabled():
		return BladeHitTest.swept_hits_in_circle(gesture.motion_segment, player_weapon.blade_length, player_weapon.blade_width, boss_hurtbox(), player_view.position, sword_radius)
	return BladeHitTest.swept_hits(gesture.motion_segment, player_weapon.blade_length, player_weapon.blade_width, boss_hurtbox())

func _settle_motion(at: float) -> void:
	if mode == 1 or paused or not gesture.held or not result.is_empty():
		return
	if is_parry_training():
		training.handle_motion(at, gesture, minf(get_viewport_rect().size.x, get_viewport_rect().size.y))
		_refresh_hud()
		return
	if mode == 4:
		directional.handle_motion(at)
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
		if _valid_motion(fresh) and fresh.direction.dot(-boss.direction) >= cos(deg_to_rad(tuning.direction_tolerance_degrees)):
			parried = _parry_in_claw_range()
	# Empty swings do not start a cooldown.
	if not parried and not _ordinary_sweep_hits():
		return
	_resolve_attack(at, parried)

func _resolve_attack(at: float, parried: bool) -> void:
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
	_redraw()

func _finish(text: String) -> void:
	directional.cancel()
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
	hud.text = "%s   |   玩家生命 %.1f / %.1f\nBoss 生命 %.1f / %.1f    架势 %.1f / %.1f" % [["曲线挥刀 · 战斗", "曲线挥刀 · 自由练刀", "曲线挥刀 · 下劈训练", "曲线挥刀 · 木桩测试", "方向手势 · 对战实验"][mode], player_hp, tuning.player_health, boss_hp, tuning.boss_health, posture, tuning.boss_posture]
	var state := "空白处短划，飞剑自动斩向熊" if mode == 4 else "划过 Boss 头部 / 身体造成伤害"
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
	if mode == 4: state += "\n任意空白处短划 · 自动锁定熊"
	prompt.text = state
	prompt.modulate = color
	var required_distance: float = minf(get_viewport_rect().size.x, get_viewport_rect().size.y) * tuning.minimum_distance_ratio
	detail.text = "按住左键持续挥刀，无需松开；实际划过 Boss 才普通命中。\n金色窗口反向划可弹反；需划≥%.1fpx / %.2fs（短边%.1f%%），间隔≥%.2fs。\n本次生命 -%.1f / 架势 -%.1f    %s    结算 %d · 弹反 %d · 受伤 %d\n1 战斗 · 2 自由练刀 · 3 下劈 · 4 木桩 · R 重置 · Esc 暂停" % [required_distance, tuning.local_window, tuning.minimum_distance_ratio * 100.0, maxf(0.0, tuning.action_interval), last_damage, last_posture_damage, "出刀冷却中" if gesture.held and now() < next_action else ("持续跟随中" if gesture.held else "未按住"), settlement_count, parry_count, hit_count]

	if mode == 4:
		detail.text = "5 方向手势：按住左键短划；折返或停顿0.12秒再划可连出。1 回原控刀\n独立参数：生命100 · 窗口0.20秒 · 容差35° · 距离短边2%% · 速度180px/s\n飞剑实际穿过目标才伤害；金色窗口新鲜反向划可取消普攻弹反。\n结算 %d · 弹反 %d · 受伤 %d · R 重开 · Esc 暂停" % [settlement_count, parry_count, hit_count]

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
	# D016: whole-map grid with a clear boundary (no art yet).
	var grid_color := Color("192838")
	var x := map_rect.position.x
	while x <= map_rect.end.x:
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), grid_color)
		x += 48.0
	var y := map_rect.position.y
	while y <= map_rect.end.y:
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), grid_color)
		y += 48.0
	draw_rect(map_rect, Color("63808f"), false, 4)
	if not is_instance_valid(boss):
		return
	# Ground rings follow their actors (same offsets as the former fixed rings).
	draw_arc(player_view.position + Vector2(0, -3), 83, 0, TAU, 64, Color("29434d"), 2)
	draw_arc(boss_view.position + Vector2(0, -7), 106, 0, TAU, 64, Color("533b42"), 2)
	if movement_enabled():
		var in_range := is_boss_in_sword_range()
		var claw_in_range := is_boss_claw_in_sword_range()
		var ring_color := Color(0.46, 0.91, 0.93, 0.42) if (in_range or claw_in_range) else Color(0.46, 0.91, 0.93, 0.16)
		var box_color := Color(0.46, 0.91, 0.93, 0.78) if in_range else Color(0.86, 0.68, 0.45, 0.35)
		draw_arc(player_view.position, sword_radius, 0, TAU, 96, ring_color, 2.5 if (in_range or claw_in_range) else 2.0)
		draw_rect(boss_hurtbox(), box_color, false, 2.0)
		draw_rect(player_hurtbox(), Color(0.46, 0.91, 0.93, 0.55), false, 1.5)
		var claw_color := Color(1.0, 0.88, 0.60, 0.85) if (boss.phase == "windup" and claw_in_range) else (Color(0.95, 0.65, 0.56, 0.65) if claw_in_range else Color(0.95, 0.65, 0.56, 0.28))
		for claw_box in boss_claw_hurtboxes():
			draw_rect(claw_box, claw_color, false, 2.0)
	if mode == 3 and not is_parry_training():
		draw_rect(boss_hurtbox(), Color("dcad72"), false, 2)

func _draw_hud_overlay() -> void:
	if not is_instance_valid(boss):
		return
	_draw_bar(Vector2(40, 88), 310, player_hp / tuning.player_health, Color("76e9ed"))
	_draw_bar(Vector2(420, 88), 310, boss_hp / tuning.boss_health, Color("f1a58e"))
	_draw_bar(Vector2(790, 88), 310, posture / tuning.boss_posture, Color("ffe09a"))
	if effect > 0:
		hud_overlay.draw_arc(Vector2(576, 440), 32 + (0.22 - effect) * 180, 0, TAU, 32, Color(effect_color, effect / 0.22), 4)

func _draw_bar(at: Vector2, width: float, ratio: float, color: Color) -> void:
	hud_overlay.draw_rect(Rect2(at, Vector2(width, 8)), Color("344154"))
	hud_overlay.draw_rect(Rect2(at, Vector2(width * clampf(ratio, 0, 1), 8)), color)
