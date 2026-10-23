extends Node

const BattleScene = preload("res://scenes/battle.tscn")
var battle: Node
var sample_time := 0.0
var checks := 0
var failures: Array[String] = []
var original_boss_visual: PackedScene

func _ready() -> void:
	battle = BattleScene.instantiate()
	# Tests use defaults; preserve the user's saved Inspector tuning resource.
	battle.tuning = preload("res://scripts/combat_tuning.gd").new()
	add_child(battle)
	original_boss_visual = battle.boss_view.actor_visual_scene
	battle.set_process(false)
	battle.gesture.clock = func() -> float: return sample_time
	_run()
	_tuning_percent_checks()
	_art_checks()
	fresh()
	battle.mode = 3
	battle.boss.attacks_enabled = false
	battle._refresh_hud()
	print("COMBAT_TESTS: %d checks, %d failures: %s" % [checks, failures.size(), failures])

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

func move(point: Vector2, delta: float = 0.04) -> void:
	sample_time += delta
	var event := InputEventMouseMotion.new()
	event.position = point
	battle.gesture._input(event)

func release() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	battle.gesture._input(event)

func slash() -> void:
	release()
	sample_time += 0.2
	press(Vector2(420, 280))
	move(Vector2(730, 280))

func warning(direction: Vector2, until: float) -> void:
	battle.boss.phase = "windup"
	battle.boss.direction = direction
	battle.boss.resolved = false
	battle.boss.deadline = until

