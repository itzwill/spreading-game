extends Node3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func shoot():
	animation_player.play("fire")
