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
	var tween: Tween = origin_node.create_tween()
	tween.finished.connect(tween.kill)
	tweens_dict[key] = origin_node.create_tween()
	tweens_dict[key].set_process_mode(process_mode)
	return tweens_dict[key]

static func _handle_tween_finished(tween: Tween, key: String):
	if tweens_dict.has(key):
		tweens_dict.erase(key)
	if is_instance_valid(tween):
		tween.kill()
