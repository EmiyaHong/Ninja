extends Node

const SETTINGS = preload("res://data/directional_combat.tres")
const HitTest = preload("res://scripts/blade_hit_test.gd")
var settings: Resource = SETTINGS.duplicate(true)
var battle: Node
var used := false
var stroke := Vector2.ZERO
var turn := Vector2.ZERO
var last_at := -INF
var stroke_at := -INF
var active := false
var start := Vector2.ZERO
var finish := Vector2.ZERO
var direction := Vector2.RIGHT
var started := 0.0
var settled := false
var defensive := false
const DURATION := 0.26
const LENGTH := 440.0
const PAUSE := 0.12

func cancel() -> void:
	active = false
	used = false
	stroke = Vector2.ZERO
	turn = Vector2.ZERO
	last_at = -INF
	stroke_at = -INF
	if is_instance_valid(battle): battle.player_weapon.clear(battle.gesture.rest)

func handle_motion(at: float) -> void:
	var g: Node = battle.gesture
	var segment: Dictionary = g.motion_segment
	if segment.is_empty(): return
	var delta: Vector2 = segment.to - segment.from
	if delta.length() < 0.5: return
	var d := delta.normalized()
	if at - last_at >= PAUSE or stroke.is_zero_approx():
		used = false
		stroke = d
		stroke_at = segment.from_time
		turn = Vector2.ZERO
	elif stroke.dot(d) <= cos(deg_to_rad(65.0)):
		turn += delta
		if turn.length() >= 8.0:
			used = false
			stroke = turn.normalized()
			stroke_at = segment.from_time
			turn = Vector2.ZERO
	else:
		turn = Vector2.ZERO
	last_at = at
	if used: return
	var motion: Dictionary = g.local_motion(at, settings.local_window, stroke_at)
	if not battle._valid_motion(motion): return
	used = true
	var b: Node = battle.boss
	var parry: bool = b.phase == "windup" and not b.resolved and at >= b.deadline - settings.parry_window and at <= b.deadline and stroke_at >= b.deadline - settings.parry_window and motion.direction.dot(-b.direction) >= cos(deg_to_rad(settings.direction_tolerance_degrees))
	# Fresh parry bypasses the running ordinary action; spent strokes never queue.
	if active and not parry: return
	launch(motion.direction, at, parry)
	if parry: battle._resolve_attack(at, true)

func launch(d: Vector2, at: float, parry: bool) -> void:
	direction = d.normalized()
	var center: Vector2 = battle.boss_hurtbox().get_center()
	start = center - direction * LENGTH * 0.5
	finish = center + direction * LENGTH * 0.5
	started = at
	settled = false
	defensive = parry
	active = true
	# Relocation is explicit, invisible to hit testing and starts a fresh trail.
	battle.player_weapon.clear(start)
	battle.player_weapon.follow(start, direction, false)

func step(at: float) -> void:
	if not active: return
	var fraction := clampf((at - started) / DURATION, 0.0, 1.0)
	var old: Vector2 = battle.player_weapon.tip
	var tip := start.lerp(finish, fraction)
	battle.player_weapon.follow(tip, direction, true)
	# The visible blade sweep, rather than gesture time, settles ordinary damage.
	if not defensive and not settled and HitTest.swept_hits({"from": old, "to": tip, "old_direction": direction, "direction": direction}, battle.player_weapon.blade_length, battle.player_weapon.blade_width, battle.boss_hurtbox()):
		settled = true
		battle._resolve_attack(at, false)
	if fraction >= 1.0 and active:
		active = false
		battle.player_weapon.clear(battle.gesture.rest)
