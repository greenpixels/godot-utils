extends Control
@export var clickable = true

var custom_scale : float = 1. :
	set(value): custom_scale = await set_custom_scale(value)
var disabled = false
var focused = false
	
func _ready():
	if get_parent() is Control:
		var control : Control = get_parent()
		control.mouse_entered.connect(_on_button_focus_entered_or_mouse_hovered)
		control.mouse_exited.connect(_on_button_focus_exited_or_mouse_leave)
		control.focus_entered.connect(_on_button_focus_entered_or_mouse_hovered)
		control.focus_exited.connect(_on_button_focus_exited_or_mouse_leave)
		if get_parent() is Button or get_parent() is TextureButton:
			var button = control
			button.button_down.connect(_on_button_down)
			button.button_up.connect(_on_button_up)

func _on_button_focus_entered_or_mouse_hovered():
	if disabled or focused: return
	focused = true
	TweenHelper.tween("scale", self).tween_property(self, "custom_scale", 0.97, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _on_button_focus_exited_or_mouse_leave():
	if not focused: return
	get_parent().modulate.v = 1
	focused = false
	TweenHelper.tween("scale",self).tween_property(self, "custom_scale", 1, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func set_custom_scale(value: float):
	get_parent().scale = Vector2(value, value)
	get_parent().pivot_offset = get_parent().get_rect().size / 2.
	return value

func _on_button_down():
	if not clickable: return
	if disabled: return
	get_parent().modulate.v = 0.75
	TweenHelper.tween("scale", self).tween_property(self, "custom_scale", 0.95, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _on_button_up():
	if not clickable: return
	get_parent().modulate.v = 1
	if disabled: return
	TweenHelper.tween("scale", self).tween_property(self, "custom_scale", 0.97, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
