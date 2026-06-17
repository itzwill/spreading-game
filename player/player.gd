extends CharacterBody3D

@onready var shoot_timer: Timer = %ShootTimer
@onready var hitmarker_timer: Timer = %HitmarkerTimer
@onready var muzzle_flash_timer: Timer = %MuzzleFlashTimer

@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var hitmarker_sound: AudioStreamPlayer2D = $HitmarkerSound

@onready var hitmarker: TextureRect = $Hitmarker
@onready var muzzle_light: SpotLight3D = %MuzzleLight

@onready var bullet_origin_marker: Marker3D = %BulletOriginMarker

signal bullet_hit(body: Node3D)

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _physics_process(delta: float) -> void:
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
	
	if Input.is_action_pressed("shoot") and shoot_timer.is_stopped():
		shoot_bullet()

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * 0.5
		%Camera3D.rotation_degrees.x -= event.relative.y * 0.2
		%Camera3D.rotation_degrees.x = clamp(
			%Camera3D.rotation_degrees.x, -80.0, 80.0
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
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
	
const SHOTGUN_PELLETS := 5
const SHOTGUN_SPREAD := 4.0 # degrees
	
#func shoot_bullet():
	#const BULLET = preload("res://player/bullet.tscn")
#
	#for i in SHOTGUN_PELLETS:
		#var new_bullet: Area3D = BULLET.instantiate()
#
		#new_bullet.hit.connect(_on_bullet_hit)
#
		#bullet_origin_marker.add_child(new_bullet)
		#new_bullet.global_transform = bullet_origin_marker.global_transform
#
		#var yaw_offset = deg_to_rad(
			#randf_range(
				#-SHOTGUN_SPREAD * 0.5,
				#SHOTGUN_SPREAD * 0.5
			#)
		#)
#
		#var pitch_offset = deg_to_rad(
			#randf_range(
				#-SHOTGUN_SPREAD * 0.5,
				#SHOTGUN_SPREAD * 0.5
			#)
		#)
#
		#new_bullet.rotate_y(yaw_offset)
		#new_bullet.rotate_object_local(Vector3.RIGHT, pitch_offset)
#
	#shoot_timer.start()
	#shoot_sound.play()
func shoot_bullet():
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

	
func _on_bullet_hit(body: Node3D) -> void:
	bullet_hit.emit(body);
	if body.has_method("take_damage"):
		handle_hitmarker()

func handle_hitmarker():
	hitmarker_sound.play()
	hitmarker.visible = true;
	hitmarker_timer.start()
	

var muzzle_light_tween: Tween

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
	
func _on_hitmarker_timer_timeout() -> void:
	hitmarker.visible = false;

func _on_muzzle_flash_timer_timeout() -> void:
	muzzle_light.visible = false;
