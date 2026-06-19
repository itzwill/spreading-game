extends CharacterBody3D

const DEFAULT_GAMEPLAY_SETTINGS = preload("res://gameplay/default_gameplay_settings.tres")

@export var reload_start_sound: AudioStream
@export var insert_shell_sound: AudioStream
@export var reload_end_sound: AudioStream
@export var gameplay_settings: Resource

@onready var shoot_timer: Timer = %ShootTimer
@onready var reload_timer: Timer = $ReloadTimer

@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var hitmarker_sound: AudioStreamPlayer2D = $HitmarkerSound
@onready var reload_sound: AudioStreamPlayer2D = %ReloadSound
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var collect_health_sound: AudioStreamPlayer2D = $CollectHealthSound
@onready var collect_ammo_sound: AudioStreamPlayer2D = $CollectAmmoSound
@onready var no_ammo_click_sound: AudioStreamPlayer2D = $NoAmmoClickSound
@onready var repair_barrier_sound: AudioStreamPlayer2D = $RepairBarrierSound

@onready var muzzle_light: SpotLight3D = %MuzzleLight

@onready var camera: Camera3D = %Camera3D
@onready var bullet_origin_marker: Marker3D = %BulletOriginMarker
@onready var shotgun: Node3D = %Shotgun

signal hit_confirmed
signal input_prompt_changed(prompt_id: String, visible: bool)
signal temporary_input_prompt_requested(prompt_id: String)
signal update_ammo(gun_ammo: int, reserve_ammo: int)
signal update_health(hp: int)
signal pause_requested
signal died

const FIRST_SHELL_DELAY := 0.4
const SHELL_INSERT_DELAY := 0.37
const VERTICAL_SENSITIVITY_RATIO := 0.45

var is_reloading := false
var muzzle_light_tween: Tween
var camera_shake_time := 0.0
var camera_shake_duration := 0.0
var camera_shake_strength := 0.0
var camera_base_position := Vector3.ZERO
var health := 100
var gun_ammo := 6
var reserve_ammo := 38
var is_dead := false
var repair_prompt_visible := false
var repair_sound_active := false
var mouse_sensitivity := 0.28

func _ready() -> void:
	ensure_gameplay_settings()
	camera_base_position = camera.position
	health = gameplay_settings.player_max_health
	gun_ammo = gameplay_settings.shotgun_max_gun_ammo
	reserve_ammo = gameplay_settings.shotgun_max_reserve_ammo
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	setup_looping_sounds()
	call_deferred("emit_health_update")
	call_deferred("emit_ammo_update")

func setup_looping_sounds() -> void:
	if repair_barrier_sound.stream is AudioStreamWAV:
		repair_barrier_sound.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	repair_barrier_sound.finished.connect(_on_repair_barrier_sound_finished)

func emit_health_update() -> void:
	update_health.emit(health)

func ensure_gameplay_settings() -> void:
	if gameplay_settings == null:
		gameplay_settings = DEFAULT_GAMEPLAY_SETTINGS

func set_gameplay_settings(settings: Resource) -> void:
	gameplay_settings = settings if settings else DEFAULT_GAMEPLAY_SETTINGS
	health = gameplay_settings.player_max_health
	gun_ammo = gameplay_settings.shotgun_max_gun_ammo
	reserve_ammo = gameplay_settings.shotgun_max_reserve_ammo
	update_health.emit(health)
	emit_ammo_update()

func emit_ammo_update() -> void:
	update_ammo.emit(gun_ammo, reserve_ammo)

func _process(delta: float) -> void:
	update_camera_shake(delta)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = gameplay_settings.player_jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * gameplay_settings.player_move_speed
		velocity.z = direction.z * gameplay_settings.player_move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, gameplay_settings.player_move_speed)
		velocity.z = move_toward(velocity.z, 0, gameplay_settings.player_move_speed)

	move_and_slide()
	
	var repairable_barrier = get_facing_repairable_barrier()
	set_repair_prompt_visible(repairable_barrier != null)

	var is_repairing := Input.is_action_pressed("repair") and repairable_barrier != null
	if is_repairing:
		repairable_barrier.repair(gameplay_settings.barrier_repair_rate * delta)
		start_repair_sound()
	else:
		stop_repair_sound()
	
	if Input.is_action_just_pressed("shoot") and should_prompt_reload():
		temporary_input_prompt_requested.emit("reload")

	if Input.is_action_just_pressed("shoot") and gun_ammo == 0:
		play_no_ammo_click()

	if Input.is_action_pressed("shoot") and shoot_timer.is_stopped():
		shoot_bullet()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		camera.rotation_degrees.x -= event.relative.y * mouse_sensitivity * VERTICAL_SENSITIVITY_RATIO
		camera.rotation_degrees.x = clamp(
			camera.rotation_degrees.x, -80.0, 80.0
		)
	elif event.is_action_pressed("ui_cancel"):
		stop_repair_sound()
		pause_requested.emit()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("reload"):
		start_reload()

