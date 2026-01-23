@tool
class_name HorizontalSelect
extends HBoxContainer

@onready var icon : TextureRect = %Icon
@onready var text : RichTextLabel = %Text

@export var options : Array[HorizontalSelectEntry] = []
@export var current_index = 0 :
	set(value):
		var new_value = clamp(value, 0, options.size() - 1)
		if current_index == new_value: return
		current_index = new_value
		if options.size() <= 0: return
		on_change.emit(current_index, options[current_index])
		_on_index_change()

signal on_change(index: int, option: HorizontalSelectEntry)

func _ready() -> void:
	_on_index_change()

func _on_index_change():
	%Text.text = options[current_index].label
	if options[current_index].icon:
		%Icon.texture = options[current_index].icon
		%Icon.show()
	else:
		%Icon.texture = null
		%Icon.hide()
	
	%ChevronLeft.modulate.a = 0.5 if current_index == 0 else 1
	%ChevronRight.modulate.a = 0.5 if current_index == options.size() - 1 else 1
		
func _on_chevron_left_pressed() -> void:
	current_index -= 1

func _on_chevron_right_pressed() -> void:
	current_index += 1
