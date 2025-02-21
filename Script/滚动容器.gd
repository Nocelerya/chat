extends ScrollContainer

@onready var 聊天列表: VBoxContainer = $聊天列表

#func _physics_process(delta: float) -> void:
	#if Input.is_action_just_pressed("检测"):
		#print(Global.消息库)

func _on_聊天列表_resized() -> void:
	 # 等待下一帧
	await get_tree().process_frame
	# 确保新添加的子节点可见
	ensure_control_visible(聊天列表)
