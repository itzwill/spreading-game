extends Node3D

@onready var animation_tree: AnimationTree = %AnimationTree
@onready var animation_player: AnimationPlayer = %AnimationPlayer

func hurt():
	animation_tree.set("parameters/TakeDamageOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func attack():
	animation_tree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
func die():
	animation_tree.active = false
	animation_player.play("Death")
