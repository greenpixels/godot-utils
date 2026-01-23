class_name BBCodeHelper

var content: String = ""
var empty_image: Texture = preload("res://addons/bb_code_helper/empty.png")

static func build(_content: String) -> BBCodeHelper:
	var instance: BBCodeHelper = BBCodeHelper.new()
	instance.content = _content
	return instance

func color(hex: String) -> BBCodeHelper:
	content = "[color={hex}]{content}[/color]".format({"hex": hex, "content": content})
	return self

func add_icon(texture: Texture, size: int = 21, before: bool = true) -> BBCodeHelper:
	var width: int = (texture.get_width() / texture.get_height()) * size
	var empty_image_string: String = "[img=4x{size_y}]{empty_path}[/img]".format({"empty_path": empty_image.resource_path, "size_y": size})
	var image_string: String = "[img={size_x}x{size_y}]{path}[/img]".format({
		"path": texture.resource_path,
		"size_x": width,
		"size_y": size
		})
	content = image_string + empty_image_string + content if before else content + empty_image_string + image_string
	return self

func replace_key_as_coloured_number_value(key: String, value: float, font_color: String, add_sign: bool = false) -> BBCodeHelper:
	var _sign: String = ""
	if add_sign: _sign = "+" if value > 0 else ""
	content = content.format({key: BBCodeHelper.build(_sign + str(value)).color(font_color).result()})
	return self
	
func replace_key_as_coloured_number_value_int(key: String, value: int, font_color: String, add_sign: bool = false) -> BBCodeHelper:
	var _sign: String = ""
	if add_sign: _sign = "+" if value > 0 else ""
	content = content.format({key: BBCodeHelper.build(_sign + str(value)).color(font_color).result()})
	return self

func center() -> BBCodeHelper:
	content = "[center]{content}[/center]".format({"content": content})
	return self

func append_key_value_pairs(pairs: Dictionary, key_color: String = "", value_color: String = "", separator: String = ": ", line_prefix: String = "\n") -> BBCodeHelper:
	for key in pairs:
		var line: String = line_prefix
		var key_text: String = str(key)
		var value_text: String = str(pairs[key])
		
		if key_color != "":
			key_text = "[color={color}]{text}[/color]".format({"color": key_color, "text": key_text})
		
		if value_color != "":
			value_text = "[color={color}]{text}[/color]".format({"color": value_color, "text": value_text})
		
		line += key_text + separator + value_text
		content += line
	
	return self
	
func result() -> String:
	return content
