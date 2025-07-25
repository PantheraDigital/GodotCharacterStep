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
	
	
	var perform_step := false
	if !move_direction.is_zero_approx():
		# set up variables
		var start : Vector3 = global_position
		var start_offset : Vector3 = Vector3.ZERO
		var direction : Vector3 = Vector3(velocity.x, 0.0, velocity.z).normalized()
		var width : float = _collision_shape_3d.shape.radius * 0.5
		var full_width : float = width + _collision_shape_3d.shape.radius
		# perform ray casts
		var center_result = CharacterStep3D.snapped_intersect_ray(get_world_3d().direct_space_state, start, direction, full_width, false, [self])
		start_offset = ((direction.rotated(Vector3.UP, deg_to_rad(90))).normalized() * width)
		var left_result = CharacterStep3D.snapped_intersect_ray(get_world_3d().direct_space_state, start + start_offset, direction, full_width, false, [self])
		start_offset = ((direction.rotated(Vector3.UP, deg_to_rad(-90))).normalized() * width)
		var right_result = CharacterStep3D.snapped_intersect_ray(get_world_3d().direct_space_state, start + start_offset, direction, full_width, false, [self])
		# process results
		if center_result.has("normal"):
			perform_step = center_result.normal.angle_to(Vector3.UP) > floor_max_angle
		elif left_result.has("normal"):
			perform_step = left_result.normal.angle_to(Vector3.UP) > floor_max_angle
		elif right_result.has("normal"):
			perform_step = right_result.normal.angle_to(Vector3.UP) > floor_max_angle
		elif center_result.has("error") and left_result.has("error") and right_result.has("error") and get_floor_normal().angle_to(Vector3.UP) <= floor_max_angle:
			# trigger step if all rays fail
			# this is good for small steps 
			perform_step = true
			
	# step_up should come BEFORE move_and_slide
	# we need to move the player to the ledge before they run into it like a wall
	# move_and_slide will smooth the movement of the character after step_up
	var stepped_up := false # reduces step down calls
	if !move_direction.is_zero_approx() and perform_step:
		var step : Dictionary = CharacterStep3D.step_up(self.get_rid(), global_transform, MAX_STEP_UP, Vector3(velocity.x, 0.0, velocity.z).normalized(), _collision_shape_3d.shape.radius * 0.5, 0.25)
		if !step.is_empty() and step["normal"].angle_to(Vector3.UP) <= floor_max_angle:
			global_position.y = step["point"].y
			stepped_up = true
	
	move_and_slide()
	
	# step_down should come AFTER move_and_slide
	# this is because if the player is not grounded but they were grounded before they moved
	# then they have stepped off a ledge and it should be checked if they can step_down
	if not stepped_up and not is_on_floor() and velocity.y <= 0 and was_on_floor:
		var ground_validation : Callable = func(_point : Vector3, _normal : Vector3) -> bool : return _normal.angle_to(Vector3.UP) <= floor_max_angle
		var step : Dictionary = CharacterStep3D.step_down(self.get_rid(), global_transform, MAX_STEP_DOWN, Vector3(velocity.x, 0.0, velocity.z).normalized(), _collision_shape_3d.shape.radius, ground_validation)
		if !step.is_empty():
			global_position = step["point"]
	
	# apply_floor_snap should come after all movement
	if velocity.y <= 0:
		# floor snap when not jumping 
		apply_floor_snap()
	
	# smooth camera movement to prevent harsh teleporting when stepping up and down
	_spring_arm_3d.global_position.x = _camera_pivot.global_position.x
	_spring_arm_3d.global_position.y = lerpf(_spring_arm_3d.global_position.y, _camera_pivot.global_position.y, 0.15)
	_spring_arm_3d.global_position.z = _camera_pivot.global_position.z


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
