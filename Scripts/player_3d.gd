# Player 3D (2.5D / HD-2D)
# Controls character movement in 3D space with billboarded 2D pixel art
extends CharacterBody3D

enum PlayerState {
	IDLE,
	WALKING,
	ATTACKING
}

# REFERENCES
@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var weapon: Node3D = $Weapon
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera3D = $Camera3D
@onready var stamina = $"Stamina(Node)"
@onready var health = $"Health(Node)"

# SETTINGS (in 3D meters/sec)
const SPEED: float = 4.0
const RUN_SPEED: float = 7.2
const TELEPORT_DISTANCE: float = 3.84
const TELEPORT_DURATION: float = 0.16
const TELEPORT_SPEED: float = 24.0 # = TELEPORT_DISTANCE / TELEPORT_DURATION
const TELEPORT_STAMINA_COST: float = 30.0
const TELEPORT_COOLDOWN_TIME: float = 4.0
const ATTACK_STATE_TIMEOUT: float = 0.9

# Camera offset for 2.5D isometric perspective
const CAMERA_OFFSET := Vector3(0.0, 11.0, 11.0)
const CAMERA_PITCH_DEG: float = -45.0

# RUNTIME
var facing_direction: String = "down"
var current_animation: String = ""
var current_state = PlayerState.IDLE
var direction: Vector3 = Vector3.ZERO
var teleport_cooldown: float = 0.0
var teleport_timer: float = 0.0
var is_invulnerable: bool = false
var attack_state_timer: float = 0.0

var pause_menu_scene = preload("res://UI/menus/pause_menu.tscn")
var pause_menu: Node = null


func _ready() -> void:
	if is_multiplayer_authority():
		camera.top_level = true
		camera.current = true
		_setup_mobile_controls()


func _setup_mobile_controls() -> void:
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		return
	var controls_scene := preload("res://UI/mobile_controls.tscn")
	var controls_layer := CanvasLayer.new()
	controls_layer.name = "MobileControlsLayer"
	controls_layer.layer = 10
	add_child(controls_layer)
	controls_layer.add_child(controls_scene.instantiate())


func _process(_delta: float) -> void:
	if is_multiplayer_authority() and camera:
		camera.global_position = global_position + CAMERA_OFFSET
		camera.rotation_degrees = Vector3(CAMERA_PITCH_DEG, 0.0, 0.0)


func _input(event: InputEvent) -> void:
	if is_multiplayer_authority() and event.is_action_pressed("esc"):
		open_pause_menu()


func open_pause_menu() -> void:
	if pause_menu == null:
		pause_menu = pause_menu_scene.instantiate()
		add_child(pause_menu)
		get_tree().paused = true