func _run() -> void:
	fresh()
	press(Vector2(576, 280))
	check(battle.boss_hp == 300 and battle.settlement_count == 0, "press inside hurtbox causes no teleport hit")
	move(Vector2(576, 280))
	move(Vector2(577, 280))
	check(battle.settlement_count == 0, "stationary and jitter ignored")
	move(Vector2(578, 280), 0.5)
	check(battle.settlement_count == 0, "slow movement ignored")
	release()
	check(battle.boss_hp == 300, "return to floating rest causes no hit")
	press(Vector2(100, 500))
	move(Vector2(220, 500))
	check(battle.boss_hp == 300 and battle.settlement_count == 0, "empty swing does not start cooldown")
	move(Vector2(730, 280))
	check(battle.boss_hp == 290 and battle.posture == 94, "same hold can hit after empty swing")
	check(battle.last_damage == 10 and battle.last_posture_damage == 6, "HUD reports actual life/posture loss")
	move(Vector2(420, 280))
	move(Vector2(730, 280))
	check(battle.boss_hp == 290 and battle.settlement_count == 1, "cooldown prevents rapid repeated settlements")
	check(battle.player_weapon.tip == Vector2(730, 280), "cooldown does not stop blade following")
	check(battle.player_view.position == Vector2(576, 578), "body fixed")
	slash()
	check(battle.boss_hp == 280, "release allows next hit")
	fresh()
	press(Vector2(420, 280))
	move(Vector2(730, 280), 0.01)
	check(battle.boss_hp == 290, "fast crossing hits with both tips outside target")
	fresh()
	press(Vector2(730, 280))
	move(Vector2(420, 280), 0.01)
	check(battle.boss_hp == 290, "reverse fast crossing hits")
	fresh()
	# Tip stays outside the body; the trailing blade shaft reaches it.
	press(Vector2(660, 280))
	move(Vector2(690, 280))
	check(battle.boss_hp == 290, "actual blade shaft can hit without tip entering target")
	fresh()
	warning(Vector2.DOWN, sample_time + 0.5)
	slash()
	check(battle.boss_hp == 290 and battle.posture == 94, "windup ordinary hit damages life and posture")
	check(battle.boss.phase == "windup" and not battle.boss.resolved, "ordinary hit does not interrupt attack")
	check(battle.boss.step(battle.boss.deadline) == "hit", "uninterrupted boss attack still impacts")
	check(battle.boss.step(battle.boss.deadline - 0.1) != "hit", "boss attack impacts once")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]:
		fresh()
		warning(direction, sample_time + 0.15)
		press(Vector2(576, 280))
		move(Vector2(576, 280) - direction * 70)
		check(battle.parry_count == 1 and battle.posture == 70, "parry direction " + str(direction))
		check(battle.boss_hp == 300 and battle.player_hp == 100, "parry takes priority over overlapping ordinary hit")
		check(battle.boss.step(sample_time + 0.2) != "hit", "parry cancels attack")
		move(Vector2(730, 280))
		check(battle.settlement_count == 1, "parry cooldown rejects immediate extra hit")
	fresh()
	warning(Vector2.DOWN, sample_time + 0.5)
	press(Vector2(200, 550))
	move(Vector2(200, 480))
	check(battle.parry_count == 0 and battle.settlement_count == 0, "early empty motion not stored or consumed")
	sample_time += 0.5
	check(battle.boss.step(battle.boss.deadline) == "hit", "early motion alone does not parry at deadline")
	fresh()
	warning(Vector2.DOWN, sample_time + 0.12)
	press(Vector2(200, 400))
	move(Vector2(200, 480))
	check(battle.parry_count == 0, "wrong direction outside hurtbox fails")
	fresh()
	warning(Vector2.DOWN, sample_time - 0.01)
	press(Vector2(200, 500))
	move(Vector2(200, 420))
	check(battle.parry_count == 0, "late motion cannot rewind impact")
	fresh()
	warning(Vector2.DOWN, sample_time + 0.25)
	press(Vector2(200, 500))
	move(Vector2(200, 499), 0.051)
	check(battle.parry_count == 0, "old fragment not carried into window")
	move(Vector2(200, 430))
	check(battle.parry_count == 1, "new local window fragment parries")
	fresh()
	press(Vector2(200, 500))
	move(Vector2(700, 500))
	sample_time += 0.12
	move(Vector2(700, 500))
	warning(Vector2.DOWN, sample_time + 0.15)
	move(Vector2(700, 420))
	check(battle.parry_count == 1, "curve turn uses current local fragment")
	for shape in [
		[Vector2(350, 440), Vector2(400, 400), Vector2(450, 440), Vector2(400, 480), Vector2(350, 440)],
		[Vector2(350, 400), Vector2(450, 420), Vector2(350, 460), Vector2(450, 500)],
		[Vector2(300, 400), Vector2(500, 450), Vector2(320, 470), Vector2(450, 360)]]:
		fresh()
		battle.mode = 1
		press(shape[0])
		for index in range(1, shape.size()):
			move(shape[index])
			check(battle.player_weapon.tip == shape[index], "curve tip follows every sample")
		check(battle.player_weapon.trail_line.points == battle.player_weapon.trail, "Line2D receives complete ordered curve")
		check(battle.boss_hp == 300, "free drawing never damages boss")
	fresh()
	battle.mode = 3
	battle.boss.attacks_enabled = false
	check(battle.boss.step(sample_time + 100) == "", "dummy never starts attacks")
	battle.posture = 6
	warning(Vector2.DOWN, sample_time + 1.0)
	slash()
	check(battle.boss_hp == 290 and battle.posture == 0 and battle.last_damage == 10, "breaking hit uses original damage multiplier")
	check(battle.boss.phase == "broken" and battle.boss.resolved, "zero posture interrupts once")
	var broken_deadline: float = battle.boss.deadline
	slash()
	check(battle.boss_hp == 270 and battle.last_damage == 20, "subsequent hit uses vulnerable multiplier")
	check(battle.posture == 0 and battle.last_posture_damage == 0, "posture stays zero while vulnerable")
	check(battle.boss.deadline == broken_deadline, "vulnerable hit does not refresh duration")
	slash()
	check(battle.boss_hp == 250 and battle.boss.deadline == broken_deadline, "repeated vulnerable hit cannot re-enter or extend")
	battle.boss.deadline = battle.now() - 0.01
	battle._process(0.016)
	check(battle.posture == 100 and battle.boss.phase == "idle", "vulnerability expiration restores full posture")
	slash()
	check(battle.boss_hp == 240 and battle.last_damage == 10, "normal damage restored after vulnerability")
	fresh()
	battle.boss.phase = "broken"
	battle.posture = 0
	battle.boss.deadline = sample_time + 0.1
	slash()
	check(battle.last_damage == 10 and battle.posture == 94 and battle.boss.phase == "idle", "input after expiry restores posture and normal multiplier before next frame")
	fresh()
	slash()
	release()
	press(Vector2(420, 280))
	move(Vector2(730, 280))
	check(battle.boss_hp == 290 and battle.settlement_count == 1, "release cannot bypass minimum action interval")
	_continuous_hold_checks()
	fresh()
	battle.boss_hp = 10
	battle.posture = 6
	slash()
	check(battle.result.begins_with("胜利") and battle.boss.phase == "ended", "death takes priority over simultaneous zero posture")
	check(not battle.gesture.enabled, "victory disables input")
	fresh()
	press(Vector2(500, 500))
	battle.toggle_pause()
	check(not battle.gesture.held and battle.player_weapon.trail.is_empty(), "pause clears gesture")
	battle.toggle_pause()
	check(not battle.gesture.held, "resume needs new press")
	press(Vector2(500, 500))
	battle._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(battle.paused and not battle.gesture.held, "focus loss pauses and clears")
	battle.restart()
	check(battle.player_hp == 100 and battle.boss_hp == 300 and battle.posture == 100 and battle.boss.phase == "idle" and not battle.gesture.held and not battle.paused and battle.last_damage == 0, "restart fully resets combat and damage readout")
	for fps in [30, 60, 120]:
		fresh()
		warning(Vector2.DOWN, sample_time + 0.2)
		var impact: float = battle.boss.deadline
		sample_time = impact - 1.0 / fps - 0.04
		press(Vector2(200, 500))
		move(Vector2(200, 420))
		check(battle.parry_count == 1, "parry boundary at %d FPS interval" % fps)
	fresh()
	warning(Vector2.DOWN, sample_time + 0.04)
	press(Vector2(200, 500))
	move(Vector2(200, 420))
	check(battle.parry_count == 1, "exact impact boundary accepts input first")
	fresh()
	battle.player_hp = 20
	warning(Vector2.DOWN, battle.now() - 0.01)
	battle._process(1.0 / 60)
	check(battle.result.begins_with("失败") and battle.player_hp == 0, "defeat ends battle")

