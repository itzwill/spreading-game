extends StaticBody3D

signal destroyed

@export var max_health := 100

var health := max_health

func _ready() -> void:
	add_to_group("barriers")

func take_barrier_damage(amount: int) -> void:
	health -= amount

	print("Barrier HP:", health)

	if health <= 0:
		destroyed.emit()
		queue_free()

func repair(amount: int) -> void:
	health = min(health + amount, max_health)
