extends Node

signal moved(at: float)
signal began
signal ended

var direct_control := true
var held := false
var enabled := true
# Gesture samples stay in screen space ("p"): parry/swing direction, distance and
# speed describe the mouse gesture itself, so camera scrolling or body walking
# cannot add to a stroke. With the default camera, screen == world as before.
var samples: Array[Dictionary] = []
var weapon: Node2D
var clock: Callable
var rest := Vector2(660, 565)
var blade_direction := Vector2.UP
var motion_segment: Dictionary = {}
# Optional world-space limit for the visible blade tip (D016 sword radius).
var tip_filter: Callable
var last_screen := Vector2.ZERO
var last_tip := Vector2.ZERO

func reset(fade_trail: bool = false) -> void:
	held = false
	samples.clear()
	motion_segment.clear()
	blade_direction = Vector2.UP
	last_tip = rest
	if direct_control and is_instance_valid(weapon):
		weapon.clear(rest, fade_trail)

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			reset()
			held = true
			var point := _clamp_point(event.position)
			last_screen = point
			last_tip = current_tip()
			samples.append({"p": point, "t": clock.call()})
			if direct_control: weapon.follow(last_tip, Vector2.ZERO, true)
			began.emit() # Initial placement is deliberately never a motion event.
		else:
			reset(true)
			ended.emit()
	elif event is InputEventMouseMotion and held:
		var point := _clamp_point(event.position)
		var previous: Vector2 = samples.back().p
		var at: float = clock.call()
		var direction := (point - previous).normalized()
		last_screen = point
		var tip := current_tip()
		# Ordinary hits sweep the visible (possibly radius-limited) blade tip.
		motion_segment = {"from": last_tip, "to": tip, "from_time": samples.back().t, "old_direction": blade_direction, "direction": direction}
		last_tip = tip
		if not direction.is_zero_approx():
			blade_direction = direction
		samples.append({"p": point, "t": at})
		if direct_control: weapon.follow(tip, direction, true)
		# Combat needs only recent samples; the weapon retains the complete visible curve.
		while samples.size() > 2 and float(samples[1].t) < at - 0.12:
			samples.pop_front()
		moved.emit(at)

func local_motion(at: float, window: float, after: float = -INF) -> Dictionary:
	if samples.size() < 2:
		return {}
	var cutoff := maxf(at - window, after)
	var first: Dictionary = samples.back()
	for sample in samples:
		if float(sample.t) >= cutoff:
			first = sample
			break
	var last: Dictionary = samples.back()
	var elapsed := float(last.t) - float(first.t)
	if elapsed <= 0.0001:
		return {}
	var displacement: Vector2 = last.p - first.p
	return {"direction": displacement.normalized(), "distance": displacement.length(), "speed": displacement.length() / elapsed}

## Screen position -> world position through the active camera.
func screen_to_world(point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * point

## World target under the last pointer sample, limited by tip_filter if set.
func current_tip() -> Vector2:
	var world := screen_to_world(last_screen)
	return tip_filter.call(world) if tip_filter.is_valid() else world

## Visual-only follow when the body or camera moves without a mouse event.
## Never emits `moved`, so walking alone cannot settle a hit.
func refresh_tip() -> void:
	if not held or not direct_control or not is_instance_valid(weapon):
		return
	var tip := current_tip()
	if tip.is_equal_approx(last_tip):
		return
	last_tip = tip
	weapon.follow(tip, Vector2.ZERO, true)

## Clamped to the visible screen; the world equivalent is the visible world rect.
func _clamp_point(point: Vector2) -> Vector2:
	return point.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)
