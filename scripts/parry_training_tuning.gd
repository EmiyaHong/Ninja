extends Resource

# Independent A/B experiment settings. Never read the formal combat resource.
@export_group("共同训练参数（两模式完全一致）")
@export_range(0.02, 0.5, 0.01) var parry_window := 0.20
@export_range(1.0, 80.0, 1.0) var direction_tolerance_degrees := 35.0
@export_range(0.005, 0.1, 0.005) var minimum_distance_ratio := 0.02
@export var minimum_speed := 180.0
@export var local_window := 0.08
@export_group("三刀时间表（秒）")
@export var first_impact_delay := 1.20
@export var impact_interval := 1.0
@export var windup := 0.8
@export var group_rest := 2.0
@export_group("新挥动资格")
@export var pause_to_rearm := 0.12
@export var turn_angle_degrees := 60.0
@export var turn_distance_ratio := 0.01
