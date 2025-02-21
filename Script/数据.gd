extends Control

@onready var 创建对话框: HTTPRequest = $"创建对话框"
@onready var 提问请求: HTTPRequest = $提问
@onready var 时间请求: HTTPRequest = $"时间请求"
@onready var 标题请求: HTTPRequest = $标题请求
var _当前活动请求: HTTPRequest = null
var _当前超时计时器: SceneTreeTimer  = null
signal 标题创建完成()

var ai_回复消息 := "回答中..."
var 请求地址 = "https://timeapi.io/api/Time/current/zone?timeZone=Asia/Shanghai"
func _ready() -> void:
	Global.connect("标题状态", Callable(self, "生成标题"))
func 生成标题(引导词: String, 会话id: int) -> void:
	更新模型()
	var api_平台 = Global.当前平台
	var 配置 = Global.api_配置.get(api_平台, {})
	
	# 构建请求体（优化为复用现有配置）
	var 请求体 = 配置.get("body", {}).duplicate()
	var 请求头 = 配置.get("headers", []).duplicate()
	
	if api_平台 in ["deepseek", "openai"]:
		请求头[0] += Global.API_KEY.get(api_平台, "")
		请求体["messages"] = [{ "role": "system", "content": 引导词 }]
	
	# 发送异步请求
	var json_请求体 = JSON.stringify(请求体)
	标题请求.request(配置.get("url", ""), 请求头, HTTPClient.METHOD_POST, json_请求体)
	
	# 绑定带参数的信号
	标题请求.request_completed.disconnect(_on_标题_request_completed)
	标题请求.request_completed.connect(_on_标题_request_completed.bind(会话id))  # 绑定会话id
func _on_标题_request_completed(结果: int, 响应码: int, 响应头: PackedStringArray, 响应体: PackedByteArray, 会话id: int) -> void:
	var 会话: Global.会话数据 = Global.会话库.get(会话id)
	if not 会话:
		return
	
	if 结果 == HTTPRequest.RESULT_SUCCESS && 响应码 == 200:
		var 响应字符串 = 响应体.get_string_from_utf8()
		var 响应JSON = JSON.parse_string(响应字符串)
		var 生成的标题 = ""
		
		match Global.当前平台:
			"deepseek", "openai":
				if 响应JSON and 响应JSON.get("choices", []).size() > 0:
					生成的标题 = 响应JSON["choices"][0]["message"]["content"].strip_edges()
					# 清理多余字符（确保只有标题）
					生成的标题 = 生成的标题.split("\n")[0].replace("\"", "").substr(0, 16)
		if 生成的标题:
			# 更新会话标题
			会话.标题 = 生成的标题
			Global.对话标题 = 生成的标题  # 更新全局变量（如果需要）
			print("成功生成标题:", 生成的标题)
			emit_signal("标题创建完成")  # 通知UI更新
	else:
		print("标题生成失败，错误码:", 响应码)

var _当前累积回复 = ""

func 发起提问(用户消息: String, ID: int) -> void:
	更新模型()
	var api_类型 = Global.当前平台
	var 配置 = Global.api_配置.get(api_类型, {})
	var 请求头 = 配置["headers"].duplicate()
	var messages = []
	if api_类型 == "deepseek" or api_类型 == "openai":
		请求头[0] += Global.API_KEY[api_类型]  # 替换为你的API密钥
		messages.append({ "role": "system", "content": Global.AI设定 })
	
	# 添加历史消息
	var 有效IDs = Global.消息库.keys()
	有效IDs.sort()
	var 历史IDs = []
	for id in 有效IDs:
		if id != ID && Global.消息库[id]["内容"] != "回答中...":
			历史IDs.append(id)
	var 最近IDs = 历史IDs.slice(max(0, 历史IDs.size() - 3), 历史IDs.size())
	for history_id in 最近IDs:
		var 记录 = Global.消息库[history_id]
		messages.append({ "role": "user", "content": 记录["内容"] })
		messages.append({ "role": "assistant", "content": 记录["内容"] })
	
	# 添加当前消息
	if api_类型 == "deepseek" or api_类型 == "openai":
		messages.append({ "role": "user", "content": 用户消息 })
		# 启用流式输出
		配置["body"]["stream"] = true
	elif api_类型 == "gemini":
		配置["body"]["contents"][0]["parts"][0]["text"] = 用户消息
	
	# 构建请求体
	var 请求体 = 配置["body"].duplicate()
	if api_类型 == "deepseek" or api_类型 == "openai":
		请求体["messages"] = messages
	
	# 发送请求
	var json_请求体 = JSON.stringify(请求体)
	提问请求.request(配置["url"], 请求头, HTTPClient.METHOD_POST, json_请求体)
	
	# 记录当前请求和计时器
	_当前活动请求 = 提问请求
	_设置超时监控(ID)
	
	# 绑定信号
	提问请求.request_completed.disconnect(_on_提问_request_completed)
	提问请求.request_completed.connect(_on_提问_request_completed.bind(ID, api_类型))

