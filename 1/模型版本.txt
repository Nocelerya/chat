extends OptionButton

func _ready() -> void:
	var 当前模型 = Global.当前模型
	for key in Global.模型库[Global.当前平台]:
		var index = item_count  # 获取当前将要添加的索引位置
		add_item(Global.模型库[Global.当前平台][key])  # 添加显示文本
		set_item_metadata(index, key)  # 将字典键存入元数据
	selected = 4

func _on_item_selected(index: int) -> void:
	var 更改模型 = get_item_text(index)
	Global.当前模型 = Global.模型库[Global.当前平台][更改模型]
