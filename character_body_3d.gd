extends CharacterBody3D

signal died

const DEFAULT_GAMEPLAY_SETTINGS = preload("res://gameplay/default_gameplay_settings.tres")

@export var gameplay_settings: Resource

@onready var navigation_agent: NavigationAgent3D = %NavigationAgent3D
@onready var player: CharacterBody3D = get_node("/root/Game/Player")
@onready var zombie_model: Node3D = %ZombieModel
@onready var animation_tree: AnimationTree = %ZombieModel/AnimationTree
@onready var despawn_timer: Timer = %DespawnTimer
@onready var hurt_sound: AudioStreamPlayer3D = %HurtSound
@onready var death_sound: AudioStreamPlayer3D = %DeathSound
@onready var attack_timer: Timer = %AttackTimer
@onready var forward_ray: RayCast3D = %ForwardRay

var health := 100
var move_direction := Vector3.FORWARD

func _ready() -> void:
	ensure_gameplay_settings()
	health = gameplay_settings.zombie_max_health
	add_to_group("damageable")

func ensure_gameplay_settings() -> void:
	if gameplay_settings == null:
		gameplay_settings = DEFAULT_GAMEPLAY_SETTINGS

func set_gameplay_settings(settings: Resource) -> void:
	gameplay_settings = settings if settings else DEFAULT_GAMEPLAY_SETTINGS
	health = gameplay_settings.zombie_max_health

func _physics_process(_delta: float) -> void:

	if can_attack_player():
		attack_player()
		move_and_slide()
		return

	var next_path_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	direction.y = 0.0
	direction = direction.normalized()
	if direction:
		move_direction = direction

	if can_attack_barrier():
		attack_barrier()
		move_and_slide()
		return

	var new_velocity = direction * gameplay_settings.zombie_move_speed
	zombie_model.rotation.y = Vector3.BACK.signed_angle_to(direction, Vector3.UP)
	
	var horizontal_speed = Vector2(new_velocity.x, new_velocity.z).length()
	var blend_value = clamp(horizontal_speed / gameplay_settings.zombie_animation_max_speed, 0.0, 1.0)
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

func set_target_to_player() -> void:
	navigation_agent.target_position = player.global_position

func can_attack_player() -> bool:
	return global_position.distance_to(
		player.global_position
	) <= gameplay_settings.zombie_attack_range

func attack_player() -> void:
	velocity = Vector3.ZERO

	if not attack_timer.is_stopped():
		return

	player.take_damage(gameplay_settings.zombie_player_damage)
	animate_attack()

	attack_timer.start()

func can_attack_barrier() -> bool:
	var barrier = get_facing_barrier()
	if barrier:
		if barrier.has_method("is_blocking"):
			return barrier.is_blocking()

		return true

	return false

func get_facing_barrier() -> Node:
	var origin := global_position + Vector3.UP * 0.65
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + move_direction * gameplay_settings.zombie_attack_range
	)

	query.exclude = [self]
	query.collision_mask = 1

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return null

	return find_barrier(result.collider)
	
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

	var barrier = get_facing_barrier()

	if barrier:
		barrier.take_barrier_damage(gameplay_settings.zombie_barrier_damage)
		animate_attack()

	attack_timer.start()


func take_damage(
	hit_location: String,
	distance: float
) -> void:
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

	var damage: float = gameplay_settings.shotgun_base_damage

	match hit_location:
		"head":
			damage *= gameplay_settings.shotgun_headshot_multiplier

		"body":
			damage *= gameplay_settings.shotgun_body_multiplier

	# Shotgun damage falloff
	var distance_factor = clamp(
		distance / gameplay_settings.shotgun_falloff_distance,
		0.0,
		1.0
	)

	damage *= lerpf(
		1.0,
		gameplay_settings.shotgun_min_falloff_multiplier,
		distance_factor
	)

	var randomness: float = gameplay_settings.shotgun_damage_randomness
	damage *= randf_range(1.0 - randomness, 1.0 + randomness)

	return roundi(damage)

func animate_attack() -> void:
	zombie_model.attack()
	
func die() -> void:
	death_sound.play()
	set_physics_process(false)
	zombie_model.die()
	despawn_timer.start()
	died.emit()

func _on_despawn_timer_timeout() -> void:
	queue_free()
