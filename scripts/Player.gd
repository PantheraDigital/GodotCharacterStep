extends CharacterBody3D

## A basic third person script for a player character that implements character_step
## to allow moving up ledges of specified heights

const MAX_STEP_UP : float = 1.0
const MAX_STEP_DOWN : float = 1.0
const SPEED : float = 5.0
const JUMP_VELOCITY : float = 4.5

@export_range(0.0, 1.0) var mouse_sensitivity : float = 0.01
@export var tilt_limit : float = deg_to_rad(55)

var was_on_floor : bool = false

@onready var _spring_arm_3d: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _collision_shape_3d: CollisionShape3D = $CollisionShape3D



func _ready() -> void:
	# prevent spring arm from colliding with owning character
	# can cause "camera flicker" if spring arm can collide with playe
	# you may also change the collision masks of spring arm and character body 
	_spring_arm_3d.add_excluded_object($"..") 


func _process(_delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_ESCAPE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	# track if character was on floor before movement is applied
	# this helps determine if character is jumping off a ledge
	was_on_floor = is_on_floor()
	
	velocity += get_gravity() * delta

	# handle movement
	var move_direction: Vector3 = Vector3.ZERO
	move_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	move_direction.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	# rotate movement to camera direction
	move_direction = move_direction.rotated(Vector3.UP, _camera_pivot.rotation.y)
	if move_direction:
		velocity.x = move_direction.x * SPEED
		velocity.z = move_direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# step_up should come BEFORE move_and_slide
	# move_and_slide will smooth the movement of the character after step_up
	if !move_direction.is_zero_approx():
		var step : Vector3 = CharacterStep3D.step_up(self, _collision_shape_3d, MAX_STEP_UP)
		if step != global_position:
			global_position = step
			# alternate usage
			#global_position.y = step.y
	
	move_and_slide()
	
	# step_down should come AFTER move_and_slide
	# this is because if the player is not grounded but they were grounded before they moved
	# then they have stepped off a ledge and it should be checked if they can step_down
	if not is_on_floor() and velocity.y <= 0 and was_on_floor:
		var step : Vector3 = CharacterStep3D.step_down(self, _collision_shape_3d, MAX_STEP_DOWN)
		if step != global_position:
			global_position = step
	
	# apply_floor_snap should come after all movement
	if velocity.y <= 0:
		# floor snap when not jumping 
		apply_floor_snap()
	
	# smooth camera movement to prevent harsh teleporting when stepping up and down
	_spring_arm_3d.global_position.x = global_position.x
	_spring_arm_3d.global_position.y = lerpf(_spring_arm_3d.global_position.y, global_position.y, 0.15)
	_spring_arm_3d.global_position.z = global_position.z


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_camera_pivot.rotation.x -= event.relative.y * mouse_sensitivity
		# Prevent the camera from rotating too far up or down.
		_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, -tilt_limit, tilt_limit)
		_camera_pivot.rotation.y += -event.relative.x * mouse_sensitivity
		# _spring_arm_3d top_level is set to true to allow for independant movement from parent 
		# this enables lerp to be used with camera position, otherwise camera position would always be set
		# to parent position with top_level set to false
		if _spring_arm_3d.top_level:
			_spring_arm_3d.rotation = _camera_pivot.rotation
