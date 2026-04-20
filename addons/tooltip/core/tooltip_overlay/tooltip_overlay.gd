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
## Offset from the cursor when using cursor-following mode.
@export var cursor_offset: Vector2 = Vector2(16, 16)

## Preloaded tooltip scene used for creating explanation popover instances.
var tooltip_scene: PackedScene = preload("res://addons/tooltip/core/tooltip/tooltip.tscn")
## Reference to the CanvasItem currently triggering the tooltip display.
var current_tooltip_element: CanvasItem = null
## Array of instantiated explanation tooltip nodes currently being displayed.
var explanations: Array[Node] = []
## Whether the tooltip is currently following the cursor.
var _is_following_cursor: bool = false


func _ready() -> void:
	%LayoutWrapper.scale = Vector2(0, 1)
	set_process(false)


func _process(_delta: float) -> void:
	if _is_following_cursor:
		_update_cursor_position()


## Hides the tooltip overlay with a scale-out animation and disconnects from the current element.
func conceal() -> void:
	_disconnect_tooltip_element(current_tooltip_element)
	current_tooltip_element = null
	_is_following_cursor = false
	set_process(false)
	(
		TweenHelper
		. tween("tooltip_container_scale", %LayoutWrapper)
		. tween_property(%LayoutWrapper, "scale", Vector2(0, 1), 0.05)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


## Displays a tooltip for the given origin node with the specified content.
## [param origin_node]: The CanvasItem that triggered the tooltip (used for positioning and exit detection).
## [param content]: The text content to display, supporting BBCode and placeholder keys.
## [param show_extra_explanation]: If true, displays additional explanation popovers for highlighted keys.
func describe(origin_node: CanvasItem, content: String, show_extra_explanation: bool = false) -> void:
	_is_following_cursor = false
	set_process(false)
	_setup_tooltip_element(origin_node)
	_prepare_tooltip_content(content, show_extra_explanation)

	var origin_x_position: float = 0
	if origin_node:
		origin_x_position = _get_screen_position(origin_node).x
	var viewport_center_position: float = get_viewport().get_visible_rect().size.x / 2

	if origin_x_position > viewport_center_position:
		%LayoutWrapper.set_anchors_and_offsets_preset(
			Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_WIDTH
		)
	else:
		%LayoutWrapper.set_anchors_and_offsets_preset(
			Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_WIDTH
		)

	_animate_tooltip_in()


## Displays a tooltip that follows the cursor position.
## The tooltip automatically positions itself to avoid screen overflow.
## [param origin_node]: The CanvasItem that triggered the tooltip (used for exit detection).
## [param content]: The text content to display, supporting BBCode and placeholder keys.
## [param show_extra_explanation]: If true, displays additional explanation popovers for highlighted keys.
func describe_at_cursor(
	origin_node: CanvasItem, content: String, show_extra_explanation: bool = false
) -> void:
	_is_following_cursor = true
	_setup_tooltip_element(origin_node)
	_prepare_tooltip_content(content, show_extra_explanation)

	# Reset anchors for manual positioning
	%LayoutWrapper.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE
	)

	# Initial position update
	_update_cursor_position()

	_animate_tooltip_in()
	set_process(true)


## Displays a tooltip anchored to a specific canvas item position.
## Control nodes use their full rect, while other CanvasItems anchor from their screen position.
## [param origin_node]: The CanvasItem that triggered the tooltip (used for positioning and exit detection).
## [param content]: The text content to display, supporting BBCode and placeholder keys.
## [param show_extra_explanation]: If true, displays additional explanation popovers for highlighted keys.
func describe_at_position(
	origin_node: CanvasItem, content: String, show_extra_explanation: bool = false
) -> void:
	_is_following_cursor = false
	set_process(false)
	_setup_tooltip_element(origin_node)
	_prepare_tooltip_content(content, show_extra_explanation)

	%LayoutWrapper.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE
	)

	await get_tree().process_frame
	_update_canvas_item_position(origin_node)

	_animate_tooltip_in()


