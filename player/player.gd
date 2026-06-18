extends CharacterBody3D

@export var reload_start_sound: AudioStream
@export var insert_shell_sound: AudioStream
@export var reload_end_sound: AudioStream

@onready var shoot_timer: Timer = %ShootTimer
@onready var reload_timer: Timer = $ReloadTimer

@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var hitmarker_sound: AudioStreamPlayer2D = $HitmarkerSound
@onready var reload_sound: AudioStreamPlayer2D = %ReloadSound

@onready var muzzle_light: SpotLight3D = %MuzzleLight

@onready var bullet_origin_marker: Marker3D = %BulletOriginMarker
@onready var shotgun: Node3D = %Shotgun

signal hit_confirmed
signal input_prompt_changed(prompt_id: String, visible: bool)
signal temporary_input_prompt_requested(prompt_id: String)
signal update_ammo(gun_ammo: int, reserve_ammo: int)
signal update_health(hp: int)
signal died

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MAX_HEALTH := 100
const SHOTGUN_PELLETS := 5
const SHOTGUN_SPREAD := 4.0 # degrees
const REPAIR_RANGE := 3.0
const REPAIR_RATE := 25.0

const FIRST_SHELL_DELAY := 0.4
const SHELL_INSERT_DELAY := 0.37
const MAX_GUN_AMMO := 6
const MAX_RESERVE_AMMO := 38

var is_reloading := false
var muzzle_light_tween: Tween
var health := MAX_HEALTH
var gun_ammo: int = MAX_GUN_AMMO
var reserve_ammo: int = MAX_RESERVE_AMMO
var is_dead := false
var repair_prompt_visible := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("player")
	call_deferred("emit_ammo_update")

func emit_ammo_update() -> void:
	update_ammo.emit(gun_ammo, reserve_ammo)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	var repairable_barrier = get_facing_repairable_barrier()
	set_repair_prompt_visible(repairable_barrier != null)

	if Input.is_action_pressed("repair") and repairable_barrier:
		repairable_barrier.repair(REPAIR_RATE * delta)
	
	if Input.is_action_just_pressed("shoot") and should_prompt_reload():
		temporary_input_prompt_requested.emit("reload")

	if Input.is_action_pressed("shoot") and shoot_timer.is_stopped():
		shoot_bullet()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * 0.5
		%Camera3D.rotation_degrees.x -= event.relative.y * 0.2
		%Camera3D.rotation_degrees.x = clamp(
			%Camera3D.rotation_degrees.x, -80.0, 80.0
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("reload"):
		start_reload()

func get_aim_direction() -> Vector3:
	var camera = %Camera3D

	var viewport_size = get_viewport().get_visible_rect().size
	var screen_center = viewport_size * 0.5

	var origin = camera.project_ray_origin(screen_center)
	var direction = camera.project_ray_normal(screen_center)

	var query = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * 1000.0
	)

	query.exclude = [self]

	var result = get_world_3d().direct_space_state.intersect_ray(query)

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

	barrier.repair(REPAIR_RATE * delta)

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
		origin + direction * REPAIR_RANGE
	)

	query.exclude = [self]
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

	for i in SHOTGUN_PELLETS:
		var bullet = BULLET.instantiate()

		bullet.hit.connect(_on_bullet_hit)

		bullet_origin_marker.add_child(bullet)

		bullet.global_position = bullet_origin_marker.global_position

		var spread_basis = Basis()

		spread_basis = spread_basis.rotated(
			Vector3.UP,
			deg_to_rad(randf_range(
				-SHOTGUN_SPREAD,
				SHOTGUN_SPREAD
			))
		)

		spread_basis = spread_basis.rotated(
			Vector3.RIGHT,
			deg_to_rad(randf_range(
				-SHOTGUN_SPREAD,
				SHOTGUN_SPREAD
			))
		)

		bullet.direction = (
			spread_basis * base_direction
		).normalized()

	shoot_timer.start()
	shoot_sound.play()
	flash_muzzle()
	shotgun.shoot()

func _on_bullet_hit(body: Node3D) -> void:
	if body.has_method("take_damage"):
		hit_confirmed.emit()
		play_hitmarker_sound()

func play_hitmarker_sound() -> void:
	hitmarker_sound.play()
	
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

func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	if health == 0:
		die()

	update_health.emit(health)
	print("Player health:", health)

func add_health(amount: int) -> bool:
	if health >= MAX_HEALTH:
		return false

	health = min(health + amount, MAX_HEALTH)
	update_health.emit(health)
	print("Player health:", health)
	return true

func add_reserve_ammo(amount: int) -> bool:
	if reserve_ammo >= MAX_RESERVE_AMMO:
		return false

	reserve_ammo = min(reserve_ammo + amount, MAX_RESERVE_AMMO)
	emit_ammo_update()
	return true

func die() -> void:
	if is_dead:
		return

	print("Player died")
	is_dead = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	died.emit()

func start_reload() -> void:
	if is_reloading:
		return

	if gun_ammo >= MAX_GUN_AMMO:
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

	if gun_ammo >= MAX_GUN_AMMO:
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

	if gun_ammo < MAX_GUN_AMMO and reserve_ammo > 0:
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
