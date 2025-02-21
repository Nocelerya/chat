extends Control
@onready var h_box_container: HBoxContainer = $HBoxContainer
@onready var 回答内容: RichTextLabel = $HBoxContainer/VBoxContainer/回答内容
var 宽度最大值 := 864
var 控件ID
var 目标文本 := ""
var 当前显示文本 := ""
var 字符位置 := 0
var 显示计时器: Timer

func _ready():
	if 回答内容:
		回答内容.size_flags_horizontal = Control.SIZE_EXPAND_FILL # 允许水平扩展
		_update_layout() # 初始调用布局
		
		# 创建计时器
		显示计时器 = Timer.new()
		显示计时器.one_shot = false
		显示计时器.wait_time = 0.02  # 每个字符显示间隔时间
		显示计时器.timeout.connect(_显示下一个字符)
		add_child(显示计时器)

func 设置回答内容(消息ID: int) -> void:
	控件ID = 消息ID
	if Global.消息库.has(消息ID):
		var 新文本 = Global.消息库[消息ID]["内容"]
		if 新文本 != 目标文本:  # 如果文本有更新
			目标文本 = 新文本
			if not 显示计时器.is_stopped():  # 如果计时器正在运行
				# 如果是流式更新，直接更新目标文本，继续显示
				pass
			else:
				# 如果是新的显示，重置状态并开始显示
				字符位置 = 0
				当前显示文本 = ""
				回答内容.text = ""
				显示计时器.start()

func _显示下一个字符():
	if 字符位置 < 目标文本.length():
		当前显示文本 += 目标文本[字符位置]
		回答内容.text = 当前显示文本
		字符位置 += 1
		_update_layout()
	else:
		显示计时器.stop()

func _update_layout():
	if 回答内容:
		var content_width = 回答内容.get_content_width()

		if content_width >= 宽度最大值:
			回答内容.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			回答内容.custom_minimum_size.x = 宽度最大值  # 设置 RichTextLabel 的最小宽度
		else:
			回答内容.autowrap_mode = TextServer.AUTOWRAP_OFF
			回答内容.custom_minimum_size.x = 0  # 取消最小宽度限制

func _on_h_box_container_resized() -> void:
	if h_box_container:
		custom_minimum_size.y = h_box_container.size.y

func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		DisplayServer.clipboard_set(回答内容.text)
		print("复制成功")

func _on_texture_rect_2_gui_input(event: InputEvent) -> void:
	pass # Replace with function body.
