extends Control

@onready var 输入内容: RichTextLabel = $HBoxContainer/输入内容
@onready var h_box_container: HBoxContainer = $HBoxContainer
@onready var 文字输入: TextEdit = $"../../../../底部区域/聊天区域列表/输入区域/MarginContainer/输入区域排列/文字输入"
var 宽度最大值 := 864

func 设置回答内容(消息ID: int) -> void:
	if Global.消息库.has(消息ID):  # 直接检查消息库是否存在该消息ID
		输入内容.text = Global.消息库[消息ID]["内容"]
		_update_layout() # 更新布局
	
func _notification(what):
	# 允许 Label 扩展宽度
	if what == NOTIFICATION_RESIZED:
		if 输入内容:
			输入内容.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#else:
		#print("错误: 输入内容节点未找到")

func _update_layout():
	if 输入内容:
		# 获取内容宽度
		var content_width = 输入内容.get_content_width()
		
		# 判断宽度是否达到最大值
		if content_width >= 宽度最大值:
			# 启用自动换行并限制宽度
			输入内容.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			输入内容.custom_minimum_size.x = 宽度最大值
			custom_minimum_size.y = h_box_container.size.y
			print(custom_minimum_size.y,h_box_container.size.y)
			#self.size.x = 宽度最大值 # 不需要手动设置宽度
		else:
			# 未达到最大宽度时，允许动态调整宽度
			输入内容.autowrap_mode = TextServer.AUTOWRAP_OFF
			输入内容.custom_minimum_size.x = 0  # 取消最小宽度限制
			
func _on_h_box_container_resized() -> void:
	if h_box_container:
		custom_minimum_size.y = h_box_container.size.y


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and MOUSE_BUTTON_LEFT:  # 确保是键盘按下事件
		DisplayServer.clipboard_set(输入内容.text)
		print("复制成功")


func _on_texture_rect_2_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and MOUSE_BUTTON_LEFT:  # 确保是键盘按下事件
		文字输入.text = 输入内容.text
