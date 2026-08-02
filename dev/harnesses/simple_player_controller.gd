extends CharacterBody3D
## Simple first-person player controller for testing dungeons
## WASD = Move, Space = Jump, Mouse = Look, ESC = Release mouse, TAB = Dungeon menu

const SPEED := 8.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.002

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D


func _ready() -> void:
	# Create camera
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.position.y = 1.6  # Eye height
	camera.near = 0.05
	camera.far = 500.0
	camera.fov = 75.0
	add_child(camera)

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	print("[TestPlayer] Spawned at: %s" % global_position)
	print("[TestPlayer] Controls: WASD=Move, Space=Jump, Mouse=Look, ESC=Release mouse, TAB=Menu")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump - Space bar
	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement - WASD keys
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1

	input_dir = input_dir.normalized()
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
