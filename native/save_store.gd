extends RefCounted
## Native user-data persistence; simulation stays independent of filesystem APIs.

const Tutorial = preload("res://native/tutorial.gd")
const Simulation = preload("res://native/simulation.gd")
const SAVE_PATH: String = "user://review-save-v4.json"
const TEMP_PATH: String = "user://review-save-v4.json.tmp"
const BACKUP_PATH: String = "user://review-save-v4.json.bak"
const MAX_SAVE_BYTES: int = 100000
const SLOT_COUNT := 3
static var storage_root := "user://"

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "state": {}, "error": message}

static func slot_path(slot: int) -> String:
	return storage_root.path_join("review-save-v4.json" if slot == 1 else "review-save-v4-slot-%d.json" % slot)

static func save_game(state: Dictionary, tutorial: Dictionary = {}, slot: int = 1) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT: return _failure("Choose a save slot from 1 to 3.")
	var save_path := slot_path(slot)
	var temp_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var validation: Dictionary = Simulation.validate_save(state)
	if not validation.ok:
		return _failure(validation.error)
	var raw: String = Simulation.serialize_save(validation.state)
	if not tutorial.is_empty():
		var training := Tutorial.validate(tutorial, validation.state)
		if not training.ok:
			return _failure(training.error)
		raw = JSON.stringify({"format": "last-review-session", "version": 1, "state": validation.state, "tutorial": training.progress})
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _failure("Could not create temporary save: " + error_string(FileAccess.get_open_error()))
	file.store_string(raw)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _failure("Could not write save: " + error_string(write_error))
	var had_save: bool = FileAccess.file_exists(save_path)
	if had_save:
		if FileAccess.file_exists(backup_path):
			var remove_error: Error = DirAccess.remove_absolute(backup_path)
			if remove_error != OK:
				return _failure("Could not replace save backup: " + error_string(remove_error))
		var backup_error: Error = DirAccess.rename_absolute(save_path, backup_path)
		if backup_error != OK:
			return _failure("Could not back up current save: " + error_string(backup_error))
	var commit_error: Error = DirAccess.rename_absolute(temp_path, save_path)
	if commit_error != OK:
		if had_save:
			var restore_error: Error = DirAccess.rename_absolute(backup_path, save_path)
			if restore_error != OK:
				return _failure("Could not finish save or restore previous file. Previous save remains at " + backup_path)
		return _failure("Could not finish save: " + error_string(commit_error))
	return {"ok": true, "error": ""}

static func load_game(slot: int = 1) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT: return _failure("Choose a save slot from 1 to 3.")
	var save_path := slot_path(slot)
	var backup_path := save_path + ".bak"
	if not FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			return _load_path(backup_path)
		if slot == 1 and FileAccess.file_exists(storage_root.path_join("review-save-v3.json")):
			return _failure("Your earlier untimed career is preserved. Timed shifts and incoming requests require a new career; new saves use version 4.")
		if slot == 1 and FileAccess.file_exists(storage_root.path_join("review-save-v2.json")):
			return _failure("An earlier review save is preserved, but its schedule is incompatible with this campaign. Start a new career to create a version 4 save.")
		return _failure("No saved review career found.")
	var result: Dictionary = _load_path(save_path)
	if result.ok:
		return result
	if FileAccess.file_exists(backup_path):
		var backup: Dictionary = _load_path(backup_path)
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
	return decode_session(parser.data)

static func has_save(slot: int = 0) -> bool:
	if slot == 0:
		for index in range(1, SLOT_COUNT + 1):
			if has_save(index): return true
		return false
	if slot < 1 or slot > SLOT_COUNT: return false
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")

static func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		var entry := {"slot": slot, "occupied": has_save(slot), "summary": "Empty", "loadable": false}
		if entry.occupied:
			var result := load_game(slot)
			entry.loadable = result.ok
			if result.ok:
				var state: Dictionary = result.state
				var minutes := Simulation.clock_minutes(state)
				entry.summary = "Orientation" if not result.get("tutorial", {}).is_empty() else "Day %d · %02d:%02d" % [int(state.day), int(minutes / 60), minutes % 60]
				if not str(result.error).is_empty(): entry.summary += " · backup"
			else: entry.summary = "Unreadable save"
		slots.append(entry)
	return slots

static func decode_session(value: Variant) -> Dictionary:
	if value is Dictionary and value.get("format") == "last-review-session":
		if value.size() != 4 or value.get("version") != 1:
			return _failure("Invalid saved session.")
		var saved := Simulation.validate_save(value.get("state"))
		if not saved.ok: return saved
		var training := Tutorial.validate(value.get("tutorial"), saved.state)
		if not training.ok: return _failure(training.error)
		saved.tutorial = training.progress
		return saved
	var saved := Simulation.validate_save(value)
	if saved.ok: saved.tutorial = {}
	return saved
