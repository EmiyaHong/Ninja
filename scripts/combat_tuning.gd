@tool
extends Resource

# Keep the stored keys stable so existing resources and combat code keep working.
@export_storage var player_health: float = 100.0
@export_storage var boss_health: float = 300.0
@export_storage var boss_posture: float = 100.0
@export_storage var normal_damage: float = 10.0
@export_storage var normal_posture: float = 6.0
@export_storage var parry_posture: float = 30.0
@export_storage var boss_damage: float = 20.0
@export_storage var broken_multiplier: float = 2.0
@export_storage var broken_duration: float = 2.0
@export_storage var windup: float = 0.9
@export_storage var parry_window: float = 0.2
@export_storage var recovery: float = 0.8
@export_storage var idle_duration: float = 0.8
@export_storage var local_window: float = 0.08
@export_storage var minimum_distance_ratio: float = 0.02
@export_storage var minimum_speed: float = 180.0
@export_storage var action_interval: float = 0.18
@export_storage var direction_tolerance_degrees: float = 35.0

const INSPECTOR_NAMES := {
	"玩家生命上限": "player_health",
	"Boss生命上限": "boss_health",
	"Boss架势上限": "boss_posture",
	"普通攻击生命伤害": "normal_damage",
	"普通攻击架势削减": "normal_posture",
	"弹反架势削减": "parry_posture",
	"Boss攻击生命伤害": "boss_damage",
	"易伤伤害倍率": "broken_multiplier",
	"易伤持续时间（秒）": "broken_duration",
	"Boss蓄力时间（秒）": "windup",
	"弹反时间窗口（秒）": "parry_window",
	"Boss收招时间（秒）": "recovery",
	"Boss等待时间（秒）": "idle_duration",
	"局部轨迹观测时间（秒）": "local_window",
	"最小挥刀距离（短边百分比）": "minimum_distance_ratio",
	"最低挥刀速度（像素每秒）": "minimum_speed",
	"最短出刀间隔（秒）": "action_interval",
	"弹反方向容差（度）": "direction_tolerance_degrees",
}

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	for label in INSPECTOR_NAMES:
		var entry := {"name": label, "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_EDITOR}
		if INSPECTOR_NAMES[label] == "minimum_distance_ratio":
			entry["hint"] = PROPERTY_HINT_RANGE
			entry["hint_string"] = "0.1,100,0.1"
		properties.append(entry)
	return properties

func _get(property: StringName) -> Variant:
	if INSPECTOR_NAMES.has(String(property)):
		if INSPECTOR_NAMES[String(property)] == "minimum_distance_ratio":
			return minimum_distance_ratio * 100.0
		return get(INSPECTOR_NAMES[String(property)])
	return null

func _set(property: StringName, value: Variant) -> bool:
	if not INSPECTOR_NAMES.has(String(property)):
		return false
	var stored_value := float(value)
	if INSPECTOR_NAMES[String(property)] == "minimum_distance_ratio":
		stored_value /= 100.0
	set(INSPECTOR_NAMES[String(property)], stored_value)
	emit_changed()
	return true
