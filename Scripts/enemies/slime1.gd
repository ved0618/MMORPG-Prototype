# Enemy
# Server-authoritative enemy AI with:
# - 4-direction movement
# - 4-direction idle
# - 4-direction attack
# - 4-direction hurt
# - 4-direction death
# - Multiplayer synchronization
#
# LEFT animations are NOT required.
# The R animations are flipped horizontally when facing left.
#
# Expected AnimatedSprite2D animations:
#
# WALK:
#   f_walk
#   b_walk
#   r_walk
#
# IDLE:
#   f_idle
#   b_idle
#   r_idle
#
# ATTACK:
#   f_attack
#   b_attack
#   r_attack
#
# HURT:
#   f_hurt
#   b_hurt
#   r_hurt
#
# DEATH:
#   f_death
#   b_death
#   r_death
#
# For LEFT:
#   r_animation + flip_h = true
#
# This means you do NOT need:
#   l_walk
#   l_idle
#   l_attack
#   l_hurt
#   l_death


extends CharacterBody2D


@onready var hurtbox = $"HurtBox(Area2D)"
@onready var health = $"Health(Node)"
@onready var animated_sprite = $AnimatedSprite2D


## How fast the enemy walks toward a player.
@export var move_speed: float = 90.0

## If a player is within this distance, the enemy starts chasing.
@export var alert_radius: float = 1000.0

## The enemy stops moving and bites when the player is this close.
@export var attack_range: float = 28.0

## Damage dealt per bite.
@export var attack_damage: int = 10

## Seconds between attacks.
@export var attack_cooldown: float = 1.2


# Counts down after every attack.
var _attack_ready: float = 0.0


# Current facing direction.
#
# f = front/down
# b = back/up
# l = left
# r = right
var _facing: String = "f"


# Prevents normal animation updates while attacking,
# being hurt, or dying.
var _special_animation: bool = false


# Prevents death from being triggered more than once.
var _is_dead: bool = false

# Avoid sending redundant facing updates every physics frame.
var _last_synced_flip_h: bool = false


func _ready() -> void:

	add_to_group("enemies")

	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)

	# Start facing down.
	_facing = "f"

	_play_idle()


func _physics_process(delta: float) -> void:

	# Only the server controls enemies.
	if not multiplayer.is_server():
		return

	if _is_dead:
		return

	_attack_ready = maxf(_attack_ready - delta, 0.0)

	var target := _nearest_player()


	# ========================================================
	# NO PLAYER
	# ========================================================

	if target == null:

		velocity = Vector2.ZERO

		if not _special_animation:
			_play_idle()

		return


	var to_target := target.global_position - global_position
	var distance := to_target.length()


	# Update which direction the enemy is facing.
	_update_facing(to_target)


	# ========================================================
	# PLAYER OUTSIDE ALERT RANGE
	# ========================================================

	if distance > alert_radius:

		velocity = Vector2.ZERO

		if not _special_animation:
			_play_idle()

		return


	# ========================================================
	# ATTACK
	# ========================================================

	if distance <= attack_range:

		velocity = Vector2.ZERO

		if _attack_ready == 0.0:

			_attack(target)

			_attack_ready = attack_cooldown

		else:

			if not _special_animation:
				_play_idle()


	# ========================================================
	# CHASE PLAYER
	# ========================================================

	else:

		velocity = to_target.normalized() * move_speed

		move_and_slide()

		if not _special_animation:
			_play_walk()


# ============================================================
# FIND NEAREST PLAYER
# ============================================================

func _nearest_player() -> Node2D:

	var nearest: Node2D = null

	var nearest_distance := alert_radius + 1.0

	for player in get_tree().get_nodes_in_group("players"):

		if not player.is_inside_tree():
			continue

		if not player.has_node("Health(Node)"):
			continue

		var d := global_position.distance_to(player.global_position)

		if d < nearest_distance:

			nearest = player
			nearest_distance = d

	return nearest


# ============================================================
# UPDATE FACING
# ============================================================

func _update_facing(direction: Vector2) -> void:

	if direction.length_squared() < 0.01:
		return


	# Horizontal movement is stronger.
	if abs(direction.x) > abs(direction.y):

		if direction.x > 0.0:
			_facing = "r"

		else:
			_facing = "l"


	# Vertical movement is stronger.
	else:

		if direction.y > 0.0:
			_facing = "f"

		else:
			_facing = "b"


# ============================================================
# ANIMATION HELPER
# ============================================================

func _play_animation(animation_name: String) -> void:
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	# The server is authoritative for enemy AI, so animation changes must be
	# explicitly sent to every peer. Replicating only the animation property
	# does not reliably restart a one-shot attack animation on clients.
	var should_flip: bool = animated_sprite.flip_h
	var needs_update: bool = (
		animated_sprite.animation != StringName(animation_name)
		or not animated_sprite.is_playing()
	)

	if multiplayer.is_server():
		if needs_update:
			_rpc_play_animation.rpc(animation_name, should_flip)
			_last_synced_flip_h = should_flip
		elif should_flip != _last_synced_flip_h:
			# Only send a facing update when the flip state actually changes.
			_rpc_sync_facing.rpc(should_flip)
			_last_synced_flip_h = should_flip
	else:
		_apply_animation_local(animation_name, should_flip)


