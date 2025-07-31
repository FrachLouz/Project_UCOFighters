extends Node2D

onready var startup_timer = $StartupTimer
onready var Active_timer = $ActiveTimer
onready var Recovery_timer = $RecoveryTimer
onready var host_player = get_tree().get_root().get_node("Main/HostPlayer").get_path()
onready var sprite_width = $AttackVisualBox.texture.get_width() * $AttackVisualBox.scale.x

func _network_spawn_preprocess(data: Dictionary) -> Dictionary:
	data['player_path'] = data['player'].get_path()
	data.erase('player')
	return data

func _network_spawn(data: Dictionary) -> void:
	
	if data['player_path'] == host_player:
		global_position = data['position']
	else:
		global_position = Vector2(data['position'].x-sprite_width, data['position'].y)
	
	
	startup_timer.start()



func _on_StartupTimer_timeout():
	pass # Replace with function body.


func _on_ActiveTimer_timeout():
	pass # Replace with function body.


func _on_RecoveryTimer_timeout():
	pass # Replace with function body.
