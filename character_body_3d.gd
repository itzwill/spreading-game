extends CharacterBody3D

@onready var navigation_agent: NavigationAgent3D = %NavigationAgent3D
@onready var player: CharacterBody3D = get_node("/root/Game/Player")

const SPEED = 2.5
const MAX_SPEED = 5

func _physics_process(delta: float) -> void:
	var direction = global_position.direction_to(player.global_position)
	direction.y = 0.0
	velocity = SPEED * direction
	var next_path_position: Vector3 = navigation_agent.get_next_path_position()
	var new_velocity: Vector3 = global_position.direction_to(next_path_position) * SPEED
	if navigation_agent.avoidance_enabled:
		navigation_agent.set_velocity(new_velocity)
	else:
		_on_velocity_computed(new_velocity)

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()



func _on_timer_timeout() -> void:
	set_target_to_player()
	
func set_target_to_player():
	navigation_agent.set_target_position(to_local(player.global_position))
	
