extends Node3D

@onready var label: Label = %Label
@onready var hud: CanvasLayer = %HUD

var player_score = 0

func _ready() -> void:
	label.visible = false
	hud.start_game_requested.connect(start_game)
	hud.retry_requested.connect(retry_game)
	hud.main_menu_requested.connect(return_to_main_menu)
	hud.set_score(player_score)

	if get_tree().has_meta("start_immediately"):
		get_tree().remove_meta("start_immediately")
		start_game()
	else:
		show_main_menu()

func increase_score() -> void:
	player_score += 1
	hud.set_score(player_score)

func show_main_menu() -> void:
	get_tree().paused = true
	hud.show_main_menu()

func start_game() -> void:
	get_tree().paused = false
	hud.hide_main_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func retry_game() -> void:
	get_tree().set_meta("start_immediately", true)
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

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
	hud.game_over(player_score)
	get_tree().paused = true
