extends Node3D

const DEFAULT_GAMEPLAY_SETTINGS = preload("res://gameplay/default_gameplay_settings.tres")

@export var mob_to_spawn: PackedScene = null
@export var gameplay_settings: Resource

signal mob_spawned(mob)

@onready var marker_3d: Marker3D = %Marker3D
@onready var timer: Timer = %Timer

var elapsed_spawn_seconds := 0.0

func _ready() -> void:
	ensure_gameplay_settings()
	timer.one_shot = true
	schedule_next_spawn()

func _process(delta: float) -> void:
	elapsed_spawn_seconds += delta

func ensure_gameplay_settings() -> void:
	if gameplay_settings == null:
		gameplay_settings = DEFAULT_GAMEPLAY_SETTINGS

func set_gameplay_settings(settings: Resource) -> void:
	gameplay_settings = settings if settings else DEFAULT_GAMEPLAY_SETTINGS
	if is_inside_tree() and timer:
		schedule_next_spawn()

func _on_timer_timeout() -> void:
	if mob_to_spawn == null:
		schedule_next_spawn()
		return

	for i in get_spawn_burst_count():
		spawn_mob()

	schedule_next_spawn()

func spawn_mob() -> void:
	var new_mob: Node3D = mob_to_spawn.instantiate()
	if new_mob.has_method("set_gameplay_settings"):
		new_mob.set_gameplay_settings(gameplay_settings)
	add_child(new_mob)
	new_mob.global_position = marker_3d.global_position + get_spawn_scatter()
	mob_spawned.emit(new_mob)

func schedule_next_spawn() -> void:
	timer.start(get_spawn_interval())

func get_spawn_interval() -> float:
	var minutes := elapsed_spawn_seconds / 60.0
	var interval: float = gameplay_settings.zombie_spawn_interval_start
	interval -= gameplay_settings.zombie_spawn_interval_ramp_per_minute * minutes
	return max(interval, gameplay_settings.zombie_spawn_interval_min)

func get_spawn_burst_count() -> int:
	var minutes := elapsed_spawn_seconds / 60.0
	var burst: int = gameplay_settings.zombie_spawn_burst_start
	burst += floori(gameplay_settings.zombie_spawn_burst_ramp_per_minute * minutes)
	return clampi(burst, 1, gameplay_settings.zombie_spawn_burst_max)

func get_spawn_scatter() -> Vector3:
	var radius := randf_range(0.0, gameplay_settings.zombie_spawn_scatter_radius)
	var angle := randf_range(0.0, TAU)
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
