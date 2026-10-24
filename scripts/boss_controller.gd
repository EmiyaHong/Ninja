extends Node

var phase := "idle"
var deadline := 0.0
var attack_id := 0
var resolved := true
var interrupted := false
var direction := Vector2.DOWN
var attack_index := -1
var fixed_down := false
var random_attacks := false
var attacks_enabled := true
var can_start_attack := true
var tuning: Resource

func reset(at: float) -> void:
	phase = "idle"
	deadline = at + tuning.idle_duration
	attack_id = 0
	attack_index = -1
	resolved = true
	interrupted = false
	direction = Vector2.DOWN

func step(at: float) -> String:
	if at < deadline:
		return ""
	match phase:
		"idle":
			if not attacks_enabled or not can_start_attack:
				return ""
			attack_index = (attack_index + 1) % 3
			var index := randi_range(0, 2) if random_attacks else attack_index
			direction = Vector2.DOWN if fixed_down else [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN][index]
			attack_id += 1
			resolved = false
			interrupted = false
			phase = "windup"
			deadline = at + tuning.windup * (1.5 if fixed_down else 1.0)
			return "warning"
		"windup":
			resolved = true
			phase = "recovery"
			deadline = at + tuning.recovery
			return "hit"
		"recovery":
			phase = "idle"
			deadline = at + tuning.idle_duration
		"broken":
			phase = "idle"
			deadline = at + tuning.idle_duration
			return "restore"
	return ""

func interrupt(at: float, broken: bool) -> void:
	resolved = true
	interrupted = true
	phase = "broken" if broken else "recovery"
	deadline = at + (tuning.broken_duration if broken else tuning.recovery)
