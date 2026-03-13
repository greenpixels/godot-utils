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
## Reference to the Control node currently triggering the tooltip display.
var current_tooltip_element: Control = null
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
## [param origin_node]: The Control node that triggered the tooltip (used for positioning and mouse exit detection).
## [param content]: The text content to display, supporting BBCode and placeholder keys.
## [param show_extra_explanation]: If true, displays additional explanation popovers for highlighted keys.
func describe(origin_node: Control, content: String, show_extra_explanation: bool = false) -> void:
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
## [param origin_node]: The Control node that triggered the tooltip (used for mouse exit detection).
## [param content]: The text content to display, supporting BBCode and placeholder keys.
## [param show_extra_explanation]: If true, displays additional explanation popovers for highlighted keys.
func describe_at_cursor(
	origin_node: Control, content: String, show_extra_explanation: bool = false
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


## Displays a tooltip anchored to a specific control node.
## The tooltip positions itself adjacent to the control, avoiding screen overflow.
## [param origin_node]: The Control node that triggered the tooltip (used for positioning and mouse exit detection).
## [param content]: The text content to display, supporting BBCode and placeholder keys.
## [param show_extra_explanation]: If true, displays additional explanation popovers for highlighted keys.
func describe_at_control(
	origin_node: Control, content: String, show_extra_explanation: bool = false
) -> void:
	_is_following_cursor = false
	set_process(false)
	_setup_tooltip_element(origin_node)
	_prepare_tooltip_content(content, show_extra_explanation)

	%LayoutWrapper.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE
	)

	await get_tree().process_frame
	_update_control_position(origin_node)

	_animate_tooltip_in()


## Sets up the tooltip element connection for mouse exit detection.
## [param origin_node]: The Control node to connect mouse exit signal from.
func _setup_tooltip_element(origin_node: Control) -> void:
	if (
		current_tooltip_element != null
		and current_tooltip_element.mouse_exited.is_connected(conceal)
	):
		current_tooltip_element.mouse_exited.disconnect(conceal)
	current_tooltip_element = origin_node
	if current_tooltip_element and not current_tooltip_element.mouse_exited.is_connected(conceal):
		current_tooltip_element.mouse_exited.connect(conceal)


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
	var control_pos: Vector2 = _get_screen_position(control)
	var control_size: Vector2 = control.size
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


## Returns the screen position of a control, accounting for nested viewports and cameras.
## Traverses up through any SubViewports to calculate the actual screen position.
## [param control]: The control to get the screen position for.
## [returns]: The control's position in main window screen coordinates.
func _get_screen_position(control: Control) -> Vector2:
	var position: Vector2 = control.global_position
	var viewport: Viewport = control.get_viewport()

	# Account for camera offset within the control's viewport
	var camera: Camera2D = viewport.get_camera_2d()
	if camera:
		position = (
			position - camera.get_screen_center_position() + viewport.get_visible_rect().size / 2
		)

	# Traverse up through nested viewports until we reach the root
	while viewport and viewport != get_tree().root:
		var viewport_parent: Node = viewport.get_parent()
		if viewport_parent is SubViewportContainer:
			# Account for the SubViewportContainer's position and any scaling
			var container: SubViewportContainer = viewport_parent
			var scale: Vector2 = Vector2.ONE
			if container.stretch:
				scale = container.size / Vector2(viewport.size)
			position = position * scale + container.global_position
			viewport = container.get_viewport()

			# Check for camera in the parent viewport as well
			if viewport == null:
				break
			camera = viewport.get_camera_2d()
			if camera:
				position = (
					position
					- camera.get_screen_center_position()
					+ viewport.get_visible_rect().size / 2
				)
		else:
			break

	return position