func _设置超时监控(消息ID: int) -> void:
	# 清理之前的计时器
	if _当前超时计时器:
		_当前超时计时器.timeout.disconnect(_超时处理)
	
	# 创建新计时器
	_当前超时计时器 = get_tree().create_timer(30.0)
	_当前超时计时器.timeout.connect(
		_超时处理.bind(消息ID,"请求超时，请重试"), 
		CONNECT_ONE_SHOT # 确保单次触发
	)

func _超时处理(消息ID: int,消息:String) -> void:
	# 如果请求仍在进行中
	if _当前活动请求 and _当前活动请求.get_http_client_status() == HTTPClient.STATUS_REQUESTING:
		_当前活动请求.cancel_request()  # 终止请求
		print("已终止请求")
	# 更新消息状态
	if Global.消息库.has(消息ID) and Global.消息库[消息ID]["内容"] == "回答中...":
		Global.消息库[消息ID]["内容"] = 消息
		print("找到回答"," ",消息)
		Global.输出状态(false)
		Global.消息库[消息ID]["实例化节点"].设置回答内容(消息ID)
	# 清理引用
	#print("请求状态:", _当前活动请求.get_http_client_status())
	
	_当前活动请求 = null
	_当前超时计时器 = null

func _on_提问_request_completed(结果: int, 响应码: int, 响应头: PackedStringArray, 响应体: PackedByteArray, 消息ID: int, api_类型: String) -> void:
	# 如果请求已被取消，直接返回
	if 结果 != HTTPRequest.RESULT_SUCCESS:
		return
	if 结果 == HTTPRequest.RESULT_SUCCESS && 响应码 == 200:
		var 响应字符串 = 响应体.get_string_from_utf8()
		
		if api_类型 == "deepseek" or api_类型 == "openai":
			# 分割响应流
			var 数据块列表 = 响应字符串.split("\n")
			for 数据块 in 数据块列表:
				if 数据块.begins_with("data: "):
					var json字符串 = 数据块.substr(6)  # 移除 "data: " 前缀
					if json字符串 == "[DONE]":
						Global.输出状态(false)
						print("\nAI回答完成\n")
						continue
					
					var 响应JSON = JSON.parse_string(json字符串)
					if 响应JSON and 响应JSON.has("choices"):
						var delta = 响应JSON["choices"][0].get("delta", {})
						if delta.has("content"):
							var 新文本 = delta["content"]
							_当前累积回复 += 新文本
							# 实时更新UI
							Global.更新AI消息(消息ID, _当前累积回复)
			
			# 完成后重置累积回复
			_当前累积回复 = ""
		
		elif api_类型 == "gemini":
			var 响应JSON = JSON.parse_string(响应字符串)
			if 响应JSON and 响应JSON.has("candidates"):
				var AI回复 = 响应JSON["candidates"][0]["content"]["parts"][0]["text"]
				Global.输出状态(false)
				Global.更新AI消息(消息ID, AI回复)
				print("\nAI回答:\n", AI回复, "\n\n当时使用模型:\n", Global.当前模型)

func 更新模型():
	Global.api_配置[Global.当前平台]["body"]["model"] = Global.当前模型
