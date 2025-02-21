extends Control

@onready var 数据: Control = $数据
@onready var 对话列表: VBoxContainer = $"背景/UI/右侧/右侧_间距/右侧_列表/聊天区域/MarginContainer/滚动容器/聊天列表"
@onready var 输入: TextEdit = $"背景/UI/右侧/右侧_间距/右侧_列表/底部区域/聊天区域列表/输入区域/MarginContainer/输入区域排列/文字输入"
@onready var 暂停节点: TextureButton = $"背景/UI/右侧/右侧_间距/右侧_列表/底部区域/聊天区域列表/输入区域/MarginContainer/输入区域排列/功能/输出/暂停"
@onready var 发送节点: TextureButton = $"背景/UI/右侧/右侧_间距/右侧_列表/底部区域/聊天区域列表/输入区域/MarginContainer/输入区域排列/功能/输出/发送"
@onready var 输入区域: PanelContainer = $"背景/UI/右侧/右侧_间距/右侧_列表/底部区域/聊天区域列表/输入区域"
@onready var 标题: LineEdit = $"背景/UI/右侧/右侧_间距/右侧_列表/头部/HBoxContainer/Control/顶部栏标题/标题"
@onready var 滚动容器: ScrollContainer = $背景/UI/右侧/右侧_间距/右侧_列表/聊天区域/滚动容器
@onready var 聊天区域: Control = $背景/UI/右侧/右侧_间距/右侧_列表/聊天区域
@onready var 引导词: Label = $背景/UI/右侧/右侧_间距/右侧_列表/底部区域/聊天区域列表/引导词/文案
@onready var 底部区域: MarginContainer = $背景/UI/右侧/右侧_间距/右侧_列表/底部区域
@onready var 会话id输入: LineEdit = $会话ID输入
@onready var 消息id输入: LineEdit = $消息ID输入
@onready var 记录: VBoxContainer = $背景/UI/左侧/VBoxContainer/聊天记录/聊天记录/ScrollContainer/VBoxContainer/记录

var AI_ID:int
var 视觉行数 := 0
var 行高

var 用户提问 := preload("res://Scene/对话框.tscn")
var AI回答 := preload("res://Scene/ai回答.tscn")
var 输入区域高度
var 输入框高度
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("检测"):
		print("当前平台:", Global.平台列表[0],"当前模型:",Global.当前模型 )

func _ready() -> void:
	if Global.会话库 == {  }:
		Global.创建新会话()
	Global.设置节点(暂停节点, 发送节点)
	输入区域高度 = 输入区域.custom_minimum_size.y
	输入框高度 = 输入.custom_minimum_size.y
	数据.connect("标题创建完成", Callable(self, "_on_标题创建"))
	记录.文案.text = Global.会话库[1].标题
	
func _on_发送_button_down() -> void:
	发送消息()
func _on_文字输入_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:  # 确保是键盘按下事件
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			# Ctrl + Enter：在 TextEdit 插入换行
			输入.insert_text_at_caret("\n")
			accept_event()  # 阻止事件继续传播
		elif event.keycode == KEY_ENTER:
			# 只有 Enter：执行你的默认 Enter 逻辑
			发送消息()
			accept_event()  # 阻止事件继续传播
	var 换行数量 = 输入.text.count("\n")
	视觉行数 = 输入.get_line_wrap_count(0)+换行数量
	行高 = int(输入.get_line_height() * 视觉行数)
	if 视觉行数 <= 4:
		输入区域.custom_minimum_size.y = 输入区域高度+行高
		输入.custom_minimum_size.y = 输入框高度+行高
		
func 发送消息():
	if 输入.text.strip_edges() == "":  # 更严格的空内容检查
		print("请输入有效内容")
		return
	Global.输出状态(true)
	# 获取并处理用户输入
	var 用户消息 = 输入.text
	var 实例化用户 = 用户提问.instantiate()
	对话列表.add_child(实例化用户)
	
	var 实例化AI = AI回答.instantiate()
	对话列表.add_child(实例化AI)
	
	# 创建新记录（带安全检查）
	var AI消息_ID: int
	var 用户消息_ID: int
	
	if 实例化AI is Control:  # 类型检查
		AI消息_ID = Global.添加AI消息("回答中...", 实例化AI)
		print(AI消息_ID)
	else:
		push_error("AI实例化失败！")
		return
	if 实例化用户 is Control:  # 类型检查
		用户消息_ID = Global.添加用户消息(用户消息, 实例化用户)
		print(用户消息_ID)
	else:
		push_error("用户实例化失败！")
		return
	
	# 初始化界面元素
	实例化用户.设置回答内容(用户消息_ID)
	实例化用户.name = "用户消息_ID" + str(用户消息_ID)
	实例化AI.设置回答内容(AI消息_ID)  # 先显示加载状态
	实例化AI.name = "AI消息_ID" + str(AI消息_ID)
	AI_ID = AI消息_ID
	# 发起请求（增加超时保护）
	#var 超时计时器 = get_tree().create_timer(30.0)  # 30秒超时
	#超时计时器.timeout.connect(func(): 
		#if Global.消息库.has(AI消息_ID) and Global.消息库[AI消息_ID]["内容"] == "回答中..." :
			#Global.消息库[AI消息_ID]["内容"] = "请求超时，请重试"
			#Global.输出状态(false)
			#实例化AI.设置回答内容(AI消息_ID)
	#)
	数据.发起提问(用户消息, AI消息_ID)
	输入.text = ""  # 清空输入框
	#数据.更新时间()

#region 消息库
	if Global.消息库 != null:
		聊天区域.visible = true
		引导词.visible = false
		底部区域.size_flags_vertical = Control.SIZE_SHRINK_END

	# 智能清理历史记录（适配字典结构）
	if Global.消息库.size() > 20:
		var 所有ID = Global.消息库.keys()
		所有ID.sort()  # 按ID升序排列
		# 清理最早的5条记录
		for i in range(min(5, 所有ID.size())):
			var 待删除ID = 所有ID[i]
			# 安全移除实例
			if Global.消息库[待删除ID].has("实例化AI"):
				var 旧实例 = Global.消息库[待删除ID]["实例化AI"]
				if is_instance_valid(旧实例):
					旧实例.queue_free()
			# 移除记录
			Global.消息库.erase(待删除ID)
#endregion

#func _on_文字输入_text_changed() -> void:
	#var 换行数量 = 输入.text.count("\n")
	#视觉行数 = 输入.get_line_wrap_count(0)+换行数量
	#行高 = int(输入.get_line_height() * 视觉行数)
	#if 视觉行数 <= 4:
		#输入区域.custom_minimum_size.y = 输入区域高度+行高
		#输入.custom_minimum_size.y = 输入框高度+行高

func _on_标题创建():
	标题.text = Global.对话标题
	记录.文案.text = Global.会话库[1].标题
	print("标题更改")

func _on_button_button_down() -> void:
	var 会话_id = 会话id输入.text
	var 消息_id = 消息id输入.text
	if 会话_id == "":
		print("请输入会话ID")
	elif 消息_id == "":
		print(Global.会话库[int(会话_id)])
	elif 会话_id != "" and 消息_id != "":
		print(Global.会话库[int(会话_id)].消息列表[int(消息_id)])


func _on_暂停_button_down() -> void:
	数据._超时处理(AI_ID,"已取消")
	print("ID:",AI_ID)
