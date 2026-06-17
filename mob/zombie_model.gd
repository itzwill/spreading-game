extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	#print(state_machine)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

@onready var animation_tree: AnimationTree = %AnimationTree
@onready var animation_player: AnimationPlayer = %AnimationPlayer

func hurt():
	animation_tree.set("parameters/TakeDamageOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func attack():
	animation_tree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
func die():
	animation_tree.active = false
	animation_player.play("Death")
