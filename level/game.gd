extends Node3D

const DEFAULT_GAMEPLAY_SETTINGS = preload("res://gameplay/default_gameplay_settings.tres")

@export var gameplay_settings: Resource

@onready var label: Label = %Label
@onready var hud: CanvasLayer = %HUD
@onready var player: CharacterBody3D = $Player
@onready var mob_spawner: Node3D = $MobSpawner

var player_score = 0

func _ready() -> void:
	ensure_gameplay_settings()
	apply_gameplay_settings()
	connect_existing_mobs()
	label.visible = false
	hud.start_game_requested.connect(start_game)
	hud.resume_game_requested.connect(resume_game)
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
	print("Zombies fragged:", player_score)

func ensure_gameplay_settings() -> void:
	if gameplay_settings == null:
		gameplay_settings = DEFAULT_GAMEPLAY_SETTINGS

func apply_gameplay_settings() -> void:
	if hud.has_method("set_max_hp"):
		hud.set_max_hp(gameplay_settings.player_max_health)

	if player.has_method("set_gameplay_settings"):
		player.set_gameplay_settings(gameplay_settings)

	if mob_spawner.has_method("set_gameplay_settings"):
		mob_spawner.set_gameplay_settings(gameplay_settings)

func connect_existing_mobs() -> void:
	for mob in get_tree().get_nodes_in_group("damageable"):
		if mob.has_method("set_gameplay_settings"):
			mob.set_gameplay_settings(gameplay_settings)
		connect_mob_score(mob)

func connect_mob_score(mob: Node) -> void:
	if not mob.has_signal("died"):
		return

	var callback := Callable(self, "increase_score")
	if not mob.is_connected("died", callback):
		mob.connect("died", callback)

func show_main_menu() -> void:
	get_tree().paused = true
	hud.show_main_menu()

func start_game() -> void:
	get_tree().paused = false
	hud.hide_main_menu()
	hud.hide_pause_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func pause_game() -> void:
	if get_tree().paused:
		return

	get_tree().paused = true
	hud.show_pause_menu()

func resume_game() -> void:
	get_tree().paused = false
	hud.hide_pause_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func retry_game() -> void:
	get_tree().set_meta("start_immediately", true)
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_mob_spawner_mob_spawned(mob: Node) -> void:
	connect_mob_score(mob)

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

func _on_player_pause_requested() -> void:
	pause_game()

func _on_player_died() -> void:
	hud.game_over(player_score)
	get_tree().paused = true
