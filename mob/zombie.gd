extends RigidBody3D

signal died

const DEFAULT_GAMEPLAY_SETTINGS = preload("res://gameplay/default_gameplay_settings.tres")

@export var gameplay_settings: Resource

@onready var zombie_model: Node3D = %ZombieModel
@onready var animation_tree: AnimationTree = %ZombieModel/AnimationTree
@onready var player: CharacterBody3D = get_node("/root/Game/Player")
@onready var timer: Timer = %Timer
@onready var hurt_sound: AudioStreamPlayer3D = %HurtSound
@onready var death_sound: AudioStreamPlayer3D = %DeathSound

var health := 100

func _ready():
	ensure_gameplay_settings()
	health = gameplay_settings.zombie_max_health
	add_to_group("damageable")

func ensure_gameplay_settings() -> void:
	if gameplay_settings == null:
		gameplay_settings = DEFAULT_GAMEPLAY_SETTINGS

func set_gameplay_settings(settings: Resource) -> void:
	gameplay_settings = settings if settings else DEFAULT_GAMEPLAY_SETTINGS
	health = gameplay_settings.zombie_max_health

func _physics_process(delta: float) -> void:
	var direction = global_position.direction_to(player.global_position)
	direction.y = 0.0
	linear_velocity = gameplay_settings.zombie_move_speed * direction
	zombie_model.rotation.y = Vector3.BACK.signed_angle_to(direction, Vector3.UP)
	
	var horizontal_speed = Vector2(linear_velocity.x, linear_velocity.z).length()
	var blend_value = clamp(horizontal_speed / gameplay_settings.zombie_animation_max_speed, 0.0, 1.0)
	animation_tree.set("parameters/locomotion/blend_position", blend_value)

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

func attack():
	zombie_model.attack()
	
func die():
	death_sound.play()
	set_physics_process(false)
	zombie_model.die()
	timer.start()
	died.emit()
	linear_velocity = Vector3.ZERO

func _on_timer_timeout() -> void:
	queue_free()
