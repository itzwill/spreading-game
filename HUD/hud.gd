extends CanvasLayer

const INPUT_PROMPTS := {
	"repair": {
		"label": "Repair",
		"key_text": "E",
		"texture": preload("res://HUD/inputs/keyboard_e.png"),
	},
	"reload": {
		"label": "Reload",
		"key_text": "R",
		"texture": preload("uid://b6vhtm1g78rhu"),
	},
}

@onready var ammo_display: Control = %AmmoDisplay
@onready var health_bar: ProgressBar = %HealthBar
@onready var hp_label: Label = %HPLabel
@onready var hitmarker: TextureRect = %Hitmarker
@onready var hitmarker_timer: Timer = %HitmarkerTimer
@onready var input_prompt: Control = %InputPrompt
@onready var input_prompt_icon: TextureRect = %InputPromptIcon
@onready var input_prompt_key_label: Label = %InputPromptKeyLabel
@onready var input_prompt_action_label: Label = %InputPromptActionLabel
@onready var input_prompt_timer: Timer = %InputPromptTimer
@onready var game_hud: CanvasLayer = %GameHud
@onready var game_over_menu: CanvasLayer = %GameOverMenu

var persistent_prompt_id := ""
var temporary_prompt_id := ""

func set_ammo(current: int, reserve_ammo: int) -> void:
	ammo_display.set_ammo(current, reserve_ammo)

func set_hp(current: int) -> void:
	health_bar.value = current
	hp_label.text = str(current) + " HP"

func show_hitmarker() -> void:
	hitmarker.visible = true
	hitmarker_timer.start()

func set_input_prompt(prompt_id: String, visible: bool) -> void:
	if visible:
		persistent_prompt_id = prompt_id
	else:
		if persistent_prompt_id == prompt_id:
			persistent_prompt_id = ""

	refresh_input_prompt()

func show_temporary_input_prompt(prompt_id: String, duration := 1.5) -> void:
	temporary_prompt_id = prompt_id
	input_prompt_timer.start(duration)
	refresh_input_prompt()

func refresh_input_prompt() -> void:
	var prompt_id := temporary_prompt_id if temporary_prompt_id else persistent_prompt_id
	if not INPUT_PROMPTS.has(prompt_id):
		input_prompt.visible = false
		return

	var prompt = INPUT_PROMPTS[prompt_id]
	var texture = prompt.texture

	input_prompt_icon.texture = texture
	input_prompt_icon.visible = texture != null
	input_prompt_key_label.visible = texture == null
	input_prompt_key_label.text = prompt.key_text
	input_prompt_action_label.text = prompt.label
	input_prompt.visible = true

func game_over() -> void:
	game_over_menu.visible = true
	game_hud.visible = false

func _on_hitmarker_timer_timeout() -> void:
	hitmarker.visible = false

func _on_input_prompt_timer_timeout() -> void:
	temporary_prompt_id = ""
	refresh_input_prompt()

func _on_button_retry_pressed() -> void:
	get_tree().reload_current_scene()
