# Kill & Death HUD + Multiplayer Scoreboard
# Displays the player's personal kill/death counter and TAB scoreboard.
extends CanvasLayer

@onready var counter_panel: PanelContainer = $CounterPanel
@onready var counter_label: Label = $CounterPanel/MarginContainer/CounterLabel
@onready var scoreboard_panel: PanelContainer = $ScoreboardPanel
@onready var player_list_container: VBoxContainer = $ScoreboardPanel/MarginContainer/VBoxContainer/PlayerList

var _world: Node = null
var _latest_stats: Dictionary = {}


func _ready() -> void:
	var player = get_parent()
	if player and player.has_method("is_multiplayer_authority"):
		if not player.is_multiplayer_authority():
			visible = false
			set_process_input(false)
			return

	scoreboard_panel.visible = false
	_connect_to_world.call_deferred()


func _connect_to_world() -> void:
	_world = get_tree().current_scene
	if _world and _world.has_signal("stats_updated"):
		_world.stats_updated.connect(_on_stats_updated)
		if "player_stats" in _world:
			_on_stats_updated(_world.player_stats)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_TAB:
			if event.pressed and not event.echo:
				scoreboard_panel.visible = true
				_refresh_scoreboard()
			elif not event.pressed:
				scoreboard_panel.visible = false
			get_viewport().set_input_as_handled()


func _on_stats_updated(all_stats: Dictionary) -> void:
	_latest_stats = all_stats

	var my_peer_id: int = 1
	if multiplayer.has_multiplayer_peer():
		my_peer_id = multiplayer.get_unique_id()

	var my_data: Dictionary = all_stats.get(my_peer_id, {"kills": 0, "deaths": 0})
	var kills: int = int(my_data.get("kills", 0))
	var deaths: int = int(my_data.get("deaths", 0))

	counter_label.text = "⚔️ Kills: %d   💀 Deaths: %d" % [kills, deaths]

	if scoreboard_panel.visible:
		_refresh_scoreboard()


func _refresh_scoreboard() -> void:
	# Clear existing player rows
	for child in player_list_container.get_children():
		child.queue_free()

	var my_peer_id: int = 1
	if multiplayer.has_multiplayer_peer():
		my_peer_id = multiplayer.get_unique_id()

	# Sort peer IDs by kills descending
	var peer_ids: Array = _latest_stats.keys()
	peer_ids.sort_custom(func(a, b):
		var kills_a: int = int(_latest_stats[a].get("kills", 0))
		var kills_b: int = int(_latest_stats[b].get("kills", 0))
		return kills_a > kills_b
	)

	# If no stats yet, at least show local player
	if peer_ids.is_empty():
		peer_ids.append(my_peer_id)

	for id in peer_ids:
		var stat: Dictionary = _latest_stats.get(id, {"kills": 0, "deaths": 0})
		var k: int = int(stat.get("kills", 0))
		var d: int = int(stat.get("deaths", 0))
		var ratio: float = float(k) if d == 0 else float(k) / float(d)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		var p_name := "Player %d" % id
		if id == 1:
			p_name += " (Host)"
		if id == my_peer_id:
			p_name += " (You)"
			name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			name_label.add_theme_color_override("font_color", Color.WHITE)

		name_label.text = p_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 14)
		row.add_child(name_label)

		var kills_label := Label.new()
		kills_label.text = "%d" % k
		kills_label.custom_minimum_size = Vector2(70, 0)
		kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kills_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		kills_label.add_theme_font_size_override("font_size", 14)
		row.add_child(kills_label)

		var deaths_label := Label.new()
		deaths_label.text = "%d" % d
		deaths_label.custom_minimum_size = Vector2(70, 0)
		deaths_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deaths_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		deaths_label.add_theme_font_size_override("font_size", 14)
		row.add_child(deaths_label)

		var kd_label := Label.new()
		kd_label.text = "%.2f" % ratio
		kd_label.custom_minimum_size = Vector2(70, 0)
		kd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kd_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		kd_label.add_theme_font_size_override("font_size", 14)
		row.add_child(kd_label)

		player_list_container.add_child(row)
