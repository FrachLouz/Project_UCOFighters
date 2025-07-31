extends Node2D

const PunchHitbox = preload("res://PunchHitbox.tscn")
onready var startup_timer = $StartupTimer
onready var punch_timer = $PunchTimer
onready var host_player = get_tree().get_root().get_node("Main/HostPlayer").get_path()
onready var sprite_width = $AttackVisualBox.texture.get_width() * $AttackVisualBox.scale.x
onready var inverse = false

func _network_spawn_preprocess(data: Dictionary) -> Dictionary:
	data['player_path'] = data['player'].get_path()
	data.erase('player')
	return data

func _network_spawn(data: Dictionary) -> void:
	
	if data['player_path'] == host_player:
		global_position = data['position']
	else:
		inverse = true
		global_position = Vector2(data['position'].x-sprite_width, data['position'].y)
	
	punch_timer.start()
	startup_timer.start()

func _on_StartupTimer_timeout():
	startup_timer.stop()
	SyncManager.spawn("PunchHitbox", get_parent(), PunchHitbox, { position = global_position, inverse = inverse, offset = sprite_width})

func _on_PunchTimer_timeout():
	SyncManager.despawn(self)
	
