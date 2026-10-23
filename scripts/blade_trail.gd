extends Line2D
## Complete input points stay on Line2D; only the recent visual path is shaded.
## One surface merges overlapping segments without stacking their opacity.

const TRAIL_SHADER = preload("res://shaders/blade_trail.gdshader")
const MAX_SAMPLES := 64

@export_range(0.05, 1.0) var fade_seconds := 0.22
@export_range(40.0, 800.0) var visible_length := 320.0

var _clock := 0.0
var _stroke_length := 0.0
var _previous_point := Vector2.ZERO
var _has_point := false
var _recent: Array[Vector4] = []
var _surface: Polygon2D

func _uses_trail_shader() -> bool:
	return material is ShaderMaterial and material.shader == TRAIL_SHADER

func sync_appearance() -> void:
	var use_surface := _uses_trail_shader()
	visible = not use_surface
	if use_surface and not is_instance_valid(_surface):
		_surface = Polygon2D.new()
		_surface.name = "BladeTrailSurface"
		get_parent().add_child(_surface)
	if is_instance_valid(_surface):
		_surface.visible = use_surface and _recent.size() > 1
		_surface.material = material
		_surface.color = default_color
		_surface.z_index = z_index
		_surface.transform = transform
	if use_surface:
		material.set_shader_parameter("trail_width", width)
		material.set_shader_parameter("fade_seconds", fade_seconds)
		material.set_shader_parameter("visible_length", visible_length)

func record_point(point: Vector2) -> void:
	var distance := point.distance_to(_previous_point) if _has_point else 0.0
	if _has_point and distance <= 0.01:
		return # Stationary input must never refresh an old sample's lifetime.
	_stroke_length += distance
	_previous_point = point
	_has_point = true
	_prune()
	_recent.append(Vector4(point.x, point.y, _clock, _stroke_length))
	# Bound visual storage even with unusually high mouse polling rates.
	if _recent.size() > 256:
		_recent.pop_front()
	_update_surface()

func _process(delta: float) -> void:
	_clock += delta
	_prune()
	_update_surface()

func _prune() -> void:
	while _recent.size() > 1:
		var next := _recent[1]
		if _clock - next.z < fade_seconds and _stroke_length - next.w < visible_length:
			break
		_recent.pop_front()
	if _recent.size() == 1 and _clock - _recent[0].z >= fade_seconds:
		_recent.clear()

func _visual_samples() -> PackedVector4Array:
	var result := PackedVector4Array()
	if _recent.size() < 2:
		return result
	# Round input joins for presentation; preserve both endpoints.
	# Combat continues to use the original unsmoothed input.
	var smooth: Array[Vector4] = [_recent[0]]
	for index in range(_recent.size() - 1):
		smooth.append(_recent[index].lerp(_recent[index + 1], 0.25))
		smooth.append(_recent[index].lerp(_recent[index + 1], 0.75))
	smooth.append(_recent.back())
	var start := smooth[0].w
	var span: float = smooth.back().w - start
	var count := clampi(int(ceil(span / 4.0)) + 1, 2, MAX_SAMPLES)
	var cursor := 0
	for index in range(count):
		var target := start + span * float(index) / float(count - 1)
		while cursor + 1 < smooth.size() - 1 and smooth[cursor + 1].w < target:
			cursor += 1
		var a := smooth[cursor]
		var b := smooth[cursor + 1]
		result.append(a.lerp(b, clampf((target - a.w) / maxf(b.w - a.w, 0.001), 0.0, 1.0)))
	return result

func _update_surface() -> void:
	sync_appearance()
	if not _uses_trail_shader():
		return
	material.set_shader_parameter("clock_seconds", _clock)
	material.set_shader_parameter("stroke_distance", _stroke_length)
	var samples := _visual_samples()
	material.set_shader_parameter("sample_count", samples.size())
	if samples.size() < 2:
		_surface.hide()
		return
	var bounds := Rect2(Vector2(samples[0].x, samples[0].y), Vector2.ZERO)
	for sample in samples:
		bounds = bounds.expand(Vector2(sample.x, sample.y))
	bounds = bounds.grow(width * 0.5 + 2.0)
	_surface.polygon = PackedVector2Array([bounds.position,
		Vector2(bounds.end.x, bounds.position.y), bounds.end,
		Vector2(bounds.position.x, bounds.end.y)])
	samples.resize(MAX_SAMPLES)
	material.set_shader_parameter("samples", samples)

func reset_trail(leave_afterimage: bool = false) -> void:
	# Released samples retain their timestamps and disappear naturally.
	# No extra Line2D copies blend over a new stroke.
	if not leave_afterimage:
		_recent.clear()
		_stroke_length = 0.0
	_has_point = false
	_update_surface()
