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
@export var player_scene: PackedScene

#Player Settings
const SPEED = 100.0

#Runtime Variables
#Updated while the game is running
var facing_direction = "down"
var current_animation = ""
var current_state = PlayerState.IDLE
var direction = Vector2.ZERO

func _ready() -> void:
	# Only enable camera for the local player (authority)
	if is_multiplayer_authority():
		camera.enabled = true
		camera.make_current()

	# Debug: print authority info
	print("=== PLAYER READY ===")
	print("Name: ", name)
	print("My Peer ID: ", multiplayer.get_unique_id())
	print("Is Authority: ", is_multiplayer_authority())
	print("Authority ID: ", get_multiplayer_authority())
	print("====================")

#Main Game Loop
#Executes every physics frame
func _physics_process(_delta: float) -> void:
	# Only the authority (the owning peer) runs input and movement.
	# The MultiplayerSynchronizer replicates position/animation to everyone else.
	var is_auth = is_multiplayer_authority()
	var auth_id = get_multiplayer_authority()
	var my_id = multiplayer.get_unique_id()

	# Debug every 60 frames
	if Engine.get_frames_drawn() % 60 == 0:
		print("PHYSICS: name=", name, " is_auth=", is_auth, " auth_id=", auth_id, " my_id=", my_id)

	if is_auth:
		handle_input()

		update_state()
		update_facing_direction()
		weapon.update_facing(facing_direction)

		move_player()
		update_animation()
	else:
		# Debug: if we're not authority but still getting input, something's wrong
		if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
			print("WARNING: Non-authority player ", name, " receiving input! Authority: ", auth_id, " MyPeer: ", my_id, " is_auth: ", is_auth)

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
		# AnimationPlayer controls when the hitbox becomes active
		animation_player.play("Attack")

#Movement
func move_player() -> void:
	if current_state == PlayerState.ATTACKING:
		# Lock movement while the attack animation is playing
		velocity = Vector2.ZERO
	else:
		velocity = direction * SPEED
		
	move_and_slide()
	
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
	if direction == Vector2.ZERO:
		current_state = PlayerState.IDLE
	else:
		current_state = PlayerState.WALKING