func _apply_animation_local(animation_name: String, should_flip: bool) -> void:
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	animated_sprite.flip_h = should_flip
	_last_synced_flip_h = should_flip
	if animated_sprite.animation != StringName(animation_name) or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)


@rpc("authority", "call_local", "reliable")
func _rpc_play_animation(animation_name: String, should_flip: bool) -> void:
	_apply_animation_local(animation_name, should_flip)


@rpc("authority", "call_local", "unreliable")
func _rpc_sync_facing(should_flip: bool) -> void:
	animated_sprite.flip_h = should_flip
	_last_synced_flip_h = should_flip


# ============================================================
# DIRECTIONAL ANIMATION
# ============================================================
#
# This is the important part.
#
# If facing:
#
# f -> f_animation
# b -> b_animation
# r -> r_animation
# l -> r_animation + flip_h
#
# So you don't need any l_ animations.
# ============================================================

func _play_directional_animation(animation_type: String) -> void:

	var animation_name: String


	# --------------------------------------------------------
	# FRONT
	# --------------------------------------------------------

	if _facing == "f":

		animated_sprite.flip_h = false

		animation_name = "f_" + animation_type

		if animated_sprite.sprite_frames.has_animation(animation_name):

			_play_animation(animation_name)

			return


	# --------------------------------------------------------
	# BACK
	# --------------------------------------------------------

	elif _facing == "b":

		animated_sprite.flip_h = false

		animation_name = "b_" + animation_type

		if animated_sprite.sprite_frames.has_animation(animation_name):

			_play_animation(animation_name)

			return


	# --------------------------------------------------------
	# RIGHT
	# --------------------------------------------------------

	elif _facing == "r":

		animated_sprite.flip_h = false

		animation_name = "r_" + animation_type

		if animated_sprite.sprite_frames.has_animation(animation_name):

			_play_animation(animation_name)

			return


	# --------------------------------------------------------
	# LEFT
	# --------------------------------------------------------

	elif _facing == "l":

		# These slime sprite sheets include dedicated left-facing frames.
		# Prefer them; flipping the right-facing frames can make the slime
		# appear to walk backwards because the art is not always symmetric.
		animation_name = "l_" + animation_type
		animated_sprite.flip_h = false

		if animated_sprite.sprite_frames.has_animation(animation_name):
			_play_animation(animation_name)
			return

		# Fallback for enemy sheets that do not contain left animations.
		animation_name = "r_" + animation_type
		animated_sprite.flip_h = true
		if animated_sprite.sprite_frames.has_animation(animation_name):
			_play_animation(animation_name)
			return


	# --------------------------------------------------------
	# FALLBACK
	# --------------------------------------------------------

	# If the requested animation doesn't exist,
	# use front or back walk.

	animated_sprite.flip_h = false

	if animated_sprite.sprite_frames.has_animation("f_walk"):

		_play_animation("f_walk")

	elif animated_sprite.sprite_frames.has_animation("b_walk"):

		_play_animation("b_walk")


# ============================================================
# IDLE
# ============================================================

func _play_idle() -> void:

	_play_directional_animation("idle")


# ============================================================
# WALK
# ============================================================

func _play_walk() -> void:

	_play_directional_animation("walk")


# ============================================================
# ATTACK
# ============================================================

func _attack(player: Node2D) -> void:

	if _is_dead:
		return

	# Don't attack invulnerable players.
	if player.get("is_invulnerable") == true:
		return


	print("Enemy bites: ", name, " -> ", player.name)


	# Start directional attack animation.
	_play_attack_animation()


	# Get player health.
	var phealth = player.get_node_or_null("Health(Node)")

	if phealth == null:
		return


	# Deal damage.
	if phealth.has_method("take_damage"):

		phealth.take_damage(attack_damage)


# ============================================================
# ATTACK ANIMATION
# ============================================================

func _play_attack_animation() -> void:

	_special_animation = true


	var animation_name: String


	# --------------------------------------------------------
	# FRONT
	# --------------------------------------------------------

	if _facing == "f":

		animated_sprite.flip_h = false

		animation_name = "f_attack"


	# --------------------------------------------------------
	# BACK
	# --------------------------------------------------------

	elif _facing == "b":

		animated_sprite.flip_h = false

		animation_name = "b_attack"


	# --------------------------------------------------------
	# RIGHT
	# --------------------------------------------------------

	elif _facing == "r":

		animated_sprite.flip_h = false

		animation_name = "r_attack"


	# --------------------------------------------------------
	# LEFT
	# --------------------------------------------------------

	else:

		# Prefer the dedicated left-facing animation when the sprite sheet has one.
		animation_name = "l_attack"
		animated_sprite.flip_h = false
		if not animated_sprite.sprite_frames.has_animation(animation_name):
			# Fallback for sprite sheets with only right-facing frames.
			animation_name = "r_attack"
			animated_sprite.flip_h = true


	# --------------------------------------------------------
	# PLAY ATTACK
	# --------------------------------------------------------

	if animated_sprite.sprite_frames.has_animation(animation_name):

		_play_animation(animation_name)

		await animated_sprite.animation_finished

	else:

		# If attack animation doesn't exist,
		# use idle as fallback.

		_play_idle()

		await get_tree().create_timer(0.15).timeout


	_special_animation = false


