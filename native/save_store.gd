extends RefCounted
## Native user-data persistence; simulation stays independent of filesystem APIs.

const Simulation = preload("res://native/simulation.gd")
const SAVE_PATH: String = "user://workshop-save.json"
const TEMP_PATH: String = "user://workshop-save.json.tmp"
const BACKUP_PATH: String = "user://workshop-save.json.bak"
const MAX_SAVE_BYTES: int = 100000

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "state": {}, "error": message}

static func save_game(state: Dictionary) -> Dictionary:
	var validation: Dictionary = Simulation.validate_save(state)
	if not validation.ok:
		return _failure(validation.error)
	var raw: String = Simulation.serialize_save(validation.state)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return _failure("Could not create temporary save: " + error_string(FileAccess.get_open_error()))
	file.store_string(raw)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _failure("Could not write save: " + error_string(write_error))
	var had_save: bool = FileAccess.file_exists(SAVE_PATH)
	if had_save:
		if FileAccess.file_exists(BACKUP_PATH):
			var remove_error: Error = DirAccess.remove_absolute(BACKUP_PATH)
			if remove_error != OK:
				return _failure("Could not replace save backup: " + error_string(remove_error))
		var backup_error: Error = DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
		if backup_error != OK:
			return _failure("Could not back up current save: " + error_string(backup_error))
	var commit_error: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if commit_error != OK:
		if had_save:
			var restore_error: Error = DirAccess.rename_absolute(BACKUP_PATH, SAVE_PATH)
			if restore_error != OK:
				return _failure("Could not finish save or restore previous file. Previous save remains at " + BACKUP_PATH)
		return _failure("Could not finish save: " + error_string(commit_error))
	return {"ok": true, "error": ""}

static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			return _load_path(BACKUP_PATH)
		return _failure("No saved workshop found.")
	var result: Dictionary = _load_path(SAVE_PATH)
	if result.ok:
		return result
	if FileAccess.file_exists(BACKUP_PATH):
		var backup: Dictionary = _load_path(BACKUP_PATH)
		if backup.ok:
			backup.error = "Current save could not be loaded; recovered the previous backup."
			return backup
	return result

static func _load_path(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Could not open save: " + error_string(FileAccess.get_open_error()))
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return _failure("Invalid save: file exceeds 100,000 bytes.")
	var raw: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(raw)
	if parse_error != OK:
		return _failure("Invalid save JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
	return Simulation.validate_save(parser.data)
