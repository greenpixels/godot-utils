extends CanvasLayer

@export var highlighted_keys: Array[TooltipHighlightedKey]
@export var explanations_delay: float = 1.25
@export var tooltip_transition_type: Tween.TransitionType = Tween.TRANS_ELASTIC
@export var tooltip_easing_type: Tween.EaseType = Tween.EASE_OUT

var tooltip_scene: PackedScene = preload("res://addons/tooltip/core/tooltip/tooltip.tscn")
var current_tooltip_element: Control = null
var explanations: Array[Node] = []

func _ready() -> void:
	%LayoutWrapper.scale = Vector2(0, 1)

func conceal() -> void:
	current_tooltip_element = null
	TweenHelper.tween("tooltip_container_scale", %LayoutWrapper) \
		.tween_property(%LayoutWrapper, "scale", Vector2(0, 1), 0.05) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)

func describe(origin_node: Control, content: String, show_extra_explanation: bool = false) -> void:
	if current_tooltip_element != null:
		current_tooltip_element.mouse_exited.disconnect(conceal)
	current_tooltip_element = origin_node
	if not current_tooltip_element.mouse_exited.is_connected(conceal):
		current_tooltip_element.mouse_exited.connect(conceal)
	var origin_x_position: float = 0
	if origin_node:
		origin_x_position = origin_node.global_position.x
	var viewport_center_position: float = get_viewport().get_visible_rect().size.x / 2
	%TooltipLoadingBar.value = 0
	TweenHelper.tween("load_progress", %TooltipLoadingBar).tween_property(%TooltipLoadingBar, "value", 0, 0)
	__cleanup()
	%MainTooltip.set_description(apply_bbcode_for_common_keys(content, show_extra_explanation))
	if not explanations.is_empty():
		TweenHelper.tween("load_progress", %TooltipLoadingBar).tween_property(%TooltipLoadingBar, "value", 100, explanations_delay)
	
	for explanation in explanations:
		var current_modulate: Color = explanation.modulate
		explanation.modulate.a = 0
		TweenHelper.tween("fade_in", explanation).tween_property(explanation, "modulate", current_modulate, 0.15).set_delay(explanations_delay)
	
	 
	if origin_x_position > viewport_center_position:
		%LayoutWrapper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_WIDTH)
	else:
		%LayoutWrapper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_WIDTH)
	%TooltipContainer.scale = Vector2(1, 1)
	%LayoutWrapper.scale = Vector2(0, 1)
	TweenHelper.tween("tooltip_container_scale", %LayoutWrapper).tween_property(%LayoutWrapper, "scale", Vector2(1, 1), 0.25).set_trans(tooltip_transition_type).set_ease(tooltip_easing_type)

	
func apply_bbcode_for_common_keys(content: String, show_explanations: bool) -> String:
	if show_explanations:
		for highlighted_key in highlighted_keys:
			if highlighted_key.explanation:
				content = add_explanation(content, "{" + highlighted_key.key + "}", highlighted_key.explanation.explanation_tr_key, highlighted_key.explanation.should_remove_key, "", highlighted_key.explanation.is_purchasable, highlighted_key.explanation.skill_key)
		
	for highlighted_key in highlighted_keys:
		var replacement_bbcode_builder: BBCodeHelper = BBCodeHelper.build(tr(highlighted_key.tr_key).capitalize())
		if highlighted_key.icon:
			replacement_bbcode_builder = replacement_bbcode_builder.add_icon(highlighted_key.icon)
		replacement_bbcode_builder.color("#" + highlighted_key.color.to_html(true))
		content = content.format({highlighted_key.key: replacement_bbcode_builder.result()})
	content.strip_edges()

	return content

func add_explanation(current_content: String, key_to_replace: StringName, explanation: String, should_remove_key: bool = false, title: String = "", is_purchasable: bool = false, skill_key = "") -> String:
	if not current_content.contains(key_to_replace): return current_content
	if title.is_empty(): title = key_to_replace
	var popover: Control = tooltip_scene.instantiate()
	%TooltipContainer.add_child(popover)
	var description_output: String = tr(explanation)
		
	popover.set_description(
		apply_bbcode_for_common_keys(title, false) +
		"\n\n" +
		apply_bbcode_for_common_keys(description_output, false)
	)
	
	explanations.push_back(popover)
	
	%TooltipContainer.move_child(popover, 0)
	if should_remove_key: current_content = current_content.replace(key_to_replace, "")
	return current_content

func __cleanup() -> void:
	for node in explanations:
		node.queue_free()
	explanations = []
