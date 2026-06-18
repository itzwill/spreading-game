extends RigidBody3D

signal died

@onready var zombie_model: Node3D = %ZombieModel
@onready var animation_tree: AnimationTree = %ZombieModel/AnimationTree
@onready var player: CharacterBody3D = get_node("/root/Game/Player")
@onready var timer: Timer = %Timer
@onready var hurt_sound: AudioStreamPlayer3D = %HurtSound
@onready var death_sound: AudioStreamPlayer3D = %DeathSound

const SPEED = 2.5
const MAX_SPEED = 5

const MAX_HEALTH := 100
var health := MAX_HEALTH

func _ready():
	add_to_group("damageable")

func _physics_process(delta: float) -> void:
	var direction = global_position.direction_to(player.global_position)
	direction.y = 0.0
	linear_velocity = SPEED * direction
	zombie_model.rotation.y = Vector3.BACK.signed_angle_to(direction, Vector3.UP)
	
	var horizontal_speed = Vector2(linear_velocity.x, linear_velocity.z).length()
	var blend_value = clamp(horizontal_speed / MAX_SPEED, 0.0, 1.0)
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
