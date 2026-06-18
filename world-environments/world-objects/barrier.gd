extends StaticBody3D

signal destroyed
signal repaired
signal state_changed(state_index: int)

@export var max_health := 100
@export var health_bar_look_range := 12.0
@export var repaired_state_count := 4
# Optional model variants. Index 0 is destroyed; index repaired_state_count is fully repaired.
@export var visual_state_nodes: Array[NodePath] = []

var health: float = max_health
var is_depleted := false
var current_state_index := -1
var player: Node3D
var player_camera: Camera3D
var health_bar_sprite: Sprite3D
var health_progress_bar: ProgressBar
var health_label: Label

@onready var health_bar_anchor: Node3D = %HealthBarAnchor
@onready var blocking_collision_shape: CollisionShape3D = %CSGBakedCollisionShape3D

func _ready() -> void:
	add_to_group("barriers")
	cache_player_camera()

	create_health_bar()
	update_health_bar()
	update_barrier_state(true)

func _process(_delta: float) -> void:
	if not player_camera:
		cache_player_camera()

	if not health_bar_sprite or not player_camera:
		return

	health_bar_sprite.visible = is_player_looking_at_barrier()

	if health_bar_sprite.visible:
		health_bar_sprite.look_at(player_camera.global_position, Vector3.UP)
		health_bar_sprite.rotate_y(PI)

func cache_player_camera() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player_camera = player.get_node_or_null("Camera3D") as Camera3D

func is_blocking() -> bool:
	return health > 0

func take_barrier_damage(amount: int) -> void:
	health = max(health - amount, 0.0)

	print("Barrier HP:", int(ceil(health)))

	if health <= 0 and not is_depleted:
		is_depleted = true
		destroyed.emit()

	update_health_bar()
	update_barrier_state()

func repair(amount: float) -> void:
	var previous_health := health
	health = min(health + amount, max_health)

	if health > previous_health:
		if is_depleted and health > 0:
			is_depleted = false
			repaired.emit()

		print("Barrier repaired HP:", int(ceil(health)))
		update_health_bar()
		update_barrier_state()

func update_barrier_state(force_emit := false) -> void:
	var next_state_index := get_state_index_for_health()
	if next_state_index == current_state_index and not force_emit:
		return

	current_state_index = next_state_index
	blocking_collision_shape.disabled = current_state_index == 0
	update_visual_state()
	state_changed.emit(current_state_index)
	print("Barrier state:", current_state_index)

func get_state_index_for_health() -> int:
	if health <= 0:
		return 0

	var state_count = max(repaired_state_count, 1)
	var health_percent := health / float(max_health)
	return clamp(ceili(health_percent * state_count), 1, state_count)

func update_visual_state() -> void:
	if visual_state_nodes.is_empty():
		return

	for i in visual_state_nodes.size():
		var node := get_node_or_null(visual_state_nodes[i]) as Node3D
		if node:
			node.visible = i == current_state_index

func create_health_bar() -> void:
	var viewport := SubViewport.new()
	viewport.name = "HealthBarViewport"
	viewport.size = Vector2i(620, 96)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	health_bar_anchor.add_child(viewport)

	var container := HBoxContainer.new()
	container.name = "HealthBarContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 24)
	viewport.add_child(container)

	health_progress_bar = ProgressBar.new()
	health_progress_bar.name = "HealthBar"
	health_progress_bar.custom_minimum_size = Vector2(420, 20)
	health_progress_bar.max_value = max_health
	health_progress_bar.rounded = true
	health_progress_bar.show_percentage = false
	health_progress_bar.add_theme_stylebox_override("background", create_bar_style(Color.BLACK, 8.0))
	health_progress_bar.add_theme_stylebox_override("fill", create_bar_style(Color(0.12, 0.78, 0.28, 1.0), 0.0))
	container.add_child(health_progress_bar)

	health_label = Label.new()
	health_label.name = "HPLabel"
	health_label.label_settings = create_label_settings()
	container.add_child(health_label)

	health_bar_sprite = Sprite3D.new()
	health_bar_sprite.name = "HealthBarSprite"
	health_bar_sprite.texture = viewport.get_texture()
	health_bar_sprite.pixel_size = 0.003
	health_bar_sprite.visible = false
	health_bar_anchor.add_child(health_bar_sprite)

func create_bar_style(color: Color, expand_margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.corner_radius_bottom_left = 1
	style.expand_margin_left = expand_margin
	style.expand_margin_top = expand_margin
	style.expand_margin_right = expand_margin
	style.expand_margin_bottom = expand_margin
	return style

func create_label_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = 28
	settings.outline_size = 5
	settings.outline_color = Color.BLACK
	return settings

func update_health_bar() -> void:
	if not health_progress_bar or not health_label:
		return

	health_progress_bar.max_value = max_health
	health_progress_bar.value = clamp(health, 0.0, max_health)
	health_label.text = str(int(ceil(health_progress_bar.value))) + " HP"

func is_player_looking_at_barrier() -> bool:
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = viewport_size * 0.5
	var origin = player_camera.project_ray_origin(screen_center)
	var direction = player_camera.project_ray_normal(screen_center)
	var query = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * health_bar_look_range
	)

	query.exclude = [player]
	query.collide_with_areas = true

	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return false

	return find_barrier(result.collider) == self

func find_barrier(node: Node) -> Node:
	while node:
		if node.is_in_group("barriers"):
			return node
		node = node.get_parent()

	return null
