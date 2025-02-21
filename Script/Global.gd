extends Node
@onready var 数据: Control = $数据

#region 参数
var 数据保存 = QA_DATA.new()
var 暂停: TextureButton
var 发送: TextureButton
var 时间:String
var Chat按钮状态:bool
signal 标题状态(引导词: String, 会话id: int)
var AI设定 := "You are a helpful assistant"
var API_KEY = {
	"deepseek": "sk-c7e539244ffd490ead63b5c1ba8491ba",
	"openai":"sk-czpacf79c051d745677a11b0ebdba0a5927e648915f9KwU2",
	"gemini":"AIzaSyAkbCVUGbdiAzQQkCZf2DzCGLkjKrfUHgg"
}
var 模型库 = {
	"openai":{
		"gpt-4o": "gpt-4o",
		"gpt-4o-mini": "gpt-4o-mini",
		"gpt-4-turbo": "gpt-4-turbo",
		"gpt-4": "gpt-4",
		"deepseek-r1":"deepseek-r1",
	},
	"deepseek":{
		"deepseek-chat": "deepseek-chat",
	},
	"gemini":{
		"gemini-2.0-flash": "deepseek-chat",
	},
}
var 平台列表 = 模型库.keys()
var 当前平台 = 平台列表[0]
var 当前模型 = 模型库[当前平台]["deepseek-r1"]
var 对话标题 = ""
var 引导词 = "根据以下对话内容，总结一个简短的标题且只需要回复总结后的标题不要说多余的话（不超过 22 个字）："
# API 配置
var api_配置 = {
	"deepseek": {
		"url": "https://api.deepseek.com/v1/chat/completions",
		"headers": ["Authorization: Bearer ", "Content-Type: application/json"],
		"body": {
			"model": "deepseek-chat",
			"messages": [],
			"stream": false
		}
	},
	"gemini": {
		"url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=GEMINI_API_KEY",
		"headers": ["Content-Type: application/json"],
		"body": {
			"contents": [{
				"parts": [{"text": ""}]
			}]
		}
	},
	"openai": {
		"url": "https://api.gptsapi.net/v1/chat/completions",
		"headers": ["Authorization: Bearer ", "Content-Type: application/json"],
		"body": {
			"model": 当前模型,
			"messages": []
		}
	}
}
#endregion

#region 核心数据存储
var 会话库: Dictionary = {}       # {会话ID: 会话对象}
var 消息库: Dictionary = {}       # {消息ID: 消息对象}
var 当前会话_id: int = 0          # 当前活动的会话ID
var id生成器: int = 0        # 统一ID生成器
#endregion

#region 按扭状态
func 设置节点(暂停节点: TextureButton, 发送节点: TextureButton):
	暂停 = 暂停节点
	发送 = 发送节点
	print("节点已设置:", 暂停, 发送)

func 输出状态(状态:bool):
	if 状态 == false:
		Chat按钮状态 = false
		暂停.visible = false
		发送.visible = true
	elif 状态 == true:
		Chat按钮状态 = true
		暂停.visible = true
		发送.visible = false
	else:
		print("节点未初始化")
#endregion

#region 数据结构类
class 会话数据:
	var id: int
	var 标题: String
	var 创建时间: String
	var 最后互动时间: String
	var 消息列表: Array[int]     # 存储消息ID
	var 平台: String
	var 模型: String
	
	func 初始化(p_id: int, p_标题: String, p_平台: String, p_模型: String):
		id = p_id
		标题 = p_标题
		创建时间 = Time.get_datetime_string_from_system()
		消息列表 = []
		平台 = p_平台
		模型 = p_模型

class 消息数据:
	enum 消息类型 {用户, AI}
	
	var id: int
	var 内容: String
	var 时间戳: String
	var 发送者类型: int        # 使用枚举类型
	var 会话id: int           # 所属会话ID
	var 是否完成: bool        # 是否已完成（用于流式响应）
	var 实例化节点: Control
	func 初始化(p_id: int, p_内容: String, p_类型: int, p_会话id: int, p_实例化节点: Control):
		id = p_id
		内容 = p_内容
		时间戳 = Time.get_time_string_from_system()
		发送者类型 = p_类型
		会话id = p_会话id
		实例化节点 = p_实例化节点
		是否完成 = false
#endregion

#region 会话管理
func 创建新会话() -> int:
	var 新id = _生成唯一ID()
	var 新会话 = 会话数据.new()
	新会话.初始化(新id, "新对话", 当前平台, 当前模型)  # 再调用 _init
	会话库[新id] = 新会话
	当前会话_id = 新id
	#_自动生成标题(新id) # 异步生成标题
	print("创建新会话:",新id)
	return 新id

func 切换会话(会话id: int) -> bool:
	if 会话库.has(会话id):
		当前会话_id = 会话id
		return true
	push_error("尝试切换不存在的会话: %d" % 会话id)
	return false

func 删除会话(会话id: int) -> void:
	if 会话库.erase(会话id):
		# 清理关联的消息
		for 消息id in 消息库.keys():
			if 消息库[消息id].会话id == 会话id:
				消息库.erase(消息id)
	else:
		push_error("尝试删除不存在的会话: %d" % 会话id)
		
#endregion

#region 消息管理
func 添加用户消息(内容: String, 实例化节点: Control) -> int:
	return _添加消息(内容, 消息数据.消息类型.用户,实例化节点)

