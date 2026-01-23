class_name TweenHelper

static var tweens_dict: Dictionary[String, Tween] = {}

static func dirty_cleanup() -> void:
	for key: String in tweens_dict.keys():
		if tweens_dict.has(key) and not (tweens_dict[key] as Tween).is_running():
			(tweens_dict[key] as Tween).kill()
			tweens_dict.erase(key)

static func tween(reference_name: String, origin_node: Node, should_cleanup_on_finish := true, process_mode := Tween.TWEEN_PROCESS_IDLE) -> Tween:
	var key: String = str(origin_node.get_instance_id()) + "_" + reference_name
	if tweens_dict.has(key) and (tweens_dict[key] as Tween).is_running():
		(tweens_dict[key] as Tween).kill()
	var new_tween: Tween = origin_node.create_tween()
	new_tween.set_process_mode(process_mode)
	tweens_dict[key] = new_tween
	if should_cleanup_on_finish:
		new_tween.finished.connect(_handle_tween_finished.bind(new_tween, key), CONNECT_ONE_SHOT)
	return new_tween

static func _handle_tween_finished(tween: Tween, key: String):
	if tweens_dict.has(key):
		tweens_dict.erase(key)
	if is_instance_valid(tween):
		tween.kill()
