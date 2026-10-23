extends Node2D

# Presentation only: no health, collision, timers, or damage callbacks here.
var phase := "idle"
var direction := Vector2.RIGHT
var active_right := false
var active_left := false
var hit_amount := 0.0
var visual_clock := 0.0
var previous_attack := ""
var trails_r: Array[Dictionary] = []
var trails_l: Array[Dictionary] = []
var striking := false
var feedback_strength := 0.0
@onready var torso: Node2D = $Rig/Torso
@onready var head: Node2D = $Rig/Torso/Head
@onready var arm_r: Node2D = $Rig/Torso/UpperArmR
@onready var arm_l: Node2D = $Rig/Torso/UpperArmL
@onready var forearm_r: Node2D = $Rig/Torso/UpperArmR/Forearm
@onready var forearm_l: Node2D = $Rig/Torso/UpperArmL/Forearm
@onready var claw_r: Node2D = $Rig/Torso/UpperArmR/Forearm/Claw
@onready var claw_l: Node2D = $Rig/Torso/UpperArmL/Forearm/Claw
@onready var tip_r: Marker2D = $Rig/Torso/UpperArmR/Forearm/Claw/StrikeTip
@onready var tip_l: Marker2D = $Rig/Torso/UpperArmL/Forearm/Claw/StrikeTip

func reset_visual() -> void:
	trails_r.clear()
	trails_l.clear()
	previous_attack = ""
	phase = "idle"
	_pose(Vector3.ZERO, Vector3.ZERO, 0.0, 0.0)
	queue_redraw()

func animate(state: String, incoming: Vector2, remaining: float, duration: float, strike_duration: float, at: float, attack_key: String) -> void:
	phase = state
	direction = incoming
	visual_clock = at
	active_right = incoming == Vector2.RIGHT or incoming == Vector2.DOWN
	active_left = incoming == Vector2.LEFT or incoming == Vector2.DOWN
	if previous_attack != attack_key:
		trails_r.clear()
		trails_l.clear()
		previous_attack = attack_key
	var right := Vector3.ZERO
	var left := Vector3.ZERO
	var lean := 0.0
	var slouch := 0.0
	striking = false
	feedback_strength = 0.0
	var charge := Vector3(60, -25, -20)
	var impact := Vector3(-65, 10, 10)
	if incoming == Vector2.DOWN:
		charge = Vector3(90, 90, 0)
		impact = Vector3(-15, -15, 15)
	var progress := clampf(1.0 - remaining / maxf(duration, 0.001), 0, 1)
	if state == "windup":
		var swing_time := clampf(strike_duration, 0.02, maxf(0.02, duration * 0.4))
		var charge_progress := clampf((duration - remaining) / maxf(0.001, duration - swing_time), 0, 1)
		var pose := Vector3.ZERO.lerp(charge, smoothstep(0, 0.75, charge_progress))
		if remaining <= swing_time:
			striking = true
			pose = charge.lerp(impact, smoothstep(0, 1, 1 - remaining / swing_time))
		if active_right: right = pose
		if active_left: left = -pose
		lean = (-3 if incoming == Vector2.RIGHT else 3) * charge_progress if incoming != Vector2.DOWN else 0
	elif state == "recovery":
		var recovery := smoothstep(0.12, 1.0, progress)
		if active_right: right = impact.lerp(Vector3.ZERO, recovery)
		if active_left: left = -impact.lerp(Vector3.ZERO, recovery)
	elif state == "parried":
		var recoil := Vector3(35, -45, -40) if incoming != Vector2.DOWN else Vector3(65, 65, -20)
		if active_right: right = recoil.lerp(Vector3.ZERO, smoothstep(0.15, 1, progress))
		if active_left: left = -recoil.lerp(Vector3.ZERO, smoothstep(0.15, 1, progress))
		lean = 5 * sin(progress * PI)
		feedback_strength = 1 - progress
	elif state == "broken" or state == "ended":
		right = Vector3(-12, -12, 15)
		left = -right
		lean = 4 if state == "broken" else 12
		slouch = 42 if state == "broken" else 72
	else:
		var breathing := sin(at * 2.4)
		right = Vector3(breathing * 1.2, 0, 0)
		left = Vector3(-breathing * 1.2, 0, 0)
		slouch = breathing * 2.0
	_pose(right, left, lean, slouch)
	head.rotation += hit_amount * 0.45
	modulate = Color(0.82, 0.75, 1.0) if state == "broken" else Color.WHITE
	if striking:
		if active_right: _record(trails_r, tip_r)
		if active_left: _record(trails_l, tip_l)
	for trail in [trails_r, trails_l]:
		while not trail.is_empty() and at - float(trail.front().t) > 0.14:
			trail.pop_front()
	queue_redraw()

func _pose(right: Vector3, left: Vector3, lean: float, slouch: float) -> void:
	torso.position = Vector2(0, -574 + slouch)
	torso.rotation = deg_to_rad(lean)
	head.rotation = deg_to_rad(-lean * 0.7 + slouch * 0.2)
	arm_r.rotation = deg_to_rad(right.x)
	forearm_r.rotation = deg_to_rad(right.y)
	claw_r.rotation = deg_to_rad(right.z)
	arm_l.rotation = deg_to_rad(left.x)
	forearm_l.rotation = deg_to_rad(left.y)
	claw_l.rotation = deg_to_rad(left.z)

func _record(trail: Array[Dictionary], marker: Marker2D) -> void:
	var point := to_local(marker.global_position)
	if trail.is_empty() or point.distance_squared_to(trail.back().p) > 1.0:
		trail.append({"p": point, "t": visual_clock})

func _draw() -> void:
	for trail in [trails_r, trails_l]:
		for index in range(1, trail.size()):
			var alpha := clampf(1.0 - (visual_clock - float(trail[index].t)) / 0.14, 0, 1)
			draw_line(trail[index - 1].p, trail[index].p, Color(1, 0.81, 0.46, alpha * 0.6), 7.0, true)
	if feedback_strength > 0.1:
		for marker in [tip_r, tip_l]:
			if (marker == tip_r and not active_right) or (marker == tip_l and not active_left):
				continue
			var point := to_local(marker.global_position)
			for index in range(8):
				var ray := Vector2.RIGHT.rotated(index * TAU / 8)
				draw_line(point + ray * 6, point + ray * (6 + feedback_strength * 20), Color(1, 0.88, 0.5, feedback_strength), 2.5, true)