func enable_preview() -> void:
	fresh()
	battle.mode = 3
	var texture := GradientTexture2D.new()
	texture.width = 110
	texture.height = 10
	texture.gradient = Gradient.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ COLOR = vec4(1.0, 0.2, 0.8, 0.9); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	battle.player_weapon.trail_material = material
	battle.player_weapon.trail_texture = texture
	battle.player_weapon.trail_width = 18.0
	battle.player_weapon.trail_color = Color.MAGENTA
	battle.player_weapon.blade_texture = texture
	battle.player_weapon.texture_tip = Vector2(110, 5)
	battle.player_weapon.apply_appearance()
	battle.player_view.head_texture = texture
	battle.boss_view.actor_visual_scene = null
	battle.boss_view.body_texture = texture
	battle.player_view.apply_appearance()
	battle.boss_view.apply_appearance()
	press(Vector2(300, 440))
	move(Vector2(400, 410))
	move(Vector2(480, 480))
	battle._refresh_hud()
	battle.queue_redraw()

func restore_preview() -> void:
	battle.player_weapon.trail_material = null
	battle.player_weapon.trail_texture = null
	battle.player_weapon.trail_width = 3.0
	battle.player_weapon.trail_color = Color(0.46, 0.91, 0.93, 0.38)
	battle.player_weapon.blade_texture = null
	battle.player_weapon.blade_visual_scene = null
	battle.player_weapon.visual_scale = Vector2.ONE
	battle.player_weapon.apply_appearance()
	for actor in [battle.player_view, battle.boss_view]:
		actor.head_texture = null
		actor.body_texture = null
		actor.actor_visual_scene = original_boss_visual if actor == battle.boss_view else null
		actor.apply_appearance()
	fresh()
	battle.mode = 3
	battle.boss.attacks_enabled = false
	battle._refresh_hud()

func _art_checks() -> void:
	enable_preview()
	check(battle.player_weapon.trail_line.material == battle.player_weapon.trail_material, "shader resource actually bound to Line2D")
	check(battle.player_weapon.trail_line.texture != null and battle.player_weapon.trail_line.width == 18, "trail texture and width actually bound")
	check(battle.player_weapon.visual.get_child_count() == 1, "blade texture produces actual sprite")
	var sprite: Sprite2D = battle.player_weapon.visual.get_child(0)
	check(sprite.position + battle.player_weapon.texture_tip == Vector2.ZERO, "texture tip is aligned to pivot origin")
	check(battle.player_weapon.tip_marker.global_position.is_equal_approx(battle.player_weapon.tip), "actual Tip marker follows gameplay tip with texture")
	check(battle.player_view.visual_root.get_node_or_null("Head") != null and battle.boss_view.visual_root.get_node_or_null("Body") != null, "head and body textures actually instantiate")
	var original_hurtbox: Rect2 = battle.boss_hurtbox()
	slash()
	check(battle.boss_hp == 290 and battle.posture == 94, "temporary shader and texture preserve damage")
	check(battle.boss_hurtbox() == original_hurtbox, "visual replacement preserves hurtbox")
	release()
	sample_time += 0.2
	battle.player_weapon.trail_width = 100.0
	battle.player_weapon.apply_appearance()
	press(Vector2(420, 440))
	move(Vector2(730, 440))
	check(battle.boss_hp == 290 and battle.settlement_count == 1, "huge visual trail width cannot expand gameplay collision")
	# Pack a small native shape as a replacement scene, then restore it in memory.
	var art := Node2D.new()
	var triangle := Polygon2D.new()
	triangle.polygon = PackedVector2Array([Vector2.ZERO, Vector2(-110, -12), Vector2(-110, 12)])
	art.add_child(triangle)
	triangle.owner = art
	var packed := PackedScene.new()
	packed.pack(art)
	art.free()
	battle.player_weapon.blade_visual_scene = packed
	battle.player_weapon.visual_scale = Vector2(1.5, 1.5)
	battle.player_weapon.apply_appearance()
	check(battle.player_weapon.visual.get_child(0).get_child(0) is Polygon2D, "replacement blade scene actually instantiated")
	check(battle.player_weapon.tip_marker.global_position.is_equal_approx(battle.player_weapon.tip), "scaling art cannot shift gameplay Tip")
	battle.player_view.actor_visual_scene = packed
	battle.player_view.apply_appearance()
	check(battle.player_view.visual_root.get_child(0).get_child(0) is Polygon2D, "replacement actor scene actually instantiated")
	for actor in [battle.player_view, battle.boss_view]:
		for socket_name in ["LeftShoulder", "RightShoulder"]:
			var socket: Node = actor.get_node(socket_name)
			actor.remove_child(socket)
			socket.free()
		actor.apply_appearance()
	restore_preview()
	slash()
	check(battle.boss_hp == 290 and battle.player_weapon.tip == Vector2(730, 280), "absent optional arms do not affect floating blade or combat")
	check(battle.player_weapon.trail_line.material == null and battle.player_weapon.blade_texture == null and battle.player_view.actor_visual_scene == null, "temporary appearance restored to placeholders")