func get_aim_direction() -> Vector3:
	var camera = %Camera3D

	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = viewport_size * 0.5

	var origin = camera.project_ray_origin(screen_center)
	var direction = camera.project_ray_normal(screen_center)

	var result = get_first_non_barrier_ray_hit(origin, direction, 1000.0)

	var target_position: Vector3

	if result:
		target_position = result.position
	else:
		target_position = origin + direction * 1000.0

	return bullet_origin_marker.global_position.direction_to(target_position)

func repair_facing_barrier(delta: float) -> void:
	var barrier = get_facing_repairable_barrier()
	if barrier == null:
		return

	barrier.repair(gameplay_settings.barrier_repair_rate * delta)

func get_facing_repairable_barrier() -> Node:
	var barrier = get_facing_barrier()
	if barrier == null:
		return null

	if barrier.has_method("can_repair") and not barrier.can_repair():
		return null

	return barrier

func get_facing_barrier() -> Node:
	var camera = %Camera3D
	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = viewport_size * 0.5
	var origin = camera.project_ray_origin(screen_center)
	var direction = camera.project_ray_normal(screen_center)
	var query = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * gameplay_settings.barrier_repair_range
	)

	query.exclude = [self]
	query.collision_mask = 1
	query.collide_with_areas = true

	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return null

	return find_barrier(result.collider)

func set_repair_prompt_visible(visible: bool) -> void:
	if repair_prompt_visible == visible:
		return

	repair_prompt_visible = visible
	input_prompt_changed.emit("repair", repair_prompt_visible)

func should_prompt_reload() -> bool:
	return gun_ammo == 0 and reserve_ammo > 0 and not is_reloading

func find_barrier(node: Node) -> Node:
	while node:
		if node.is_in_group("barriers"):
			return node
		node = node.get_parent()

	return null

func shoot_bullet() -> void:
	if gun_ammo == 0:
		return
	
	if is_reloading:
		cancel_reload()
		
	gun_ammo -= 1
	emit_ammo_update()
	
	const BULLET = preload("res://player/bullet.tscn")

	var base_direction = get_aim_direction()

	for i in gameplay_settings.shotgun_pellets:
		var bullet = BULLET.instantiate()

		bullet.hit.connect(_on_bullet_hit)

		bullet_origin_marker.add_child(bullet)

		bullet.global_position = bullet_origin_marker.global_position

		var spread_basis = Basis()

		spread_basis = spread_basis.rotated(
			Vector3.UP,
			deg_to_rad(randf_range(
				-gameplay_settings.shotgun_spread_degrees,
				gameplay_settings.shotgun_spread_degrees
			))
		)

		spread_basis = spread_basis.rotated(
			Vector3.RIGHT,
			deg_to_rad(randf_range(
				-gameplay_settings.shotgun_spread_degrees,
				gameplay_settings.shotgun_spread_degrees
			))
		)

		bullet.direction = (
			spread_basis * base_direction
		).normalized()

	shoot_timer.start()
	shoot_sound.play()
	flash_muzzle()
	shake_camera(0.08, 0.035)
	shotgun.shoot()

func _on_bullet_hit(body: Node3D) -> void:
	if body.has_method("take_damage"):
		hit_confirmed.emit()
		play_hitmarker_sound()

func play_hitmarker_sound() -> void:
	hitmarker_sound.play()

func play_no_ammo_click() -> void:
	no_ammo_click_sound.play()

func start_repair_sound() -> void:
	repair_sound_active = true
	if not repair_barrier_sound.playing:
		repair_barrier_sound.stream_paused = false
		repair_barrier_sound.play()

func stop_repair_sound() -> void:
	repair_sound_active = false
	if repair_barrier_sound.playing:
		repair_barrier_sound.stop()

func _on_repair_barrier_sound_finished() -> void:
	if repair_sound_active:
		repair_barrier_sound.play()
	
