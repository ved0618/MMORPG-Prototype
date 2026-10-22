# Enemy 3D (2.5D / HD-2D)
# Server-authoritative enemy AI in 3D with billboarded 2D sprites
extends CharacterBody3D

@onready var hurtbox: Area3D = $"HurtBox(Area3D)"
@onready var health: Node = $"Health(Node)"
@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D

@export var move_speed: float = 3.6
@export var alert_radius: float = 30.0
@export var attack_range: float = 1.3
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.2

var _attack_timer: float = 0.0
var _facing: String = "f" # "f" = front/down (+Z), "b" = back/up (-Z), "r" = right (+X), "l" = left (-X)
var _special_animation: bool = false
var _is_dead: bool = false
var _target_player: Node3D = null


func _ready() -> void:
	if hurtbox and hurtbox.has_signal("hit_received"):
		hurtbox.hit_received.connect(_on_hit_received)
	if health and health.has_signal("died"):
		health.died.connect(_on_died)
	if animated_sprite and animated_sprite.has_signal("animation_finished"):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	_facing = "f"
	_play_anim("idle")


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return

	if _is_dead:
		velocity = Vector3.ZERO
		return

	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)

	if _special_animation:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_find_closest_player()

	if _target_player == null:
		velocity = Vector3.ZERO
		_play_anim("idle")
		move_and_slide()
		return

	var delta_pos := _target_player.global_position - global_position
	delta_pos.y = 0.0
	var dist := delta_pos.length()

	if dist > alert_radius:
		velocity = Vector3.ZERO
		_play_anim("idle")
		move_and_slide()
		return

	_update_facing(delta_pos)

	if dist <= attack_range:
		velocity = Vector3.ZERO
		if _attack_timer <= 0.0:
			_attack()
		else:
			_play_anim("idle")
	else:
		var dir := delta_pos.normalized()
		velocity = dir * move_speed
		velocity.y = 0.0
		_play_anim("walk")

	move_and_slide()


func _find_closest_player() -> void:
	var players := get_tree().get_nodes_in_group("players")
	var closest: Node3D = null
	var min_dist := INF

	for p in players:
		if not is_instance_valid(p) or not p is Node3D:
			continue
		var hp = p.get_node_or_null("Health(Node)")
		if hp and hp.current_health <= 0:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < min_dist:
			min_dist = d
			closest = p

	_target_player = closest


func _update_facing(dir: Vector3) -> void:
	if abs(dir.z) >= abs(dir.x):
		_facing = "f" if dir.z >= 0.0 else "b"
	else:
		_facing = "r" if dir.x >= 0.0 else "l"


func _attack() -> void:
	_attack_timer = attack_cooldown
	_special_animation = true
	_play_anim("attack")

	# Deal damage to player if still in range
	if _target_player and is_instance_valid(_target_player):
		var hp = _target_player.get_node_or_null("Health(Node)")
		if hp and hp.has_method("take_damage"):
			hp.take_damage(attack_damage)


var _last_attacker_peer_id: int = 1


func _on_hit_received(hitbox_area: Area3D) -> void:
	if _is_dead:
		return
	var dmg: int = 10
	if hitbox_area and hitbox_area.has_method("get_damage"):
		dmg = hitbox_area.get_damage()

	if hitbox_area and hitbox_area.has_method("get_attacker_peer_id"):
		_last_attacker_peer_id = hitbox_area.get_attacker_peer_id()
	elif _target_player and is_instance_valid(_target_player):
		_last_attacker_peer_id = int(_target_player.name)

	if health and health.has_method("take_damage"):
		health.take_damage(dmg)

	if not _is_dead:
		_special_animation = true
		_play_anim("hurt")


func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	_special_animation = true
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	_play_anim("death")

	# Award kill to the attacking player on the server
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var world = get_tree().current_scene
		if world and world.has_method("record_kill"):
			world.record_kill(_last_attacker_peer_id)


func _on_animation_finished() -> void:
	if _is_dead:
		queue_free()
		return
	_special_animation = false


func _play_anim(anim_type: String) -> void:
	var anim_name := ""
	match _facing:
		"f":
			anim_name = "f_" + anim_type
			animated_sprite.flip_h = false
		"b":
			anim_name = "b_" + anim_type
			animated_sprite.flip_h = false
		"r":
			anim_name = "r_" + anim_type
			animated_sprite.flip_h = false
		"l":
			anim_name = "r_" + anim_type
			animated_sprite.flip_h = true

	# Also check suffix convention (e.g. walk_front, walk_back, walk_side)
	var alt_anim_name := ""
	match _facing:
		"f":
			alt_anim_name = anim_type + "_front"
		"b":
			alt_anim_name = anim_type + "_back"
		"r", "l":
			alt_anim_name = anim_type + "_side"

	if animated_sprite.animation != anim_name and animated_sprite.animation != alt_anim_name:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)
		elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(alt_anim_name):
			animated_sprite.play(alt_anim_name)
		elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_type):
			animated_sprite.play(anim_type)
