## Overlay layer that manages displaying tooltips with optional explanations and BBCode formatting.
## Handles positioning, animation, and lifecycle of tooltip UI elements.
extends CanvasLayer

## Array of highlighted keys used for BBCode formatting and explanations in tooltips.
@export var highlighted_keys: Array[TooltipHighlightedKey]
## Delay in seconds before explanation tooltips fade in.
@export var explanations_delay: float = 1.25
## Tween transition type used for tooltip show/hide animations.
@export var tooltip_transition_type: Tween.TransitionType = Tween.TRANS_ELASTIC
## Tween easing type used for tooltip show/hide animations.
@export var tooltip_easing_type: Tween.EaseType = Tween.EASE_OUT

## Preloaded tooltip scene used for creating explanation popover instances.
var tooltip_scene: PackedScene = preload("res://addons/tooltip/core/tooltip/tooltip.tscn")
## Reference to the Control node currently triggering the tooltip display.
var current_tooltip_element: Control = null
## Array of instantiated explanation tooltip nodes currently being displayed.
var explanations: Array[Node] = []


func _ready() -> void:
	%LayoutWrapper.scale = Vector2(0, 1)


## Hides the tooltip overlay with a scale-out animation and disconnects from the current element.
func conceal() -> void:
	current_tooltip_element = null
	TweenHelper.tween("tooltip_container_scale", %LayoutWrapper) \
		.tween_property(%LayoutWrapper, "scale", Vector2(0, 1), 0.05) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


## Displays a tooltip for the given origin node with the specified content.
## [param origin_node]: The Control node that triggered the tooltip (used for positioning and mouse exit detection).
## [param content]: The text content to display, supporting BBCode and placeholder keys.
## [param show_extra_explanation]: If true, displays additional explanation popovers for highlighted keys.
func describe(origin_node: Control, content: String, show_extra_explanation: bool = false) -> void:
	if current_tooltip_element != null:
		current_tooltip_element.mouse_exited.disconnect(conceal)
	current_tooltip_element = origin_node
	if not current_tooltip_element.mouse_exited.is_connected(conceal):
		current_tooltip_element.mouse_exited.connect(conceal)
	var origin_x_position: float = 0
	if origin_node:
		origin_x_position = _get_screen_position(origin_node).x
	var viewport_center_position: float = get_viewport().get_visible_rect().size.x / 2
	%TooltipLoadingBar.value = 0
	TweenHelper.tween("load_progress", %TooltipLoadingBar) \
		.tween_property(%TooltipLoadingBar, "value", 0, 0)
	__cleanup()
	%MainTooltip.set_description(apply_bbcode_for_common_keys(content, show_extra_explanation))
	if not explanations.is_empty():
		TweenHelper.tween("load_progress", %TooltipLoadingBar) \
			.tween_property(%TooltipLoadingBar, "value", 100, explanations_delay)

	for explanation in explanations:
		var current_modulate: Color = explanation.modulate
		explanation.modulate.a = 0
		TweenHelper.tween("fade_in", explanation) \
			.tween_property(explanation, "modulate", current_modulate, 0.15) \
			.set_delay(explanations_delay)

	if origin_x_position > viewport_center_position:
		%LayoutWrapper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_WIDTH)
	else:
		%LayoutWrapper.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_WIDTH)
	%TooltipContainer.scale = Vector2(1, 1)
	%LayoutWrapper.scale = Vector2(0, 1)
	TweenHelper.tween("tooltip_container_scale", %LayoutWrapper) \
		.tween_property(%LayoutWrapper, "scale", Vector2(1, 1), 0.25) \
		.set_trans(tooltip_transition_type) \
		.set_ease(tooltip_easing_type)


## Applies BBCode formatting to content by replacing placeholder keys with styled text.
## [param content]: The raw content string containing placeholder keys like {key_name}.
## [param show_explanations]: If true, also creates explanation popovers for keys that have explanations.
## [returns]: The formatted content with BBCode applied.
func apply_bbcode_for_common_keys(content: String, show_explanations: bool) -> String:
	if show_explanations:
		for highlighted_key in highlighted_keys:
			if highlighted_key.explanation:
				content = add_explanation(content, "{" + highlighted_key.key + "}", highlighted_key.explanation.explanation_tr_key, highlighted_key.explanation.should_remove_key, "", highlighted_key.explanation.is_purchasable)

	for highlighted_key in highlighted_keys:
		var replacement_bbcode_builder: BBCodeHelper = BBCodeHelper.build(tr(highlighted_key.tr_key).capitalize())
		if highlighted_key.icon:
			replacement_bbcode_builder = replacement_bbcode_builder.add_icon(highlighted_key.icon)
		replacement_bbcode_builder.color("#" + highlighted_key.color.to_html(true))
		content = content.format({highlighted_key.key: replacement_bbcode_builder.result()})
	content = content.strip_edges()

	return content


## Creates and adds an explanation popover tooltip for a specific key in the content.
## [param current_content]: The content string being processed.
## [param key_to_replace]: The placeholder key to look for (e.g., "{damage}").
## [param explanation]: The translation key for the explanation text.
## [param should_remove_key]: If true, removes the placeholder key from the content after processing.
## [param title]: Optional custom title for the explanation popover.
## [param is_purchasable]: Flag indicating if the explained item is purchasable.
## [returns]: The modified content string.
func add_explanation(current_content: String, key_to_replace: StringName, explanation: String, should_remove_key: bool = false, title: String = "", is_purchasable: bool = false) -> String:
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


## Cleans up all currently displayed explanation tooltips by freeing them and clearing the array.
func __cleanup() -> void:
	for node in explanations:
		node.queue_free()
	explanations = []


## Returns the screen position of a control, accounting for nested viewports.
## Traverses up through any SubViewports to calculate the actual screen position.
## [param control]: The control to get the screen position for.
## [returns]: The control's position in main window screen coordinates.
func _get_screen_position(control: Control) -> Vector2:
	var position: Vector2 = control.global_position
	var viewport: Viewport = control.get_viewport()
	
	# Traverse up through nested viewports until we reach the root
	while viewport and viewport != get_tree().root:
		var viewport_parent: Node = viewport.get_parent()
		if viewport_parent is SubViewportContainer:
			# Account for the SubViewportContainer's position and any scaling
			var container: SubViewportContainer = viewport_parent
			position = position * container.get_transform().get_scale() + container.global_position
			viewport = container.get_viewport()
		else:
			break
	
	return position