func flash_muzzle() -> void:
	if muzzle_light_tween:
		muzzle_light_tween.kill()

	muzzle_light.light_energy = randf_range(8.0, 15.0)
	muzzle_light.spot_range = randf_range(15.0, 25.0)

	muzzle_light_tween = create_tween()

	muzzle_light_tween.set_parallel(true)

	muzzle_light_tween.tween_property(
		muzzle_light,
		"light_energy",
		0.0,
		0.1
	)

	muzzle_light_tween.tween_property(
		muzzle_light,
		"spot_range",
		0.0,
		0.1
	)

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value

func shake_camera(duration: float, strength: float) -> void:
	if is_dead:
		return

	camera_shake_duration = max(camera_shake_duration, duration)
	camera_shake_time = camera_shake_duration
	camera_shake_strength = max(camera_shake_strength, strength)

func update_camera_shake(delta: float) -> void:
	if is_dead:
		return

	if camera_shake_time <= 0.0:
		camera.position = camera_base_position
		camera.rotation_degrees.z = 0.0
		camera_shake_strength = 0.0
		return

	camera_shake_time = max(camera_shake_time - delta, 0.0)
	var amount := camera_shake_time / camera_shake_duration
	var offset := Vector3(
		randf_range(-camera_shake_strength, camera_shake_strength),
		randf_range(-camera_shake_strength, camera_shake_strength),
		0.0
	) * amount

	camera.position = camera_base_position + offset
	camera.rotation_degrees.z = randf_range(-2.0, 2.0) * amount

func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead:
		return

	health = max(health - amount, 0)
	hurt_sound.play()
	shake_camera(0.18, 0.11)

	if health == 0:
		die()

	update_health.emit(health)
	print("Player health:", health)

func add_health(amount: int) -> bool:
	if health >= gameplay_settings.player_max_health:
		return false

	health = min(health + amount, gameplay_settings.player_max_health)
	update_health.emit(health)
	collect_health_sound.play()
	print("Player health:", health)
	return true

func add_reserve_ammo(amount: int) -> bool:
	if reserve_ammo >= gameplay_settings.shotgun_max_reserve_ammo:
		return false

	reserve_ammo = min(reserve_ammo + amount, gameplay_settings.shotgun_max_reserve_ammo)
	emit_ammo_update()
	collect_ammo_sound.play()
	return true

func die() -> void:
	if is_dead:
		return

	print("Player died")
	is_dead = true
	stop_repair_sound()
	play_death_camera_fall()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	died.emit()

func play_death_camera_fall() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(camera, "position", Vector3(0.12, 0.18, 0.08), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(camera, "rotation_degrees:x", 12.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(camera, "rotation_degrees:z", 88.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func start_reload() -> void:
	if is_reloading:
		return

	if gun_ammo >= gameplay_settings.shotgun_max_gun_ammo:
		return

	if reserve_ammo <= 0:
		return

	is_reloading = true

	reload_sound.stream = reload_start_sound
	reload_sound.play()

	reload_timer.start(FIRST_SHELL_DELAY)

func _on_reload_timer_timeout() -> void:
	if not is_reloading:
		return

	if gun_ammo >= gameplay_settings.shotgun_max_gun_ammo:
		finish_reload()
		return

	if reserve_ammo <= 0:
		finish_reload()
		return

	gun_ammo += 1
	reserve_ammo -= 1

	emit_ammo_update()

	reload_sound.stream = insert_shell_sound
	reload_sound.play()

	if gun_ammo < gameplay_settings.shotgun_max_gun_ammo and reserve_ammo > 0:
		reload_timer.start(SHELL_INSERT_DELAY)
	else:
		finish_reload()

func finish_reload() -> void:
	is_reloading = false
	reload_sound.stream = reload_end_sound
	reload_sound.play()

func cancel_reload() -> void:
	is_reloading = false
	reload_timer.stop()
	reload_sound.stop()

func get_first_non_barrier_ray_hit(origin: Vector3, ray_direction: Vector3, distance: float) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var cast_from := origin
	var cast_to := origin + ray_direction * distance
	var excluded := [self]

	for i in 8:
		var query := PhysicsRayQueryParameters3D.create(cast_from, cast_to)
		query.exclude = excluded
		query.collision_mask = 1

		var result := space_state.intersect_ray(query)
		if result.is_empty():
			return {}

		if find_barrier(result.collider):
			excluded.append(result.collider)
			cast_from = result.position + ray_direction * 0.01
			continue

		return result

	return {}
