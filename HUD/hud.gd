extends CanvasLayer

signal start_game_requested
signal retry_requested
signal main_menu_requested

const INPUT_PROMPTS := {
	"repair": {
		"label": "Repair",
		"key_text": "E",
		"texture": preload("res://HUD/inputs/keyboard_e.png"),
	},
	"reload": {
		"label": "Reload",
		"key_text": "R",
		"texture": preload("res://HUD/inputs/keyboard_r.png"),
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
var menu_overlay: Control
var game_over_overlay: Control
var game_over_score_label: Label
var score_value_label: Label
var score_pulse_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_menu.visible = false
	build_score_counter()
	build_main_menu()
	build_game_over_menu()

func set_ammo(current: int, reserve_ammo: int) -> void:
	ammo_display.set_ammo(current, reserve_ammo)

func set_hp(current: int) -> void:
	health_bar.value = current
	hp_label.text = str(current) + " HP"

func show_hitmarker() -> void:
	hitmarker.visible = true
	hitmarker_timer.start()

func set_score(score: int) -> void:
	if not score_value_label:
		return

	score_value_label.text = str(score)
	pulse_score()

func pulse_score() -> void:
	if score_pulse_tween:
		score_pulse_tween.kill()

	score_value_label.scale = Vector2.ONE
	score_pulse_tween = create_tween()
	score_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	score_pulse_tween.tween_property(score_value_label, "scale", Vector2(1.22, 1.22), 0.08)
	score_pulse_tween.tween_property(score_value_label, "scale", Vector2.ONE, 0.1)

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

func show_main_menu() -> void:
	menu_overlay.visible = true
	game_over_overlay.visible = false
	game_hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_main_menu() -> void:
	menu_overlay.visible = false
	game_hud.visible = true

func game_over(score: int) -> void:
	game_over_score_label.text = str(score)
	game_over_overlay.visible = true
	game_over_menu.visible = false
	game_hud.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_hitmarker_timer_timeout() -> void:
	hitmarker.visible = false

func _on_input_prompt_timer_timeout() -> void:
	temporary_prompt_id = ""
	refresh_input_prompt()

func _on_button_retry_pressed() -> void:
	retry_requested.emit()

func build_score_counter() -> void:
	var container := VBoxContainer.new()
	container.name = "ScoreCounter"
	container.anchor_left = 1.0
	container.anchor_right = 1.0
	container.offset_left = -280.0
	container.offset_top = 24.0
	container.offset_right = -24.0
	container.offset_bottom = 120.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	game_hud.add_child(container)

	var title := Label.new()
	title.text = "Zombies Fragged"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.label_settings = make_label_settings(20, 4)
	container.add_child(title)

	score_value_label = Label.new()
	score_value_label.text = "0"
	score_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_value_label.pivot_offset = Vector2(24, 24)
	score_value_label.label_settings = make_label_settings(44, 6)
	container.add_child(score_value_label)

func build_main_menu() -> void:
	menu_overlay = make_overlay("MainMenu")
	add_child(menu_overlay)

	var panel := make_menu_panel()
	menu_overlay.add_child(panel)

	var title := Label.new()
	title.text = "Survive the Spread"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.label_settings = make_label_settings(68, 8)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Hold the line. Repair the barricade. Keep moving."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.label_settings = make_label_settings(22, 4)
	panel.add_child(subtitle)

	var guide := VBoxContainer.new()
	guide.add_theme_constant_override("separation", 10)
	panel.add_child(guide)

	add_control_row(guide, "Move", [
		preload("res://HUD/inputs/keyboard_w.png"),
		preload("res://HUD/inputs/keyboard_a.png"),
		preload("res://HUD/inputs/keyboard_s.png"),
	])
	add_text_key_control_row(guide, "Move right", "D")
	add_control_row(guide, "Look", [preload("res://HUD/inputs/mouse_move.png")])
	add_control_row(guide, "Fire", [preload("res://HUD/inputs/mouse_left.png")])
	add_control_row(guide, "Reload", [preload("res://HUD/inputs/keyboard_r.png")])
	add_control_row(guide, "Repair", [preload("res://HUD/inputs/keyboard_e.png")])

	var start_button := make_menu_button("Start Game")
	start_button.pressed.connect(func(): start_game_requested.emit())
	panel.add_child(start_button)

func build_game_over_menu() -> void:
	game_over_overlay = make_overlay("GameOverOverlay")
	game_over_overlay.visible = false
	add_child(game_over_overlay)

	var panel := make_menu_panel()
	game_over_overlay.add_child(panel)

	var title := Label.new()
	title.text = "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.label_settings = make_label_settings(64, 8)
	panel.add_child(title)

	var caption := Label.new()
	caption.text = "Zombies Fragged"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.label_settings = make_label_settings(24, 4)
	panel.add_child(caption)

	var score := Label.new()
	score.name = "GameOverScore"
	score.text = "0"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.label_settings = make_label_settings(56, 7)
	panel.add_child(score)
	game_over_score_label = score

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	panel.add_child(buttons)

	var retry_button := make_menu_button("Retry")
	retry_button.pressed.connect(func(): retry_requested.emit())
	buttons.add_child(retry_button)

	var menu_button := make_menu_button("Main Menu")
	menu_button.pressed.connect(func(): main_menu_requested.emit())
	buttons.add_child(menu_button)

func make_overlay(node_name: String) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color(0.005, 0.008, 0.012, 0.86)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)

	return overlay

func make_menu_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360.0
	panel.offset_top = -300.0
	panel.offset_right = 360.0
	panel.offset_bottom = 300.0
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 24)
	return panel

func add_control_row(parent: VBoxContainer, label_text: String, icons: Array) -> void:
	var row := make_control_row(label_text)
	var icon_box := row.get_node("Icons") as HBoxContainer

	for texture in icons:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(46, 46)
		icon.texture = texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_box.add_child(icon)

	parent.add_child(row)

func add_text_key_control_row(parent: VBoxContainer, label_text: String, key_text: String) -> void:
	var row := make_control_row(label_text)
	var icon_box := row.get_node("Icons") as HBoxContainer
	var key := Label.new()
	key.custom_minimum_size = Vector2(46, 46)
	key.text = key_text
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.label_settings = make_label_settings(22, 4)
	icon_box.add_child(key)
	parent.add_child(row)

func make_control_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)

	var icons := HBoxContainer.new()
	icons.name = "Icons"
	icons.custom_minimum_size = Vector2(190, 48)
	icons.alignment = BoxContainer.ALIGNMENT_END
	icons.add_theme_constant_override("separation", 6)
	row.add_child(icons)

	var label := Label.new()
	label.custom_minimum_size = Vector2(220, 48)
	label.text = label_text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.label_settings = make_label_settings(24, 4)
	row.add_child(label)
	return row

func make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220, 56)
	button.text = text
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_stylebox_override("normal", make_button_style(Color(0.12, 0.16, 0.2, 0.95)))
	button.add_theme_stylebox_override("hover", make_button_style(Color(0.2, 0.28, 0.34, 1.0)))
	button.add_theme_stylebox_override("pressed", make_button_style(Color(0.08, 0.11, 0.14, 1.0)))
	return button

func make_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.58, 0.72, 0.78, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func make_label_settings(font_size: int, outline_size: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.outline_size = outline_size
	settings.outline_color = Color.BLACK
	return settings