@rpc("any_peer", "call_remote", "reliable")
func _rpc_force_teleport(target_position: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() != 1:
		return
	global_position = target_position
	velocity = Vector3.ZERO
	direction = Vector3.ZERO
	teleport_timer = 0.0
	is_invulnerable = false


func _physics_process(delta: float) -> void:
	var is_auth: bool = is_multiplayer_authority()

	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	if current_state == PlayerState.ATTACKING:
		attack_state_timer = maxf(attack_state_timer - delta, 0.0)
		if attack_state_timer == 0.0:
			_finish_attack_state()

	# Teleport dash tick
	if teleport_timer > 0.0:
		teleport_timer -= delta
		move_and_slide()
		if teleport_timer <= 0.0:
			is_invulnerable = false
			velocity = Vector3.ZERO
		return

	if is_auth:
		if Input.is_action_just_pressed("teleport") and teleport_cooldown == 0.0 and stamina.spend(TELEPORT_STAMINA_COST):
			_do_teleport()

		handle_input()
		update_state()
		update_facing_direction()
		if weapon:
			weapon.update_facing(facing_direction)

		move_player(delta)
		update_animation()


func handle_input() -> void:
	handle_movement_input()
	handle_combat_input()


func handle_movement_input() -> void:
	if current_state == PlayerState.ATTACKING:
		return

	var input_vec := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	# In 3D: X is left/right, Z is forward/back (-Z is up on screen, +Z is down on screen)
	direction = Vector3(input_vec.x, 0.0, input_vec.y).normalized()


func handle_combat_input() -> void:
	if current_state == PlayerState.ATTACKING:
		return

	if Input.is_action_just_pressed("attack"):
		current_state = PlayerState.ATTACKING
		attack_state_timer = ATTACK_STATE_TIMEOUT
		animation_player.play("Attack")
		if multiplayer.has_multiplayer_peer():
			_rpc_play_attack.rpc(facing_direction)


@rpc("any_peer", "call_local", "reliable")
func _rpc_play_attack(attack_facing: String) -> void:
	if is_multiplayer_authority():
		return
	facing_direction = attack_facing
	current_state = PlayerState.ATTACKING
	attack_state_timer = ATTACK_STATE_TIMEOUT
	update_animation()


func move_player(delta: float) -> void:
	if teleport_timer > 0.0:
		return
	elif current_state == PlayerState.ATTACKING:
		velocity = Vector3.ZERO
		stamina.regen(delta)
	else:
		var is_sprinting: bool = Input.is_action_pressed("sprint") and direction != Vector3.ZERO and stamina.current_stamina > 0.0
		if is_sprinting:
			stamina.drain(delta)
			velocity = direction * RUN_SPEED
		else:
			stamina.regen(delta)
			velocity = direction * SPEED

	# Keep on the ground floor
	velocity.y = 0.0
	move_and_slide()


func _do_teleport() -> void:
	teleport_cooldown = TELEPORT_COOLDOWN_TIME
	is_invulnerable = true
	teleport_timer = TELEPORT_DURATION
	var teleport_dir := Vector3.ZERO
	match facing_direction:
		"up":    teleport_dir = Vector3(0.0, 0.0, -1.0)
		"down":  teleport_dir = Vector3(0.0, 0.0, 1.0)
		"left":  teleport_dir = Vector3(-1.0, 0.0, 0.0)
		"right": teleport_dir = Vector3(1.0, 0.0, 0.0)
	velocity = teleport_dir * TELEPORT_SPEED
	if current_state != PlayerState.ATTACKING:
		current_state = PlayerState.WALKING


func update_state() -> void:
	if current_state == PlayerState.ATTACKING:
		return
	if direction == Vector3.ZERO:
		current_state = PlayerState.IDLE
	else:
		current_state = PlayerState.WALKING


func update_facing_direction() -> void:
	if abs(direction.z) >= abs(direction.x) and abs(direction.z) > 0.01:
		if direction.z < 0.0:
			facing_direction = "up"
		else:
			facing_direction = "down"
	elif abs(direction.x) > 0.01:
		if direction.x > 0.0:
			facing_direction = "right"
		else:
			facing_direction = "left"


func update_animation() -> void:
	match current_state:
		PlayerState.IDLE:
			match facing_direction:
				"up":
					play_animation("idle_up")
				"down":
					play_animation("idle_down")
				"right":
					play_animation("idle_side")
					animated_sprite.flip_h = false
				"left":
					play_animation("idle_side")
					animated_sprite.flip_h = true

		PlayerState.WALKING:
			match facing_direction:
				"up":
					play_animation("walk_up")
				"down":
					play_animation("walk_down")
				"right":
					play_animation("walk_side")
					animated_sprite.flip_h = false
				"left":
					play_animation("walk_side")
					animated_sprite.flip_h = true

		PlayerState.ATTACKING:
			match facing_direction:
				"up":
					play_animation("attack_up")
				"down":
					play_animation("attack_down")
				"right":
					play_animation("attack_side")
					animated_sprite.flip_h = false
				"left":
					play_animation("attack_side")
					animated_sprite.flip_h = true


func play_animation(animation_name: String) -> void:
	if current_animation == animation_name:
		return
	animated_sprite.play(animation_name)
	current_animation = animation_name


func _on_animated_sprite_3d_animation_finished() -> void:
	if current_state != PlayerState.ATTACKING:
		return
	_finish_attack_state()


func _finish_attack_state() -> void:
	attack_state_timer = 0.0
	if direction == Vector3.ZERO:
		current_state = PlayerState.IDLE
	else:
		current_state = PlayerState.WALKING
