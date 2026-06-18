extends Node3D

@onready var label: Label = %Label
@onready var hud: CanvasLayer = %HUD

var player_score = 0

func increase_score() -> void:
	player_score += 1
	label.text = "Score: " + str(player_score)

func _on_mob_spawner_mob_spawned(mob: RigidBody3D) -> void:
	mob.died.connect(increase_score)

func _on_player_update_ammo(gun_ammo: int, reserve_ammo: int) -> void:
	hud.set_ammo(gun_ammo, reserve_ammo)

func _on_player_update_health(hp: int) -> void:
	hud.set_hp(hp)

func _on_player_hit_confirmed() -> void:
	hud.show_hitmarker()

func _on_player_input_prompt_changed(prompt_id: String, visible: bool) -> void:
	hud.set_input_prompt(prompt_id, visible)

func _on_player_temporary_input_prompt_requested(prompt_id: String) -> void:
	hud.show_temporary_input_prompt(prompt_id)

func _on_player_died() -> void:
	hud.game_over()
