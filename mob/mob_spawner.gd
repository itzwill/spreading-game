extends Node3D

@export var mob_to_spawn: PackedScene = null

signal mob_spawned(mob)

@onready var marker_3d: Marker3D = %Marker3D
@onready var timer: Timer = %Timer

func _on_timer_timeout() -> void:
	var new_mob: Node3D = mob_to_spawn.instantiate()
	add_child(new_mob)
	new_mob.global_position = marker_3d.global_position
	mob_spawned.emit(new_mob)