# ============================================================
# HIT RECEIVED
# ============================================================

func _on_hit_received(hitbox) -> void:
	if _is_dead or not hitbox.has_method("get_damage"):
		return

	# Client-side hit detection must request damage from the server.
	# The server still validates the attacker, range, and enemy state.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		var weapon: Node = hitbox.get_parent()
		var attacker: Node = weapon.get_parent() if weapon != null else null
		if attacker != null:
			_request_server_damage.rpc_id(1, attacker.get_path(), hitbox.get_damage())
		return

	_apply_server_damage(hitbox.get_parent().get_parent(), hitbox.get_damage())


@rpc("any_peer", "reliable")
func _request_server_damage(attacker_path: NodePath, requested_damage: int) -> void:
	if not multiplayer.is_server() or _is_dead or requested_damage <= 0:
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	var attacker: Node = get_tree().root.get_node_or_null(attacker_path)
	if attacker == null or not attacker.is_inside_tree():
		return
	if attacker.get_multiplayer_authority() != sender_id:
		return
	if not attacker.has_node("Weapon/Hitbox(Area2D)"):
		return
	# Reject remote hit requests from outside plausible melee range.
	if global_position.distance_to(attacker.global_position) > 110.0:
		return

	_apply_server_damage(attacker, requested_damage)


func _apply_server_damage(_attacker: Node, amount: int) -> void:
	if not multiplayer.is_server() or _is_dead or amount <= 0:
		return

	_play_hurt_animation()
	health.take_damage(amount)


# ============================================================
# HURT
# ============================================================

func _play_hurt_animation() -> void:

	if _is_dead:
		return


	_special_animation = true


	var animation_name: String


	# --------------------------------------------------------
	# FRONT
	# --------------------------------------------------------

	if _facing == "f":

		animated_sprite.flip_h = false

		animation_name = "f_hurt"


	# --------------------------------------------------------
	# BACK
	# --------------------------------------------------------

	elif _facing == "b":

		animated_sprite.flip_h = false

		animation_name = "b_hurt"


	# --------------------------------------------------------
	# RIGHT
	# --------------------------------------------------------

	elif _facing == "r":

		animated_sprite.flip_h = false

		animation_name = "r_hurt"


	# --------------------------------------------------------
	# LEFT
	# --------------------------------------------------------

	else:

		# Prefer the dedicated left-facing animation when the sprite sheet has one.
		animation_name = "l_hurt"
		animated_sprite.flip_h = false
		if not animated_sprite.sprite_frames.has_animation(animation_name):
			# Fallback for sprite sheets with only right-facing frames.
			animation_name = "r_hurt"
			animated_sprite.flip_h = true


	# --------------------------------------------------------
	# PLAY HURT
	# --------------------------------------------------------

	if animated_sprite.sprite_frames.has_animation(animation_name):

		_play_animation(animation_name)

		await animated_sprite.animation_finished

	else:

		# If the hurt animation doesn't exist, wait briefly then continue.
		await get_tree().create_timer(0.15).timeout


	if not _is_dead:

		_special_animation = false


# ============================================================
# DEATH
# ============================================================

func _on_died() -> void:

	if not multiplayer.is_server():
		return

	if _is_dead:
		return


	_is_dead = true

	velocity = Vector2.ZERO

	_special_animation = true


	print("Enemy died: ", name)


	# Tell the map that an enemy died.
	var world := get_tree().current_scene

	if world.has_method("enemy_died"):

		world.enemy_died(self)


	# --------------------------------------------------------
	# DEATH ANIMATION
	# --------------------------------------------------------

	var animation_name: String


	if _facing == "f":

		animated_sprite.flip_h = false

		animation_name = "f_death"


	elif _facing == "b":

		animated_sprite.flip_h = false

		animation_name = "b_death"


	elif _facing == "r":

		animated_sprite.flip_h = false

		animation_name = "r_death"


	else:

		# Prefer the dedicated left-facing animation when the sprite sheet has one.
		animation_name = "l_death"
		animated_sprite.flip_h = false
		if not animated_sprite.sprite_frames.has_animation(animation_name):
			# Fallback for sprite sheets with only right-facing frames.
			animation_name = "r_death"
			animated_sprite.flip_h = true


	# --------------------------------------------------------
	# PLAY DEATH
	# --------------------------------------------------------

	if animated_sprite.sprite_frames.has_animation(animation_name):

		_play_animation(animation_name)

		await animated_sprite.animation_finished


	# Remove enemy.
	queue_free()
