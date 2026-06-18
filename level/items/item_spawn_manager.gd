extends Node3D

@export var health_box_scene: PackedScene
@export var shotgun_ammo_scene: PackedScene
@export var max_health_boxes := 2
@export var max_shotgun_ammo_boxes := 2
@export var min_spawn_interval := 6.0
@export var max_spawn_interval := 12.0
@export var min_spawn_radius := 4.0
@export var max_spawn_radius := 10.0
@export var spawn_attempts := 8
@export var ground_probe_height := 12.0
@export var ground_probe_depth := 40.0

@onready var spawn_timer: Timer = %SpawnTimer

var player: Node3D
var health_boxes: Array[Node] = []
var shotgun_ammo_boxes: Array[Node] = []

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	schedule_next_spawn()

func _on_spawn_timer_timeout() -> void:
	prune_collected_items()
	try_spawn_random_item()
	schedule_next_spawn()

func schedule_next_spawn() -> void:
	spawn_timer.start(randf_range(min_spawn_interval, max_spawn_interval))

func try_spawn_random_item() -> void:
	var spawn_options := []

	if health_boxes.size() < max_health_boxes and health_box_scene:
		spawn_options.append("health")

	if shotgun_ammo_boxes.size() < max_shotgun_ammo_boxes and shotgun_ammo_scene:
		spawn_options.append("shotgun_ammo")

	if spawn_options.is_empty():
		return

	var reward_type = spawn_options.pick_random()
	var item_scene: PackedScene = health_box_scene if reward_type == "health" else shotgun_ammo_scene
	var spawn_position = find_spawn_position()
	if spawn_position == null:
		return

	var item := item_scene.instantiate() as Node3D
	add_child(item)
	item.global_position = spawn_position

	if reward_type == "health":
		health_boxes.append(item)
	else:
		shotgun_ammo_boxes.append(item)

func find_spawn_position() -> Variant:
	if not player:
		player = get_tree().get_first_node_in_group("player") as Node3D
		if not player:
			return null

	for i in spawn_attempts:
		var angle := randf() * TAU
		var radius := randf_range(min_spawn_radius, max_spawn_radius)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * radius
		var probe_origin := player.global_position + offset + Vector3.UP * ground_probe_height
		var query := PhysicsRayQueryParameters3D.create(
			probe_origin,
			probe_origin + Vector3.DOWN * ground_probe_depth
		)
		var result := get_world_3d().direct_space_state.intersect_ray(query)

		if result:
			return result.position

	return null

func prune_collected_items() -> void:
	health_boxes = get_valid_items(health_boxes)
	shotgun_ammo_boxes = get_valid_items(shotgun_ammo_boxes)

func get_valid_items(items: Array[Node]) -> Array[Node]:
	var valid_items: Array[Node] = []

	for item in items:
		if is_instance_valid(item):
			valid_items.append(item)

	return valid_items
