extends Node3D

@onready var label: Label = %Label
@onready var hud: CanvasLayer = %HUD

var player_score = 0

func increase_score():
	player_score += 1
	%Label.text = "Score: " + str(player_score)

func _on_mob_spawner_mob_spawned(mob: RigidBody3D) -> void:
	mob.died.connect(increase_score)


#func _on_player_bullet_hit(body: Node3D) -> void:
	##if body.has_method("take_damage"):
		##body.take_damage()
	#pass

func _on_player_update_ammo(gun_ammo: int, reserve_ammo: int) -> void:
	hud.set_ammo(gun_ammo, reserve_ammo)


func _on_player_update_health(hp: int) -> void:
	hud.set_hp(hp)


func _on_player_died() -> void:
	hud.game_over()
