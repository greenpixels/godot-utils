extends Node


func _enter_tree() -> void:
	get_tree().node_added.connect(func(node):
		if "focus_mode" in node and not node is TextEdit:
			node.focus_mode = Control.FOCUS_NONE
	)
