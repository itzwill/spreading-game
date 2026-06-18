extends CharacterBody3D

signal died

@onready var navigation_agent: NavigationAgent3D = %NavigationAgent3D
@onready var player: CharacterBody3D = get_node("/root/Game/Player")
@onready var zombie_model: Node3D = %ZombieModel
@onready var animation_tree: AnimationTree = %ZombieModel/AnimationTree
@onready var despawn_timer: Timer = %DespawnTimer
@onready var hurt_sound: AudioStreamPlayer3D = %HurtSound
@onready var death_sound: AudioStreamPlayer3D = %DeathSound
@onready var attack_timer: Timer = %AttackTimer
@onready var forward_ray: RayCast3D = %ForwardRay

# Mob Movement Speed
const SPEED = 2.5
const MAX_SPEED = 5

# Mob's Health
const MAX_HEALTH := 100
var health := MAX_HEALTH

# For attacking the player
const ATTACK_RANGE := 1.5
const ATTACK_DAMAGE := 10

func _ready():
	add_to_group("damageable")

func _physics_process(_delta: float) -> void:

	if can_attack_player():
		attack_player()
		move_and_slide()
		return

	if can_attack_barrier():
		attack_barrier()
		move_and_slide()
		return

	#navigation_agent.target_position = player.global_position

	var next_path_position = navigation_agent.get_next_path_position()

	var direction = global_position.direction_to(next_path_position)
	direction.y = 0.0

	var new_velocity = direction * SPEED
	zombie_model.rotation.y = Vector3.BACK.signed_angle_to(direction, Vector3.UP)
	
	var horizontal_speed = Vector2(new_velocity.x, new_velocity.z).length()
	var blend_value = clamp(horizontal_speed / MAX_SPEED, 0.0, 1.0)
	animation_tree.set("parameters/locomotion/blend_position", blend_value)

	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_navigation_agent_3d_velocity_computed(new_velocity)

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()

func _on_navigation_timer_timeout() -> void:
	set_target_to_player()
	
func _on_attack_timer_timeout() -> void:
	pass # Replace with function body.

func set_target_to_player():
	navigation_agent.target_position = player.global_position

func can_attack_player() -> bool:
	return global_position.distance_to(
		player.global_position
	) <= ATTACK_RANGE

func attack_player() -> void:
	velocity = Vector3.ZERO

	if not attack_timer.is_stopped():
		return

	player.take_damage(ATTACK_DAMAGE)
	animate_attack()

	attack_timer.start()

func can_attack_barrier() -> bool:
	if not forward_ray.is_colliding():
		return false

	var collider = forward_ray.get_collider()

	var barrier = find_barrier(collider)
		
	if barrier:
		if barrier.has_method("is_blocking"):
			return barrier.is_blocking()

		return true

	return false
	
func find_barrier(node: Node) -> Node:
	while node:
		if node.is_in_group("barriers"):
			return node

		node = node.get_parent()

	return null
	
func attack_barrier() -> void:
	
	velocity = Vector3.ZERO

	if not attack_timer.is_stopped():
		return

	var barrier = find_barrier(forward_ray.get_collider())

	if barrier:
		barrier.take_barrier_damage(25)
		animate_attack()

	attack_timer.start()


func take_damage(
	hit_location: String,
	distance: float
):
	if health <= 0:
		return

	var damage = calculate_damage(
		hit_location,
		distance
	)

	health -= damage

	print(
		"Hit:",
		hit_location,
		" Distance:",
		round(distance),
		" Damage:",
		damage,
		" Health:",
		health
	)

	if health <= 0:
		die()
	else:
		hurt_sound.play()
		zombie_model.hurt()


func calculate_damage(
	hit_location: String,
	distance: float
) -> int:

	var damage := 20.0

	match hit_location:
		"head":
			damage *= 2.0

		"body":
			damage *= 1.0

	# Shotgun damage falloff
	var distance_factor = clamp(
		distance / 40.0,
		0.0,
		1.0
	)

	damage *= lerpf(
		1.0,
		0.5,
		distance_factor
	)

	# Random ±10%
	damage *= randf_range(0.9, 1.1)

	return roundi(damage)

func animate_attack():
	zombie_model.attack()
	
func die():
	death_sound.play()
	set_physics_process(false)
	zombie_model.die()
	despawn_timer.start()
	died.emit()
	#linear_velocity = Vector3.ZERO

func _on_despawn_timer_timeout() -> void:
	queue_free()
