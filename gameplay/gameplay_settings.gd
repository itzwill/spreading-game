extends Resource
class_name GameplaySettings

@export_group("Player")
@export var player_max_health := 100
@export var player_move_speed := 5.0
@export var player_jump_velocity := 4.5
@export var barrier_repair_range := 3.0
@export var barrier_repair_rate := 25.0

@export_group("Shotgun")
@export var shotgun_pellets := 5
@export var shotgun_spread_degrees := 4.0
@export var shotgun_max_gun_ammo := 6
@export var shotgun_max_reserve_ammo := 38
@export var shotgun_base_damage := 20.0
@export var shotgun_headshot_multiplier := 2.0
@export var shotgun_body_multiplier := 1.0
@export var shotgun_falloff_distance := 40.0
@export var shotgun_min_falloff_multiplier := 0.5
@export_range(0.0, 1.0, 0.01) var shotgun_damage_randomness := 0.1

@export_group("Zombies")
@export var zombie_max_health := 100
@export var zombie_move_speed := 2.5
@export var zombie_animation_max_speed := 5.0
@export var zombie_attack_range := 1.5
@export var zombie_player_damage := 10
@export var zombie_barrier_damage := 25

@export_group("Zombie Spawning")
@export var zombie_spawn_interval_start := 5.0
@export var zombie_spawn_interval_min := 1.25
@export var zombie_spawn_interval_ramp_per_minute := 0.45
@export var zombie_spawn_burst_start := 1
@export var zombie_spawn_burst_max := 4
@export var zombie_spawn_burst_ramp_per_minute := 0.35
@export var zombie_spawn_scatter_radius := 1.25
@export var zombie_primary_spawn_weight := 12.0
@export var zombie_secondary_spawn_start_weight := 0.35
@export var zombie_secondary_spawn_max_weight := 8.0
@export var zombie_secondary_spawn_weight_ramp_per_minute := 1.25