## Displays a tooltip anchored to a specific control node.
## The tooltip positions itself adjacent to the control, avoiding screen overflow.
## [param origin_node]: The Control node that triggered the tooltip (used for positioning and exit detection).
## [param content]: The text content to display, supporting BBCode and placeholder keys.
## [param show_extra_explanation]: If true, displays additional explanation popovers for highlighted keys.
func describe_at_control(
	origin_node: Control, content: String, show_extra_explanation: bool = false
) -> void:
	describe_at_position(origin_node, content, show_extra_explanation)


## Sets up the tooltip element connection for mouse exit detection.
## [param origin_node]: The CanvasItem to connect exit signals from.
func _setup_tooltip_element(origin_node: CanvasItem) -> void:
	_disconnect_tooltip_element(current_tooltip_element)
	current_tooltip_element = origin_node
	_connect_tooltip_element(current_tooltip_element)


func _connect_tooltip_element(origin_node: CanvasItem) -> void:
	if not is_instance_valid(origin_node):
		return

	var conceal_callable: Callable = Callable(self, "conceal")
	if origin_node.has_signal(&"mouse_exited") and not origin_node.is_connected(
		&"mouse_exited", conceal_callable
	):
		origin_node.connect(&"mouse_exited", conceal_callable)
	if origin_node.has_signal(&"focus_exited") and not origin_node.is_connected(
		&"focus_exited", conceal_callable
	):
		origin_node.connect(&"focus_exited", conceal_callable)


func _disconnect_tooltip_element(origin_node: CanvasItem) -> void:
	if not is_instance_valid(origin_node):
		return

	var conceal_callable: Callable = Callable(self, "conceal")
	if origin_node.has_signal(&"mouse_exited") and origin_node.is_connected(
		&"mouse_exited", conceal_callable
	):
		origin_node.disconnect(&"mouse_exited", conceal_callable)
	if origin_node.has_signal(&"focus_exited") and origin_node.is_connected(
		&"focus_exited", conceal_callable
	):
		origin_node.disconnect(&"focus_exited", conceal_callable)


## Prepares the tooltip content, loading bar, and explanation fade-in animations.
## [param content]: The text content to display.
## [param show_extra_explanation]: If true, creates explanation popovers.
func _prepare_tooltip_content(content: String, show_extra_explanation: bool) -> void:
	%TooltipLoadingBar.value = 0
	TweenHelper.tween("load_progress", %TooltipLoadingBar).tween_property(
		%TooltipLoadingBar, "value", 0, 0
	)
	__cleanup()
	%MainTooltip.set_description(apply_bbcode_for_common_keys(content, show_extra_explanation))
	if not explanations.is_empty():
		TweenHelper.tween("load_progress", %TooltipLoadingBar).tween_property(
			%TooltipLoadingBar, "value", 100, explanations_delay
		)

	for explanation in explanations:
		var current_modulate: Color = explanation.modulate
		explanation.modulate.a = 0
		(
			TweenHelper
			. tween("fade_in", explanation)
			. tween_property(explanation, "modulate", current_modulate, 0.15)
			. set_delay(explanations_delay)
		)


## Animates the tooltip container scaling in.
func _animate_tooltip_in() -> void:
	%TooltipContainer.scale = Vector2(1, 1)
	%LayoutWrapper.scale = Vector2(0, 1)
	(
		TweenHelper
		. tween("tooltip_container_scale", %LayoutWrapper)
		. tween_property(%LayoutWrapper, "scale", Vector2(1, 1), 0.25)
		. set_trans(tooltip_transition_type)
		. set_ease(tooltip_easing_type)
	)


