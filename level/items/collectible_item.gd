extends Area3D

@export_enum("health", "shotgun_ammo") var reward_type := "health"
@export var amount := 25
@export var spin_speed := 1.5
@export var bob_height := 0.08
@export var bob_speed := 2.0

@onready var visual_root: Node3D = %VisualRoot

var base_visual_position := Vector3.ZERO
var bob_time := 0.0
var collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	base_visual_position = visual_root.position

func _process(delta: float) -> void:
	bob_time += delta * bob_speed
	visual_root.rotation.y += delta * spin_speed
	visual_root.position = base_visual_position + Vector3.UP * sin(bob_time) * bob_height

func _on_body_entered(body: Node3D) -> void:
	if collected or not body.is_in_group("player"):
		return

	if not apply_reward(body):
		return

	collected = true
	queue_free()

func apply_reward(player: Node) -> bool:
	match reward_type:
		"health":
			if player.has_method("add_health"):
				return player.add_health(amount)
		"shotgun_ammo":
			if player.has_method("add_reserve_ammo"):
				return player.add_reserve_ammo(amount)

	return false
