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