## Updates the tooltip position to follow the cursor, avoiding screen overflow.
func _update_cursor_position() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tooltip_size: Vector2 = %LayoutWrapper.size

	# Calculate available space in each direction
	var space_right: float = viewport_size.x - mouse_pos.x
	var space_left: float = mouse_pos.x
	var space_bottom: float = viewport_size.y - mouse_pos.y
	var space_top: float = mouse_pos.y

	var target_pos: Vector2 = mouse_pos

	# Determine horizontal position
	if space_right >= tooltip_size.x + cursor_offset.x:
		# Place to the right of cursor
		target_pos.x = mouse_pos.x + cursor_offset.x
	elif space_left >= tooltip_size.x + cursor_offset.x:
		# Place to the left of cursor
		target_pos.x = mouse_pos.x - tooltip_size.x - cursor_offset.x
	else:
		# Not enough space on either side, clamp to viewport
		target_pos.x = clampf(mouse_pos.x + cursor_offset.x, 0, viewport_size.x - tooltip_size.x)

	# Determine vertical position
	if space_bottom >= tooltip_size.y + cursor_offset.y:
		# Place below cursor
		target_pos.y = mouse_pos.y + cursor_offset.y
	elif space_top >= tooltip_size.y + cursor_offset.y:
		# Place above cursor
		target_pos.y = mouse_pos.y - tooltip_size.y - cursor_offset.y
	else:
		# Not enough space, clamp to viewport
		target_pos.y = clampf(mouse_pos.y + cursor_offset.y, 0, viewport_size.y - tooltip_size.y)

	%LayoutWrapper.position = target_pos


## Positions the tooltip adjacent to the given control, avoiding screen overflow.
## Prefers placing the tooltip to the right of the control, falling back to left, below, or above.
## [param control]: The Control node to anchor the tooltip to.
func _update_control_position(control: Control) -> void:
	_update_canvas_item_position(control)


## Positions the tooltip adjacent to the given canvas item, avoiding screen overflow.
## Control nodes use their full rect; other CanvasItems anchor from their screen position.
## [param canvas_item]: The CanvasItem to anchor the tooltip to.
func _update_canvas_item_position(canvas_item: CanvasItem) -> void:
	var item_rect: Rect2 = _get_canvas_item_screen_rect(canvas_item)
	var control_pos: Vector2 = item_rect.position
	var control_size: Vector2 = item_rect.size
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tooltip_size: Vector2 = %LayoutWrapper.size

	var space_right: float = viewport_size.x - (control_pos.x + control_size.x)
	var space_left: float = control_pos.x
	var space_below: float = viewport_size.y - (control_pos.y + control_size.y)
	var space_above: float = control_pos.y

	var target_pos: Vector2

	if space_right >= tooltip_size.x:
		target_pos.x = control_pos.x + control_size.x
		target_pos.y = clampf(control_pos.y, 0.0, viewport_size.y - tooltip_size.y)
	elif space_left >= tooltip_size.x:
		target_pos.x = control_pos.x - tooltip_size.x
		target_pos.y = clampf(control_pos.y, 0.0, viewport_size.y - tooltip_size.y)
	elif space_below >= tooltip_size.y:
		target_pos.x = clampf(control_pos.x, 0.0, viewport_size.x - tooltip_size.x)
		target_pos.y = control_pos.y + control_size.y
	elif space_above >= tooltip_size.y:
		target_pos.x = clampf(control_pos.x, 0.0, viewport_size.x - tooltip_size.x)
		target_pos.y = control_pos.y - tooltip_size.y
	else:
		target_pos = Vector2(
			clampf(control_pos.x + control_size.x, 0.0, viewport_size.x - tooltip_size.x),
			clampf(control_pos.y, 0.0, viewport_size.y - tooltip_size.y)
		)

	%LayoutWrapper.position = target_pos


