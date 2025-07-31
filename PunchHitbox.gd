extends Node2D

onready var host_player = get_tree().get_root().get_node("Main/HostPlayer").get_path()
onready var active_timer = $ActiveTimer
onready var sprite_width = $AttackVisualBox.texture.get_width() * $AttackVisualBox.scale.x

func _network_spawn(data: Dictionary) -> void:
	
	if not data['inverse']:
		global_position = data['position']
	else:
		global_position = Vector2(data['position'].x + abs(data['offset']-sprite_width), data['position'].y)
	
	active_timer.start()


func _on_ActiveTimer_timeout():
	SyncManager.despawn(self)
