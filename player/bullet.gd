extends Area3D

signal hit(body: Node3D)

const SPEED := 150.0
const RANGE := 40.0

var direction := Vector3.ZERO
var travelled_distance := 0.0

func _physics_process(delta: float) -> void:
	var movement := direction * SPEED * delta
	var result := get_first_blocking_hit(global_position + movement)

	if result:
		var body: Node3D = result.collider
		
	
		if body.is_in_group("damageable"):
			var owner_id = body.shape_find_owner(result.shape)
			var shape_node = body.shape_owner_get_owner(owner_id)

			var hit_location = shape_node.get_meta(
				"hit_location",
				"body"
			)
			
			body.take_damage(
				hit_location,
				travelled_distance
			)
			
			hit.emit(body)

		queue_free()
		return

	global_position += movement

	travelled_distance += movement.length()

	if travelled_distance >= RANGE:
		queue_free()

func get_first_blocking_hit(target_position: Vector3) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var cast_from := global_position
	var excluded := [self]

	for i in 8:
		var query := PhysicsRayQueryParameters3D.create(cast_from, target_position)
		query.exclude = excluded
		query.collision_mask = 1

		var result := space_state.intersect_ray(query)
		if result.is_empty():
			return {}

		if find_barrier(result.collider):
			excluded.append(result.collider)
			cast_from = result.position + direction * 0.01
			continue

		travelled_distance += global_position.distance_to(result.position)
		return result

	return {}

func find_barrier(node: Node) -> Node:
	while node:
		if node.is_in_group("barriers"):
			return node

		node = node.get_parent()

	return null