func 添加AI消息(内容: String, 实例化节点: Control) -> int:
	return _添加消息(内容, 消息数据.消息类型.AI, 实例化节点)

func 更新消息内容(消息id: int, 新内容: String) -> void:
	print("更新内容")
	if 消息库.has(消息id):
		消息库[消息id].内容 += 新内容
	else:
		push_error("尝试更新不存在的消息: %d" % 消息id)

func 标记消息完成(消息id: int) -> void:
	if 消息库.has(消息id):
		消息库[消息id].是否完成 = true
	else:
		push_error("尝试标记不存在的消息: %d" % 消息id)

# 更新消息的函数
func 更新AI消息(消息id: int, 内容: String):
	if 消息库.has(消息id):
		消息库[消息id].内容 = 内容  # 直接通过消息ID更新
		消息库[消息id]["实例化节点"].设置回答内容(消息id)
	else:
		push_error("消息ID不存在: " + str(消息id))
#endregion

#region 私有方法
func _生成唯一ID() -> int:
	id生成器 += 1
	print("生成新ID:",id生成器)
	return id生成器


func _添加消息(内容: String, 发送者类型: int, a_实例化节点: Control) -> int:
	var 发送者:String
	if 发送者类型 == 1:
		发送者 = "AI发送"
	elif 发送者类型 == 0:
		发送者 = "用户发送"
		
	if 当前会话_id == 0:
		创建新会话()
		print("创建新会话"," ","会话ID：",当前会话_id)
	var 新id = _生成唯一ID()
	var 新消息 = 消息数据.new()
	新消息.初始化(新id, 内容, 发送者类型, 当前会话_id, a_实例化节点)  # 再调用 _init
	
	消息库[新id] = 新消息
	会话库[当前会话_id].消息列表.append(新id)
	print("创建新消息"," ","发送者类型:",发送者," ","消息ID：",新id)

	# 关联到会话
	var 当前会话: 会话数据 = 会话库.get(当前会话_id)
	if 当前会话:
		当前会话.最后互动时间 = Time.get_datetime_string_from_system()
		# 检查是否需要生成标题
		if 会话库[1].消息列表.size() == 6:
			print("开生成标题")
			_异步生成标题(当前会话_id)  # 异步调用生成标题
		else :
			print("消息列表未达到6,当前数量是:",会话库[1].消息列表.size(),"打印列表",会话库[1].消息列表)
	return 新id

func _异步生成标题(会话id: int) -> void:
	# 获取会话数据
	var 会话: 会话数据 = 会话库.get(会话id)
	if not 会话:
		print("不存在会话，当前传入会话为:",会话库.get(会话id),"会话ID为",会话id)
		return
	# 检查是否已有标题（避免重复生成）
	if 会话.标题 != "新对话":
		print("标题为空",会话.标题)
		return
	# 提取最近的 N 条消息内容
	var 上下文内容 := ""
	var 消息数量 = min(会话.消息列表.size(), 20)
	for i in range(会话.消息列表.size() - 消息数量, 会话.消息列表.size()):
		var 消息id: int = 会话.消息列表[i]
		var 消息: 消息数据 = 消息库.get(消息id)
		if 消息:
			上下文内容 += "%s: %s\n" % ["用户" if 消息.发送者类型 == 消息数据.消息类型.用户 else "AI", 消息.内容]
	# 构建引导词
	var 完整引导词 = Global.引导词 + "\n\n" + 上下文内容
	# 调用生成标题方法
	emit_signal("标题状态", 完整引导词,会话id) 
	print("标题状态信号触发！")
# 在Global脚本中添加清理方法
func 清理无效记录():
	var 有效消息id列表 = []
	var 有效会话id列表 = []
	
	# 清理无效消息
	for 消息id in 消息库.keys():
		var 消息 = 消息库[消息id]
		if 消息 is 消息数据 and 会话库.has(消息.会话id):
			有效消息id列表.append(消息id)
		else:
			print("发现无效消息记录：", 消息id)
	
	# 清理无效会话
	for 会话id in 会话库.keys():
		var 会话 = 会话库[会话id]
		if 会话 is 会话数据:
			有效会话id列表.append(会话id)
		else:
			print("发现无效会话记录：", 会话id)
	# 重建有效记录字典
	var 新消息库 = {}
	for 消息id in 有效消息id列表:
		新消息库[消息id] = 消息库[消息id]
	消息库 = 新消息库
	
	var 新会话库 = {}
	for 会话id in 有效会话id列表:
		新会话库[会话id] = 会话库[会话id]
	会话库 = 新会话库
	print("清理完成：剩余消息数 =", 消息库.size(), "剩余会话数 =", 会话库.size())
	
const 最大重试次数: int = 2
var _当前重试次数: int = 0

#endregion

#region 备选功能
func _超时处理(消息ID: int) -> void:
	if _当前重试次数 < 最大重试次数:
		_当前重试次数 += 1
		#发起提问(Global.消息库[消息ID]["内容"], 消息ID)
	else:
		pass
	
func _设置超时监控(消息ID: int) -> void:
	var 超时时间 = 30.0
	match Global.当前平台:
		"gemini": 超时时间 = 45.0
		"openai": 超时时间 = 25.0
	#_当前超时计时器 = get_tree().create_timer(超时时间)
#endregion

func _save() -> void:
	ResourceSaver.save(数据保存,"User://ChatDATA")
