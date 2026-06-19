extends Node3D

@export var ground_probe_height := 12.0
@export var ground_probe_depth := 40.0

func get_random_ground_position(attempts: int) -> Variant:
	var points := get_polygon_points()
	if points.size() < 3:
		return null

	var bounds := get_bounds(points)

	for i in attempts:
		var point := Vector2(
			randf_range(bounds.position.x, bounds.end.x),
			randf_range(bounds.position.y, bounds.end.y)
		)

		if not is_point_in_polygon(point, points):
			continue

		var probe_origin := Vector3(point.x, global_position.y + ground_probe_height, point.y)
		var query := PhysicsRayQueryParameters3D.create(
			probe_origin,
			probe_origin + Vector3.DOWN * ground_probe_depth
		)
		query.collision_mask = 1

		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if result:
			return result.position

	return null

func get_polygon_points() -> Array[Vector2]:
	var points: Array[Vector2] = []

	for child in get_children():
		if child is Marker3D:
			points.append(Vector2(child.global_position.x, child.global_position.z))

	return points

func get_bounds(points: Array[Vector2]) -> Rect2:
	var min_point := points[0]
	var max_point := points[0]

	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)

	return Rect2(min_point, max_point - min_point)

func is_point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	var inside := false
	var j := polygon.size() - 1

	for i in polygon.size():
		var current := polygon[i]
		var previous := polygon[j]
		var intersects := (
			(current.y > point.y) != (previous.y > point.y)
			and point.x < (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
		)

		if intersects:
			inside = not inside

		j = i

	return inside
