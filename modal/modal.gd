@tool
extends PanelContainer

@export var title : String = "" :
	set(value):
		title = value
		if not is_node_ready():
			await ready
		%TitleLabel.text = title
var original_position : Vector2

func _enter_tree() -> void:
	visibility_changed.connect(_on_show_or_hide)

func _exit_tree() -> void:
	visibility_changed.disconnect(_on_show_or_hide)

func _ready() -> void:
	original_position = position

func _on_show_or_hide():
	if Engine.is_editor_hint(): return
	position = Vector2(position.x, position.y + 400)
	if is_visible_in_tree():
		TweenHelper.tween("move_in", self).tween_property(self, "position", original_position, 0.5)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)

func _on_okay_button_pressed() -> void:
	hide()
