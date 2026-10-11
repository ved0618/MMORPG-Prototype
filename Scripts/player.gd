extends CharacterBody2D

#All Player States
# Controls the players's current behavior
enum PlayerState {
	IDLE,
	WALKING,
	ATTACKING
}

#REFERENCES
@onready var animated_sprite = $AnimatedSprite2D
@onready var weapon = $Weapon
@onready var animation_player = $AnimationPlayer
@onready var camera = $Camera2D
@onready var stamina = $"Stamina(Node)"
@onready var health = $"Health(Node)"
@export var player_scene: PackedScene

#Player Settings
const SPEED = 100.0

# Move speed while holding Shift. Faster than wolves (90) but teleport (160) is
# strictly better as an escape — sprint is good for repositioning, not fleeing.
const RUN_SPEED = 180.0

#Teleport (Q) — blinks ~3 tiles in the facing direction, faster than any
#movement so it beats sprinting. 4-second cooldown, costs 30 stamina, brief
#invulnerability during the blink.
const TELEPORT_DISTANCE: float = 96.0
const TELEPORT_DURATION: float = 0.16
const TELEPORT_SPEED: float = 600.0  # = TELEPORT_DISTANCE / TELEPORT_DURATION
const TELEPORT_STAMINA_COST: float = 30.0
const TELEPORT_COOLDOWN_TIME: float = 4.0
const ATTACK_STATE_TIMEOUT: float = 0.9

#Runtime Variables
#Updated while the game is running
var facing_direction = "down"
var current_animation = ""
var current_state = PlayerState.IDLE
var direction = Vector2.ZERO
var teleport_cooldown: float = 0.0
var teleport_timer: float = 0.0
var is_invulnerable: bool = false
var attack_state_timer: float = 0.0

func _ready() -> void:
	# Only enable camera for the local player (authority)
	if is_multiplayer_authority():
		camera.enabled = true
		camera.make_current()
		_setup_camera_limits()
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


# Server-authorized level transition. The server owns progression, but each remote
# player's movement authority belongs to that player, so changing position only on
# the server can be immediately overwritten by the client's next movement tick.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_force_teleport(target_position: Vector2) -> void:
	# Only accept this command from the server (peer ID 1).
	if multiplayer.get_remote_sender_id() != 1:
		return

	global_position = target_position
	velocity = Vector2.ZERO
	direction = Vector2.ZERO
	teleport_timer = 0.0
	is_invulnerable = false
	if is_multiplayer_authority():
		call_deferred("_update_camera_limits")

#Main Game Loop
#Executes every physics frame
func _physics_process(delta: float) -> void:
	# Only the authority (the owning peer) runs input and movement.
	# The MultiplayerSynchronizer replicates position/animation to everyone else.
	var is_auth = is_multiplayer_authority()

	# Tick cooldowns even outside the auth block (timer is local only)
	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	if current_state == PlayerState.ATTACKING:
		attack_state_timer = maxf(attack_state_timer - delta, 0.0)
		if attack_state_timer == 0.0:
			_finish_attack_state()

	# Teleport ticks for all peers (local visual movement)
	if teleport_timer > 0.0:
		teleport_timer -= delta
		# Apply the blink velocity — move_player() is skipped while teleporting,
		# so move_and_slide() runs here.
		move_and_slide()
		if teleport_timer <= 0.0:
			is_invulnerable = false
			velocity = Vector2.ZERO
		return

	if is_auth:
		# Teleport input is checked before the state gate so Q works while attacking
		if Input.is_action_just_pressed("teleport") and teleport_cooldown == 0.0 and stamina.spend(TELEPORT_STAMINA_COST):
			_do_teleport()

		handle_input()

		update_state()
		update_facing_direction()
		weapon.update_facing(facing_direction)

		move_player(delta)
		update_animation()

#Input Handling
func handle_input() -> void:
	handle_movement_input()
	handle_combat_input()

func handle_movement_input() -> void:
	#  Prevent movement input while attacking
	if current_state == PlayerState.ATTACKING:
		return
	
	direction = Input.get_vector(
		"move_left", 
		"move_right", 
		"move_up", 
		"move_down"
	)
	
func handle_combat_input() -> void:
	if current_state == PlayerState.ATTACKING:
		return

	if Input.is_action_just_pressed("attack"):
		current_state = PlayerState.ATTACKING
		attack_state_timer = ATTACK_STATE_TIMEOUT
		# AnimationPlayer controls when the hitbox becomes active
		animation_player.play("Attack")
		# Broadcast the attack to all peers so they play the visual animation
		_rpc_play_attack.rpc(facing_direction)


## Called on all peers to play the attack animation visually.
## The authority triggers this via RPC; every peer updates their local sprite.
@rpc("any_peer", "call_local", "reliable")
func _rpc_play_attack(attack_facing: String) -> void:
	# Ignore if this is our own call (authority already played it above)
	if is_multiplayer_authority():
		return
	# Update facing and play the correct attack sprite animation
	facing_direction = attack_facing
	current_state = PlayerState.ATTACKING
	attack_state_timer = ATTACK_STATE_TIMEOUT
	update_animation()

