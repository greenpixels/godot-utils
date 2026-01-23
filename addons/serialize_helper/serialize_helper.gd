class_name SerializeHelper

static func export_storage_to_json(node: Node) -> Dictionary:
	var data: Dictionary = {}
	for prop: Dictionary in node.get_property_list():
		var property_name: String = prop.name
		var property_usage: int = prop.usage
		# Only include script-defined properties with storage flag
		if property_usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and property_usage & PROPERTY_USAGE_STORAGE != 0:
			data[property_name] = node.get(property_name)
	return data
