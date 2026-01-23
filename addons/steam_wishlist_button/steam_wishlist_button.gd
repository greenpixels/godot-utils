extends PanelContainer
class_name SteamWishlistButton

var orignal_scale: Vector2
static var url = "https://store.steampowered.com/app/3618390?utm_source=UNKNOWN_OR_DESKTOP&utm_medium=PLATFORM&utm_content=CONTENT"

func _ready() -> void:
	orignal_scale = scale
	var animation = TweenHelper.tween("animation", self)
	animation.set_loops()
	animation.tween_property(self, "modulate", Color.from_rgba8(150, 150, 150, 255), 0.2).set_delay(2).set_ease(Tween.EASE_OUT)
	animation.tween_property(self, "modulate", Color.WHITE, 0.2).set_ease(Tween.EASE_OUT)

static func open_steam(content: String):
	var target_url = url
	if OS.has_feature("web"):
		var host = JavaScriptBridge.eval("location.hostname", true)
		target_url = url.replace("UNKNOWN_OR_DESKTOP", host)
	target_url = target_url.replace("PLATFORM", OS.get_name().to_lower() + "_" + ("demo" if OS.has_feature("demo") else "release"))
	target_url = target_url.replace("CONTENT", content)
	OS.shell_open(target_url)

func _on_button_pressed() -> void:
	open_steam("ingame_button")
