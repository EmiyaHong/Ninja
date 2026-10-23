extends Node

signal knife_settled(index: int, success: bool, reason: String)

const SETTINGS = preload("res://data/parry_training.tres")
var tuning: Resource = SETTINGS.duplicate(true)
var rule := 0 # A: axis in either direction. B: strict opposite direction.
var pattern := 0 # Same direction, or right/left/right.
var session_start := 0.0
var group_start := 0.0
var group_number := 1
var impact_times: Array[float] = []
var results: Array[String] = []
var reasons: Array[String] = []
var previous_group := "尚未完成一组"
var completed_groups := 0
var total_success := 0
var total_failure := 0
var group_recorded := false
var stroke_used := false
var stroke_start := 0.0
var stroke_direction := Vector2.ZERO
var last_moved_at := -INF
var turn_vector := Vector2.ZERO
var turn_start := 0.0
var has_gesture := false

func reset(at: float, selected_rule: int, selected_pattern: int) -> void:
	rule = selected_rule
	pattern = selected_pattern
	session_start = at
	group_number = 1
	completed_groups = 0
	total_success = 0
	total_failure = 0
	previous_group = "尚未完成一组"
	_start_group(at)
	cancel_gesture()

func _start_group(at: float) -> void:
	group_start = at
	impact_times.clear()
	for index in range(3):
		impact_times.append(at + tuning.first_impact_delay + index * tuning.impact_interval)
	results.assign(["等待", "等待", "等待"])
	reasons.assign(["", "", ""])
	group_recorded = false

func cancel_gesture() -> void:
	has_gesture = false
	stroke_used = false
	stroke_direction = Vector2.ZERO
	last_moved_at = -INF
	turn_vector = Vector2.ZERO
	stroke_start = INF

func begin_gesture(at: float) -> void:
	cancel_gesture()
	has_gesture = true
	stroke_start = at
	last_moved_at = at

func direction_for(index: int) -> Vector2:
	return Vector2.LEFT if pattern == 1 and index == 1 else Vector2.RIGHT

func matches(player_direction: Vector2, incoming: Vector2) -> bool:
	var projection := player_direction.dot(incoming)
	var threshold := cos(deg_to_rad(tuning.direction_tolerance_degrees))
	return absf(projection) >= threshold if rule == 0 else -projection >= threshold

func current_index(at: float) -> int:
	for index in range(impact_times.size()):
		if at <= impact_times[index]:
			return index
	return -1

func step(at: float) -> void:
	if impact_times.size() != 3 or at < session_start:
		return
	# Every impact belongs to the original absolute schedule. Results cannot move it.
	while true:
		for index in range(3):
			if at > impact_times[index] and results[index] == "等待":
				_settle(index, false, "错过窗口")
		if at > impact_times[2] and not group_recorded:
			group_recorded = true
			completed_groups += 1
			previous_group = "第 %d 组：%s（%d / 3）" % [group_number, " / ".join(results), results.count("成功")]
		if at <= impact_times[2] + tuning.group_rest:
			break
		var next_start: float = impact_times[2] + tuning.group_rest
		group_number += 1
		_start_group(next_start)

func _observe_stroke(at: float, segment: Dictionary, short_side: float) -> void:
	var displacement: Vector2 = segment.to - segment.from
	if displacement.length() < 0.5:
		return # Jitter does not reset the pause timer or create a turn.
	var direction := displacement.normalized()
	var from_time: float = segment.from_time
	if at - last_moved_at >= tuning.pause_to_rearm:
		stroke_used = false
		stroke_start = from_time
		stroke_direction = direction
		turn_vector = Vector2.ZERO
	elif stroke_direction.is_zero_approx():
		stroke_direction = direction
	elif stroke_direction.dot(direction) <= cos(deg_to_rad(tuning.turn_angle_degrees)):
		if turn_vector.is_zero_approx():
			turn_start = from_time
		turn_vector += displacement
		if turn_vector.length() >= short_side * tuning.turn_distance_ratio:
			stroke_used = false
			stroke_start = turn_start
			stroke_direction = turn_vector.normalized()
			turn_vector = Vector2.ZERO
	else:
		turn_vector = Vector2.ZERO
	last_moved_at = at

func handle_motion(at: float, gesture: Node, short_side: float) -> void:
	if not has_gesture or not gesture.held or at < session_start or gesture.motion_segment.is_empty():
		return
	step(at)
	_observe_stroke(at, gesture.motion_segment, short_side)
	var index := current_index(at)
	if index < 0 or stroke_used or results[index] != "等待":
		return
	var window_start: float = impact_times[index] - tuning.parry_window
	if at < window_start:
		return # Return movements outside a window never spend a future opportunity.
	var motion: Dictionary = gesture.local_motion(at, tuning.local_window, maxf(window_start, stroke_start))
	if motion.is_empty() or motion.distance < short_side * tuning.minimum_distance_ratio or motion.speed < tuning.minimum_speed:
		return
	stroke_used = true
	var success := matches(motion.direction, direction_for(index))
	_settle(index, success, "方向与时机正确" if success else "方向不符合本模式")

func _settle(index: int, success: bool, reason: String) -> void:
	if results[index] != "等待":
		return
	results[index] = "成功" if success else "失败"
	reasons[index] = reason
	if success:
		total_success += 1
	else:
		total_failure += 1
	knife_settled.emit(index, success, reason)
