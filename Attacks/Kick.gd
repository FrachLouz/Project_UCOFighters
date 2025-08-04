extends Area2D

const KickHitbox = preload("res://Attacks/KickHitbox.tscn")
onready var startup_timer = $StartupTimer
onready var kick_timer = $KickTimer
onready var host_player = get_tree().get_root().get_node("Main/HostPlayer").get_path()
onready var sprite_width = $AttackVisualBox.texture.get_width() * $AttackVisualBox.scale.x
onready var inverse = false

var player_path = null

func _network_spawn_preprocess(data: Dictionary) -> Dictionary:
	data['player_path'] = data['player'].get_path()
	data.erase('player')
	return data

func _network_spawn(data: Dictionary) -> void:
	
	player_path = data['player_path']
	
	if data['player_path'] == host_player:
		global_position = data['position']
	else:
		inverse = true
		global_position = Vector2(data['position'].x-sprite_width, data['position'].y)
	
	kick_timer.start()
	startup_timer.start()

func _on_StartupTimer_timeout():
	startup_timer.stop()
	SyncManager.spawn("KickHitbox", get_parent(), KickHitbox, { position = global_position, 
																inverse = inverse, 
																offset = sprite_width,
																player_path = player_path})

func _on_KickTimer_timeout():
	SyncManager.despawn(self)
	
func take_hit(object_path: NodePath):
	print(self.get_path(), " me han golpeado")
