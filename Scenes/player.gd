extends CharacterBody2D

# ============================================================
# PLAYER STATES
# ============================================================

enum PlayerState {
	IDLE,
	WALKING,
	ATTACKING
}

# ============================================================
# REFERENCES
# ============================================================

@onready var animated_sprite = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer

# ============================================================
# PLAYER SETTINGS
# ============================================================

const SPEED = 150.0

var facing_direction = "down"
var current_animation = ""
var current_state = PlayerState.IDLE
var direction = Vector2.ZERO


# ============================================================
# PHYSICS
# ============================================================

func _ready() -> void:
	# Health is changed by server-authoritative enemy AI, so its own
	# synchronizer must replicate from the server even when this player
	# character is owned by a client.
	var health_sync := get_node_or_null("HealthSynchronizer") as MultiplayerSynchronizer
	if health_sync != null:
		health_sync.set_multiplayer_authority(1, true)


func _physics_process(_delta: float) -> void:
	if !is_multiplayer_authority():
		return

	handle_input()
	update_facing_direction()
	update_state()
	update_animation()
	move_player()


# ============================================================
# INPUT
# ============================================================

func handle_input() -> void:
	handle_movement_input()
	handle_combat_input()


# ============================================================
# MOVEMENT INPUT
# ============================================================

func handle_movement_input() -> void:
	direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)


# ============================================================
# COMBAT INPUT
# ============================================================

func handle_combat_input() -> void:
	if current_state == PlayerState.ATTACKING:
		return

	if Input.is_action_just_pressed("attack"):
		current_state = PlayerState.ATTACKING

		# Play attack immediately on the local player.
		animation_player.play("Attack")

		# If this is a client, tell the server to attack
		# using the server's copy of this player.
		if not multiplayer.is_server():
			rpc_id(1, "_server_start_attack")
		else:
			_server_start_attack()


# ============================================================
# SERVER-SIDE ATTACK
# ============================================================

@rpc("any_peer", "reliable")
func _server_start_attack() -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()

	# When the server itself calls this function,
	# get_remote_sender_id() is 0.
	if sender_id == 0:
		sender_id = get_multiplayer_authority()

	# Only the owner of this player can request its attack.
	if sender_id != get_multiplayer_authority():
		return

	# Don't start another attack while already attacking.
	if current_state == PlayerState.ATTACKING:
		return

	current_state = PlayerState.ATTACKING

	# Run the attack animation on the SERVER copy.
	# This allows the AnimationPlayer to activate
	# the server-side weapon hitbox.
	animation_player.play("Attack")

	# Wait until the server-side attack animation finishes.
	await animation_player.animation_finished

	# Return to normal state.
	if current_state == PlayerState.ATTACKING:
		current_state = PlayerState.IDLE


# ============================================================
# MOVEMENT
# ============================================================

func move_player() -> void:
	velocity = direction * SPEED
	move_and_slide()


# ============================================================
# ANIMATION
# ============================================================

func update_animation() -> void:

	# --------------------------------------------------------
	# PLAYER IS IDLE
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# PLAYER IS WALKING
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# PLAYER IS ATTACKING
	# --------------------------------------------------------

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


# ============================================================
# PLAY ANIMATION
# ============================================================

func play_animation(animation_name: String) -> void:
	if current_animation == animation_name:
		return

	animated_sprite.play(animation_name)
	current_animation = animation_name


# ============================================================
# STATE UPDATE
# ============================================================

func update_state() -> void:
	if current_state == PlayerState.ATTACKING:
		return

	if direction == Vector2.ZERO:
		current_state = PlayerState.IDLE
	else:
		current_state = PlayerState.WALKING


# ============================================================
# FACING DIRECTION
# ============================================================

func update_facing_direction() -> void:

	if direction.y < 0:
		facing_direction = "up"

	elif direction.y > 0:
		facing_direction = "down"

	elif direction.x > 0:
		facing_direction = "right"

	elif direction.x < 0:
		facing_direction = "left"


# ============================================================
# ATTACK ANIMATION FINISHED
# ============================================================

func _on_animated_sprite_2d_animation_finished() -> void:

	if current_state != PlayerState.ATTACKING:
		return

	if direction == Vector2.ZERO:
		current_state = PlayerState.IDLE
	else:
		current_state = PlayerState.WALKING
