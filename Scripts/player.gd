extends CharacterBody2D

#All Player States
enum PlayerState {
	IDLE,
	WALKING,
	ATTACKING
}

@onready var animated_sprite = $AnimatedSprite2D
const SPEED = 100.0
var facing_direction = "down"
var current_animation = ""
var current_state = PlayerState.IDLE
var direction = Vector2.ZERO
@onready var weapon = $Weapon

func _physics_process(_delta: float) -> void:
	handle_input()
	
	update_facing_direction()
	update_state()
	update_animation()
	
	move_player()


#Input
func handle_input() -> void:
	handle_movement_input()
	handle_combat_input()

func handle_movement_input() -> void:
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
		weapon.attack(facing_direction)

#Movement
func move_player() -> void:
	if current_state == PlayerState.ATTACKING:
		velocity = Vector2.ZERO
	else:
		velocity = direction * SPEED
		
	move_and_slide()
	
#Animation
# Update Animation
func update_animation() -> void:
	
	#Player isn't Moving
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
		
	# Player is walking
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
			
			
#Plays The Animation
func play_animation(animation_name: String) -> void:
	if current_animation == animation_name:
		return
	animated_sprite.play(animation_name)
	current_animation = animation_name

#State
#Updating State
func update_state() -> void:
	if current_state == PlayerState.ATTACKING:
		return
		
	if direction == Vector2.ZERO:
		current_state = PlayerState.IDLE
	else: 
		current_state = PlayerState.WALKING

#Tells Which Direction Is Facing
func update_facing_direction() -> void:
	if direction.y < 0:
		facing_direction = "up"
	elif direction.y > 0:
		facing_direction = "down"

	elif direction.x > 0:
		facing_direction = "right"

	elif direction.x < 0:
		facing_direction = "left"


func _on_animated_sprite_2d_animation_finished() -> void:
	if current_state != PlayerState.ATTACKING:
		return
	if direction == Vector2.ZERO:
		current_state = PlayerState.IDLE
	else:
		current_state = PlayerState.WALKING
