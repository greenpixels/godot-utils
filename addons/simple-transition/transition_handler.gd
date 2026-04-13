extends CanvasLayer

enum TransitionType {
	DONUT
}

@export var default_transition_type: TransitionType = TransitionType.DONUT

var _current_transition: BaseTransition
var _target_scene: PackedScene
var _target_node: Node
var _transition_time: float = 0.0
var _duration: float = 1.0
var is_transitioning: bool = false
var _scene_switched: bool = false
var _transition_drawer: TransitionDrawer
var _resource_loader_path: String
var _loading_status = ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED
var _before_load_callable = null
var _after_load_callable = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_drawer = TransitionDrawer.new()
	add_child(_transition_drawer)
	_transition_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not is_transitioning:
		return

	if _resource_loader_path != "" and not _scene_switched:
		_loading_status = ResourceLoader.load_threaded_get_status(_resource_loader_path)

	if not (_loading_status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS and _transition_time > 0.5):
		_transition_time += min(delta, 0.1) / _duration

	if _transition_time >= 0.5 and not _scene_switched:
		if not _before_load_callable == null:
			_before_load_callable.call()

		if _loading_status == ResourceLoader.THREAD_LOAD_LOADED:
			if _resource_loader_path != "":
				_target_scene = ResourceLoader.load_threaded_get(_resource_loader_path)
			_switch_scene()

	if _transition_time >= 1.0:
		is_transitioning = false
		_target_scene = null
		_target_node = null
		_loading_status = ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED
		on_transition_finished()
		return

	_transition_drawer.progress = _transition_time
	_transition_drawer.transition = _current_transition
	_transition_drawer.queue_redraw()

func _start_transition(duration: float, transition_type: TransitionType, before_loaded = null, after_loaded = null) -> void:
	_target_scene = null
	_target_node = null
	_scene_switched = false
	_duration = duration
	_before_load_callable = before_loaded
	_after_load_callable = after_loaded
	_transition_time = 0.0
	is_transitioning = true
	_resource_loader_path = ""
	_loading_status = ResourceLoader.THREAD_LOAD_LOADED
	get_tree().paused = true

	match transition_type:
		TransitionType.DONUT:
			_current_transition = DonutTransition.new()

func transition_to(target_scene: PackedScene, duration: float, transition_type: TransitionType = default_transition_type, before_loaded = null, after_loaded = null) -> void:
	_start_transition(duration, transition_type, before_loaded, after_loaded)
	_resource_loader_path = target_scene.resource_path
	ResourceLoader.load_threaded_request(_resource_loader_path)

func transition_to_node(target_node: Node, duration: float, transition_type: TransitionType = default_transition_type, before_loaded = null, after_loaded = null) -> void:
	_start_transition(duration, transition_type, before_loaded, after_loaded)
	_target_node = target_node

func _switch_scene() -> void:
	if _target_node != null:
		get_tree().change_scene_to_node(_target_node)
	elif _target_scene != null:
		get_tree().change_scene_to_packed(_target_scene)
	_scene_switched = true
	on_new_scene_loaded()

func on_new_scene_loaded() -> void:
	get_tree().paused = false

func on_transition_finished() -> void:
	if _after_load_callable != null:
		_after_load_callable.call()
	_transition_drawer._reset()
	_after_load_callable = null
	_before_load_callable = null
	