## Applies BBCode formatting to content by replacing placeholder keys with styled text.
## [param content]: The raw content string containing placeholder keys like {key_name}.
## [param show_explanations]: If true, also creates explanation popovers for keys that have explanations.
## [returns]: The formatted content with BBCode applied.
func apply_bbcode_for_common_keys(content: String, show_explanations: bool) -> String:
	if show_explanations:
		for highlighted_key in highlighted_keys:
			if highlighted_key.explanation:
				content = add_explanation(
					content,
					"{" + highlighted_key.key + "}",
					highlighted_key.explanation.explanation_tr_key,
					highlighted_key.explanation.should_remove_key,
					"",
					highlighted_key.explanation.is_purchasable
				)

	for highlighted_key in highlighted_keys:
		var replacement_bbcode_builder: BBCodeHelper = BBCodeHelper.build(
			tr(highlighted_key.tr_key).capitalize()
		)
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
func add_explanation(
	current_content: String,
	key_to_replace: StringName,
	explanation: String,
	should_remove_key: bool = false,
	title: String = "",
	is_purchasable: bool = false
) -> String:
	if not current_content.contains(key_to_replace):
		return current_content
	if title.is_empty():
		title = key_to_replace
	var popover: Control = tooltip_scene.instantiate()
	%TooltipContainer.add_child(popover)
	var description_output: String = tr(explanation)

	popover.set_description(
		(
			apply_bbcode_for_common_keys(title, false)
			+ "\n\n"
			+ apply_bbcode_for_common_keys(description_output, false)
		)
	)

	explanations.push_back(popover)

	%TooltipContainer.move_child(popover, 0)
	if should_remove_key:
		current_content = current_content.replace(key_to_replace, "")
	return current_content


## Cleans up all currently displayed explanation tooltips by freeing them and clearing the array.
func __cleanup() -> void:
	for node in explanations:
		node.queue_free()
	explanations = []


## Returns the screen position of a canvas item, accounting for nested subviewports.
## [param canvas_item]: The canvas item to get the screen position for.
## [returns]: The canvas item's position in main window screen coordinates.
func _get_screen_position(canvas_item: CanvasItem) -> Vector2:
	return _get_canvas_item_screen_rect(canvas_item).position


func _get_canvas_item_screen_rect(canvas_item: CanvasItem) -> Rect2:
	if not is_instance_valid(canvas_item):
		return Rect2()
	if canvas_item is Control:
		var control: Control = canvas_item
		return Rect2(_get_canvas_point_screen_position(control, Vector2.ZERO), control.size)
	if canvas_item.has_method("get_rect"):
		var local_rect_variant: Variant = canvas_item.call("get_rect")
		if local_rect_variant is Rect2:
			return _get_transformed_screen_rect(canvas_item, local_rect_variant)
	return Rect2(_get_canvas_point_screen_position(canvas_item, Vector2.ZERO), Vector2.ZERO)


func _get_transformed_screen_rect(canvas_item: CanvasItem, local_rect: Rect2) -> Rect2:
	var top_left: Vector2 = _get_canvas_point_screen_position(canvas_item, local_rect.position)
	var top_right: Vector2 = _get_canvas_point_screen_position(
		canvas_item, Vector2(local_rect.end.x, local_rect.position.y)
	)
	var bottom_left: Vector2 = _get_canvas_point_screen_position(
		canvas_item, Vector2(local_rect.position.x, local_rect.end.y)
	)
	var bottom_right: Vector2 = _get_canvas_point_screen_position(canvas_item, local_rect.end)

	var min_x: float = minf(top_left.x, top_right.x, bottom_left.x, bottom_right.x)
	var min_y: float = minf(top_left.y, top_right.y, bottom_left.y, bottom_right.y)
	var max_x: float = maxf(top_left.x, top_right.x, bottom_left.x, bottom_right.x)
	var max_y: float = maxf(top_left.y, top_right.y, bottom_left.y, bottom_right.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _get_canvas_point_screen_position(canvas_item: CanvasItem, local_point: Vector2) -> Vector2:
	if not is_instance_valid(canvas_item):
		return Vector2.ZERO

	var position: Vector2 = canvas_item.get_global_transform_with_canvas() * local_point
	var viewport: Viewport = canvas_item.get_viewport()

	while viewport and viewport != get_tree().root:
		var viewport_parent: Node = viewport.get_parent()
		if viewport_parent is SubViewportContainer:
			var container: SubViewportContainer = viewport_parent
			var scale: Vector2 = Vector2.ONE
			if container.stretch:
				scale = container.size / Vector2(viewport.size)
			position = position * scale + container.global_position
			viewport = container.get_viewport()
		else:
			break

	return position
