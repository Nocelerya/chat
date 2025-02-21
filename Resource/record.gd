extends Resource
class_name QA_DATA

@export var 当前会话:int

# 数据结构
@export var 会话管理 = {
	# 结构示例：
	# 1: {
	#     "标题": "对话标题", 
	#     "创建时间": "2024-05-20", 
	#     "消息列表": [1,2,3], 
	#     "当前模型": "gpt-4o",
	#     "平台": "openai"
	# }
}

@export var 消息库 = {
	# 结构示例：
	# 1: {
	#     "类型": "用户/AI", 
	#     "内容": "消息内容", 
	#     "时间": "12:00", 
	#     "实例化节点": Control
	# }
}
var API_KEY = {
	"deepseek": "sk-c7e539244ffd490ead63b5c1ba8491ba",
	"openai":"sk-czpacf79c051d745677a11b0ebdba0a5927e648915f9KwU2",
	"gemini":"AIzaSyAkbCVUGbdiAzQQkCZf2DzCGLkjKrfUHgg"
}
var 模型库 = {
	"openai":{
		"name": "openai",
		"gpt-4o": "gpt-4o",
		"gpt-4o-mini": "gpt-4o-mini",
		"gpt-4-turbo": "gpt-4-turbo",
		"gpt-4": "gpt-4"
	}
}

@export var 聊天记录实例 : Array[PackedScene]
