extends Node
var b: Node
var at := 10.0
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func fresh() -> void:
	b._switch_mode(4)
	b.set_process(false)
	b.boss.attacks_enabled = false
	b.gesture.clock = func() -> float: return at
	at += 2.0
func press(p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	b.gesture._input(e)
func move(p: Vector2) -> void:
	at += 0.02
	var e := InputEventMouseMotion.new()
	e.position = p
	b.gesture._input(e)
func stroke(p: Vector2, d: Vector2) -> void:
	press(p)
	move(p + d * 10)
	move(p + d * 30)
func _ready() -> void:
	b = preload("res://scenes/battle.tscn").instantiate()
	add_child(b)
	var saved: Resource = b.tuning
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2(1,-1).normalized()]:
		fresh()
		stroke(Vector2(100,550), d)
		check(b.directional.active, "remote stroke launches")
		check(b.boss_hp == 300, "no immediate damage")
		check(b.directional.direction.dot(d) > 0.99, "continuous direction")
		var start: Vector2 = b.player_weapon.tip
		b.directional.step(at + 0.04)
		check((b.player_weapon.tip-start).dot(d) > 0, "visible displacement")
		b.directional.step(at + 0.18)
		check(b.boss_hp == 290, "physical strike damage")
		b.directional.step(at + 0.4)
		check(b.boss_hp == 290 and not b.directional.active, "single hit and safe return")
	fresh()
	stroke(Vector2(100,550), Vector2.RIGHT)
	b.directional.step(at + 0.3)
	for i in range(6): move(Vector2(140+i*20,550))
	check(not b.directional.active, "straight hold cannot spam")
	move(Vector2(220,550)); move(Vector2(190,550)); move(Vector2(170,550))
	check(b.directional.active, "held reversal rearms")
	fresh()
	stroke(Vector2(100,550), Vector2.RIGHT)
	b.boss.phase = "windup"; b.boss.resolved = false
	b.boss.direction = Vector2.RIGHT; b.boss.deadline = at + 0.15
	move(Vector2(110,550)); move(Vector2(90,550)); move(Vector2(70,550))
	check(b.parry_count == 1 and b.directional.defensive, "fresh parry cancels active normal")
	b.directional.step(at+0.3)
	check(b.boss_hp == 300 and b.posture == 70, "cancelled damage never returns")
	fresh()
	b.posture = 6
	stroke(Vector2(100,550), Vector2.RIGHT)
	b.directional.step(at+0.18)
	check(b.boss.phase == "broken", "break posture")
	b.directional.step(at+0.3)
	b.directional.launch(Vector2.LEFT, at+0.4, false)
	b.directional.step(at+0.58)
	check(b.last_damage == 20, "vulnerability multiplier")
	b.boss_hp = 1
	b.directional.launch(Vector2.UP, at+0.6, false)
	b.directional.step(at+0.78)
	check(not b.result.is_empty() and not b.directional.active, "victory clears action")
	fresh()
	b.player_hp = 1; b.boss.phase = "windup"; b.boss.deadline = b.now()-0.1
	b._process(0.01)
	check(b.player_hp == 0 and not b.result.is_empty(), "defeat")
	fresh(); stroke(Vector2(100,550), Vector2.RIGHT)
	b.toggle_pause()
	check(not b.directional.active and not b.gesture.held, "pause cleanup")
	b._switch_mode(0)
	check(b.tuning == saved and b.gesture.direct_control, "restore old tuning and control")
	print("DIRECTIONAL_TESTS: %d checks, %d failures: %s" % [checks, failures.size(), failures])
	get_tree().quit(0 if failures.is_empty() else 1)
