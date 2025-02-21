extends HBoxContainer
@onready var 文案: Label = $右侧/右侧_间距/右侧_列表/底部区域/聊天区域列表/引导词/文案
@onready var 定时器: Timer = $"../../定时器"
var 当前字符数: int = 0
var 总字符数: int = 10
var 定时速度 := 0.1
func _ready() -> void:
	# 初始化
	文案.visible_characters = 0  # 初始隐藏所有字符
	总字符数 = 文案.text.length()  # 获取文本总长度
	# 启动定时器
	定时器.start(定时速度)  # 每 0.1 秒显示一个字符
	定时器.timeout.connect(self._on_Timer_timeout)
func _on_Timer_timeout():
	if 当前字符数 < 总字符数:
		当前字符数 += 1
		定时速度 -= 0.01
		文案.visible_characters = 当前字符数  # 显示更多字符
	else:
		定时器.stop()  # 停止定时器
		定时速度 = 0.1
