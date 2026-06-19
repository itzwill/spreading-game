extends Area3D

signal hit(body: Node3D)

const SPEED := 150.0
const RANGE := 40.0

var direction := Vector3.ZERO
var travelled_distance := 0.0

func _physics_process(delta: float) -> void:
	var movement := direction * SPEED * delta

	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + movement
	)

	query.exclude = [self]
	query.collision_mask = 1

	var result := get_world_3d().direct_space_state.intersect_ray(query)

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
