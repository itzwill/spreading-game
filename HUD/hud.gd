extends CanvasLayer

@onready var ammo_display: Control = %AmmoDisplay
@onready var health_bar: ProgressBar = %HealthBar
@onready var hp_label: Label = %HPLabel
@onready var hitmarker: TextureRect = %Hitmarker
@onready var hitmarker_timer: Timer = %HitmarkerTimer
@onready var game_hud: CanvasLayer = %GameHud
@onready var game_over_menu: CanvasLayer = %GameOverMenu

func set_ammo(current: int, reserve_ammo: int) -> void:
	ammo_display.set_ammo(current, reserve_ammo)

func set_hp(current: int) -> void:
	health_bar.value = current
	hp_label.text = str(current) + " HP"

func show_hitmarker() -> void:
	hitmarker.visible = true
	hitmarker_timer.start()

func game_over() -> void:
	game_over_menu.visible = true
	game_hud.visible = false

func _on_hitmarker_timer_timeout() -> void:
	hitmarker.visible = false

func _on_button_retry_pressed() -> void:
	get_tree().reload_current_scene()
