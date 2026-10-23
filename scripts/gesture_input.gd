extends Node

signal moved(at: float)
signal began
signal ended

var direct_control := true
var held := false
var enabled := true
var samples: Array[Dictionary] = []
var weapon: Node2D
var clock: Callable
var rest := Vector2(660, 565)
var blade_direction := Vector2.UP
var motion_segment: Dictionary = {}

func reset(fade_trail: bool = false) -> void:
	held = false
	samples.clear()
	motion_segment.clear()
	blade_direction = Vector2.UP
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
			samples.append({"p": point, "t": clock.call()})
			if direct_control: weapon.follow(point, Vector2.ZERO, true)
			began.emit() # Initial placement is deliberately never a motion event.
		else:
			reset(true)
			ended.emit()
	elif event is InputEventMouseMotion and held:
		var point := _clamp_point(event.position)
		var previous: Vector2 = samples.back().p
		var at: float = clock.call()
		var direction := (point - previous).normalized()
		motion_segment = {"from": previous, "to": point, "from_time": samples.back().t, "old_direction": blade_direction, "direction": direction}
		if not direction.is_zero_approx():
			blade_direction = direction
		samples.append({"p": point, "t": at})
		if direct_control: weapon.follow(point, direction, true)
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

func _clamp_point(point: Vector2) -> Vector2:
	return point.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)
