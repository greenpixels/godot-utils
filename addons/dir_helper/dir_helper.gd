class_name DirHelper

static func for_each_in_directory(directory: String, callback: Callable) -> void:
	var dir: DirAccess = DirAccess.open(directory)
	
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		
		while file_name != "":
			var file_path: String = directory + "/" + file_name
			var resource_path: String = file_path.replace(".remap", "")
			if dir.current_is_dir():
				for_each_in_directory(file_path, callback)
			elif resource_path.ends_with(".tres") or resource_path.ends_with(".res"):
				var res_path: String = resource_path
				var resource: Resource = ResourceLoader.load(res_path)
				callback.call(resource)
			
			file_name = dir.get_next()