func _continuous_hold_checks() -> void:
	fresh()
	press(Vector2(560, 280))
	move(Vector2(590, 280))
	for x in [610, 630, 650, 670, 690]:
		move(Vector2(x, 280))
	check(battle.gesture.held and battle.boss_hp == 280 and battle.settlement_count == 2, "one uninterrupted hold produces repeated hits after cooldown")
	move(Vector2(690, 280), 0.25)
	move(Vector2(690, 280))
	check(battle.boss_hp == 280, "stationary blade on boss cannot repeat damage after cooldown")
	warning(Vector2.DOWN, sample_time + 0.15)
	move(Vector2(690, 200))
	check(battle.parry_count == 1 and battle.gesture.held, "ordinary hit can be followed by parry without release")
	fresh()
	warning(Vector2.DOWN, sample_time + 0.15)
	press(Vector2(200, 500))
	move(Vector2(200, 420))
	move(Vector2(200, 420), 0.25)
	move(Vector2(200, 340))
	check(battle.parry_count == 1 and battle.posture == 70, "same cancelled boss attack cannot be parried twice")
	move(Vector2(200, 340), 0.05)
	warning(Vector2.RIGHT, sample_time + 0.15)
	move(Vector2(120, 340))
	check(battle.parry_count == 2 and battle.posture == 40 and battle.gesture.held, "consecutive boss attacks can be parried in one hold")
	move(Vector2(120, 340), 0.25)
	move(Vector2(420, 280))
	move(Vector2(730, 280))
	check(battle.boss_hp == 290 and battle.gesture.held, "parry can be followed by ordinary hit without release")
	fresh()
	press(Vector2(560, 280))
	move(Vector2(590, 280))
	battle._settle_motion(sample_time + 0.3)
	check(battle.settlement_count == 1, "old motion cannot be replayed when cooldown ends")
	battle.restart()
	move(Vector2(730, 280))
	check(battle.settlement_count == 0 and not battle.gesture.held, "restart cancels an ongoing continuous hold")

func _tuning_percent_checks() -> void:
	fresh()
	battle.tuning.minimum_distance_ratio = 1.0
	warning(Vector2.DOWN, sample_time + 0.15)
	press(Vector2(200, 500))
	move(Vector2(200, 420))
	check(battle.parry_count == 0, "reproduce 100-percent distance threshold rejecting a clear short parry")
	battle.tuning.set("最小挥刀距离（短边百分比）", 2.0)
	check(is_equal_approx(battle.tuning.minimum_distance_ratio, 0.02), "Inspector value two percent stores ratio 0.02")
	fresh()
	warning(Vector2.DOWN, sample_time + 0.15)
	press(Vector2(200, 500))
	move(Vector2(200, 420))
	check(battle.parry_count == 1, "same short motion parries after correcting percentage")
	battle.tuning.set("最小挥刀距离（短边百分比）", 1.0)
	check(is_equal_approx(battle.tuning.minimum_distance_ratio, 0.01), "Inspector one now means one percent rather than 100 percent")
	battle.tuning.minimum_distance_ratio = 0.02
