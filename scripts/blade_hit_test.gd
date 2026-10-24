extends RefCounted

# Conservative continuous sweep of endpoints between consecutive input samples.
# Collision width is gameplay data, independent of the Line2D and shader.
static func swept_hits(segment: Dictionary, length: float, width: float, target: Rect2) -> bool:
	if segment.is_empty() or segment.from.is_equal_approx(segment.to):
		return false
	var previous_tip: Vector2 = segment.from
	var current_tip: Vector2 = segment.to
	var previous_base: Vector2 = previous_tip - segment.old_direction * length
	var current_base: Vector2 = current_tip - segment.direction * length
	var expanded := target.grow(width * 0.5)
	var corners := PackedVector2Array([expanded.position, Vector2(expanded.end.x, expanded.position.y), expanded.end, Vector2(expanded.position.x, expanded.end.y)])
	var points := PackedVector2Array([previous_tip, previous_base, current_tip, current_base])
	# Also handles a straight swept blade whose convex hull is degenerate.
	for point in points:
		if expanded.has_point(point):
			return true
	for start in points:
		for finish in points:
			for index in range(4):
				if Geometry2D.segment_intersects_segment(start, finish, corners[index], corners[(index + 1) % 4]) != null:
					return true
	var hull := Geometry2D.convex_hull(points)
	return hull.size() >= 4 and not Geometry2D.intersect_polygons(hull, corners).is_empty()

## Returns true if the rectangle `rect` intersects or lies inside the circle (`center`, `radius`).
static func rect_overlaps_circle(rect: Rect2, center: Vector2, radius: float) -> bool:
	var closest := center.clamp(rect.position, rect.end)
	return center.distance_squared_to(closest) <= radius * radius

## Clamps a point into the circle (`center`, `radius`).
static func _clamp_to_circle(point: Vector2, center: Vector2, radius: float) -> Vector2:
	var offset := point - center
	if offset.length_squared() <= radius * radius:
		return point
	return center + offset.normalized() * radius

## Strictly enforces `radius` around `center` as the maximum attackable range:
## 1) target rect must overlap the circle, and
## 2) the blade sweep endpoints (both tips and bases) are clamped inside the circle
##    so an outward-extending blade shaft cannot hit a target outside `radius`.
static func swept_hits_in_circle(segment: Dictionary, length: float, width: float, target: Rect2, center: Vector2, radius: float) -> bool:
	if segment.is_empty() or segment.from.is_equal_approx(segment.to):
		return false
	if not rect_overlaps_circle(target, center, radius):
		return false
	var previous_tip := _clamp_to_circle(segment.from, center, radius)
	var current_tip := _clamp_to_circle(segment.to, center, radius)
	var previous_base := _clamp_to_circle(previous_tip - segment.old_direction * length, center, radius)
	var current_base := _clamp_to_circle(current_tip - segment.direction * length, center, radius)
	var expanded := target.grow(width * 0.5)
	var corners := PackedVector2Array([expanded.position, Vector2(expanded.end.x, expanded.position.y), expanded.end, Vector2(expanded.position.x, expanded.end.y)])
	var points := PackedVector2Array([previous_tip, previous_base, current_tip, current_base])
	for point in points:
		if expanded.has_point(point):
			return true
	for start in points:
		for finish in points:
			for index in range(4):
				if Geometry2D.segment_intersects_segment(start, finish, corners[index], corners[(index + 1) % 4]) != null:
					return true
	var hull := Geometry2D.convex_hull(points)
	return hull.size() >= 4 and not Geometry2D.intersect_polygons(hull, corners).is_empty()

