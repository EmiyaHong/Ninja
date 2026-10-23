extends SceneTree

const WEAPON = preload("res://scenes/player_weapon.tscn")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var weapon := WEAPON.instantiate()
	root.add_child(weapon)
	var line: Line2D = weapon.trail_line
	line.set_process(false)
	weapon.follow(Vector2(100, 300), Vector2.RIGHT, true)
	line._process(0.08)
	weapon.follow(Vector2(220, 300), Vector2.RIGHT, true)
	line._process(0.08)
	weapon.follow(Vector2(340, 300), Vector2.RIGHT, true)
	check(line.points == weapon.trail, "Complete unsmoothed input must remain available")
	var samples: PackedVector4Array = line._visual_samples()
	check(samples[0].z < samples[samples.size() - 1].z, "Old segments retain their own age during a continuous hold")
	var oldest_time: float = line._recent[0].z
	weapon.follow(Vector2(360, 320), Vector2(1, 1), true)
	check(is_equal_approx(line._recent[0].z, oldest_time), "New movement cannot refresh old segment timestamps")
	check(not line.visible and line._surface.visible, "Only one surface draws; original Line2D must not double-blend")
	var count: int = line._recent.size()
	weapon.follow(Vector2(360, 320), Vector2.ZERO, true)
	check(line._recent.size() == count, "Stationary samples cannot refresh the trail")
	line._process(0.3)
	check(line._recent.is_empty() and not line._surface.visible, "All stationary trail segments must expire")
	weapon.follow(Vector2(370, 320), Vector2.RIGHT, true)
	weapon.follow(Vector2(390, 320), Vector2.RIGHT, true)
	check(line._recent.size() == 2, "Resuming after a pause cannot resurrect earlier segments")
	weapon.clear(Vector2(660, 565), true)
	check(weapon.trail.is_empty() and line.points.is_empty(), "Release immediately clears gameplay samples")
	check(line._surface.visible, "Release retains the same surface for natural fading")
	line._process(0.3)
	check(not line._surface.visible, "Released trail disappears after its lifetime")
	weapon.follow(Vector2(100, 300), Vector2.RIGHT, true)
	weapon.follow(Vector2(500, 300), Vector2.RIGHT, true)
	weapon.clear(Vector2.ZERO)
	check(line._recent.is_empty() and not line._surface.visible, "Restart clears visual history immediately")
	weapon.trail_width = 64.0
	weapon.apply_appearance()
	check(is_equal_approx(line.material.get_shader_parameter("trail_width"), 64.0), "Inspector width reaches the shader")
	for index in range(1000):
		weapon.follow(Vector2(index, 300 + sin(index * 0.1) * 20), Vector2.RIGHT, true)
	check(line._recent.size() <= 256 and line._visual_samples().size() <= 64, "Continuous input has bounded visual cost")
	check(line.points == weapon.trail, "Visual pruning cannot discard original gameplay input")
	var second := WEAPON.instantiate()
	root.add_child(second)
	check(second.trail_material != weapon.trail_material, "Each weapon owns its shader uniforms")
	weapon.trail_material = null
	weapon.apply_appearance()
	check(line.visible and not line._surface.visible, "Custom/absent shader keeps ordinary Line2D rendering")
	print("BLADE_TRAIL_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