#Movement
func move_player(delta: float) -> void:
	if teleport_timer > 0.0:
		# During teleport the movement direction is locked to facing_direction
		return
	elif current_state == PlayerState.ATTACKING:
		# Lock movement while the attack animation is playing
		velocity = Vector2.ZERO
		stamina.regen(delta)
	else:
		# Sprint (hold Shift) to outrun monsters. Requires stamina > 0.
		var is_sprinting = Input.is_action_pressed("sprint") and direction != Vector2.ZERO and stamina.current_stamina > 0.0
		if is_sprinting:
			stamina.drain(delta)
			velocity = direction * RUN_SPEED
		else:
			stamina.regen(delta)
			velocity = direction * SPEED

	move_and_slide()

#Teleport
func _do_teleport() -> void:
	# Stamina cost is spent by the caller (spend()) before this runs
	teleport_cooldown = TELEPORT_COOLDOWN_TIME
	is_invulnerable = true
	teleport_timer = TELEPORT_DURATION
	# Teleport in the direction the player is currently facing
	var teleport_dir := Vector2.ZERO
	match facing_direction:
		"up":    teleport_dir = Vector2.UP
		"down":  teleport_dir = Vector2.DOWN
		"left":  teleport_dir = Vector2.LEFT
		"right": teleport_dir = Vector2.RIGHT
	velocity = teleport_dir * TELEPORT_SPEED
	# Lock movement state so animations keep playing the walk cycle during the dash
	if current_state != PlayerState.ATTACKING:
		current_state = PlayerState.WALKING
	
#Animation
# Update Animation
func update_animation() -> void:
	
	#Idle animations
	if current_state == PlayerState.IDLE:
		
		if facing_direction == "up":
			play_animation("idle_up")
			
		elif facing_direction == "down":
			play_animation("idle_down")
			
		elif facing_direction == "right":
			play_animation("idle_side")
			animated_sprite.flip_h = false
			
		elif facing_direction == "left":
			play_animation("idle_side")
			animated_sprite.flip_h = true
			
		return
		
	# Walking animations
	elif current_state == PlayerState.WALKING:
		if facing_direction == "up":
			play_animation("walk_up")

		elif facing_direction == "down":
			play_animation("walk_down")
	
		
		elif facing_direction == "right":
			play_animation("walk_side")
			animated_sprite.flip_h = false
	
		
		elif facing_direction == "left":
			play_animation("walk_side")
			animated_sprite.flip_h = true
	
	# Attack Animations
	elif current_state == PlayerState.ATTACKING:
		if facing_direction == "up":
			play_animation("attack_up")
			
		elif facing_direction == "down":
			play_animation("attack_down")
			
		elif facing_direction == "right":
			play_animation("attack_side")
			animated_sprite.flip_h = false
		elif facing_direction == "left":
			play_animation("attack_side")
			animated_sprite.flip_h = true
			
			
#Prevent restarting the same animation every frame
func play_animation(animation_name: String) -> void:
	if current_animation == animation_name:
		return
	animated_sprite.play(animation_name)
	current_animation = animation_name

#State Management
#Updating State
func update_state() -> void:
	# Keep attack state until the animation finishes
	if current_state == PlayerState.ATTACKING:
		return
		
	if direction == Vector2.ZERO:
		current_state = PlayerState.IDLE
	else: 
		current_state = PlayerState.WALKING

#Update the Direction the player Is Facing
func update_facing_direction() -> void:
	if direction.y < 0:
		facing_direction = "up"
	elif direction.y > 0:
		facing_direction = "down"

	elif direction.x > 0:
		facing_direction = "right"

	elif direction.x < 0:
		facing_direction = "left"

# Return to idle or walking after the attack animation ends
func _on_animated_sprite_2d_animation_finished() -> void:
	if current_state != PlayerState.ATTACKING:
		return
	_finish_attack_state()


func _finish_attack_state() -> void:
	attack_state_timer = 0.0
	if direction == Vector2.ZERO:
		current_state = PlayerState.IDLE
	else:
		current_state = PlayerState.WALKING


# ── Camera Boundary ────────────────────────────────────

const MapDataScript := preload("res://Scripts/map_data.gd")

func _setup_camera_limits() -> void:
	"""Initialize camera limits based on map dimensions."""
	var map_width = MapDataScript.MAP_WIDTH
	var map_height = MapDataScript.MAP_HEIGHT
	var half_w = map_width / 2.0
	var half_h = map_height / 2.0

	# Set camera limits to keep view within current map bounds
	# Assumes viewport is 1280x720 (camera zoom ~1.0)
	camera.limit_left = int(-half_w)
	camera.limit_right = int(half_w)
	camera.limit_top = int(-half_h)
	camera.limit_bottom = int(half_h)


func _update_camera_limits() -> void:
	"""Update camera limits when transitioning between maps."""
	if not is_multiplayer_authority():
		return

	var map_width = MapDataScript.MAP_WIDTH
	var map_height = MapDataScript.MAP_HEIGHT
	var half_w = map_width / 2.0
	var half_h = map_height / 2.0

	# Get the current map's global position to offset limits
	var current_map = get_parent()
	while current_map and current_map.name != "Maps":
		current_map = current_map.get_parent()

	if current_map:
		# Find which map node is our parent
		var map_node = get_parent()
		var map_offset = map_node.global_position

		camera.limit_left = int(map_offset.x - half_w)
		camera.limit_right = int(map_offset.x + half_w)
		camera.limit_top = int(map_offset.y - half_h)
		camera.limit_bottom = int(map_offset.y + half_h)
