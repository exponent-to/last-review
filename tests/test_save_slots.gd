extends SceneTree
const Store = preload("res://native/save_store.gd")
const Sim = preload("res://native/simulation.gd")
const Tutorial = preload("res://native/tutorial.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 Store.storage_root = "user://save-slot-test-%d" % Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute(Store.storage_root)
 check(not Store.has_save(), "Fresh storage has no saves.")
 check(Store.save_game(Sim.advance(Sim.initial_state(), 17), {}, 1).ok, "Slot 1 stores the current campaign.")
 check(Store.load_game(1).state.shift_seconds == 17, "Slot 1 loads its progress.")
 var original := FileAccess.get_file_as_bytes(Store.slot_path(1))
 check(Store.save_game(Tutorial.initial_practice_state(), Tutorial.initial_progress(), 2).ok, "Slot 2 stores orientation.")
 check(Store.save_game(Sim.advance(Sim.initial_state(), 70), {}, 3).ok, "Slot 3 stores career progress.")
 check(FileAccess.get_file_as_bytes(Store.slot_path(1)) == original, "Writing other slots never changes slot 1.")
 check(Store.load_game(2).tutorial.stage == 0, "Tutorial progress loads independently.")
 check(Store.load_game(3).state.shift_seconds == 70, "Career time loads independently.")
 var summaries := Store.list_slots()
 check(summaries.size() == 3 and summaries[1].summary.begins_with("Orientation") and summaries[2].summary.contains("11:06"), "Slot picker summaries reflect each run.")
 check(Store.save_game(Sim.advance(Sim.initial_state(), 80), {}, 3).ok, "Updating a slot preserves its previous backup.")
 var corrupt := FileAccess.open(Store.slot_path(3), FileAccess.WRITE)
 corrupt.store_string("broken")
 corrupt.close()
 check(Store.load_game(3).ok and Store.load_game(3).state.shift_seconds == 70, "A corrupt slot recovers only its own backup.")
 check(Store.list_slots()[2].summary.ends_with("backup"), "Recovery is visible in the slot summary.")
 check(Store.load_game(1).state.shift_seconds == 17, "Recovery leaves other slots intact.")
 # Pre-release: invalid saves are deleted at application start, so the menu shows the slot empty.
 check(Store.DELETE_INVALID_SAVES_ON_START, "Pre-release builds delete invalid saves on start.")
 var outdated := Sim.initial_state()
 outdated.version = Sim.SAVE_VERSION - 1
 var old_file := FileAccess.open(Store.slot_path(2), FileAccess.WRITE)
 old_file.store_string(JSON.stringify(outdated))
 old_file.close()
 if FileAccess.file_exists(Store.slot_path(2) + ".bak"): DirAccess.remove_absolute(Store.slot_path(2) + ".bak")
 check(Store.has_save(2) and not Store.load_game(2).ok, "An outdated save is present but cannot load.")
 var removed := Store.purge_invalid()
 check(Store.slot_path(2) in removed and not Store.has_save(2), "An outdated save is removed at startup.")
 check(Store.list_slots()[1].summary == "Empty" and not Store.list_slots()[1].occupied, "The removed slot shows as empty, not as an error.")
 check(Store.slot_path(3) in removed and FileAccess.file_exists(Store.slot_path(3) + ".bak"), "A damaged save is removed but its valid backup stays.")
 check(Store.load_game(3).ok and Store.load_game(3).state.shift_seconds == 70, "The kept backup still loads.")
 check(Store.load_game(1).ok and Store.load_game(1).state.shift_seconds == 17 and Store.slot_path(1) not in removed, "Valid saves survive the purge.")
 check(Store.purge_invalid().is_empty(), "A second purge finds nothing left to delete.")
 for slot in [-1, 0, 4]:
  check(not Store.save_game(Sim.initial_state(), {}, slot).ok, "Out-of-range writes are rejected.")
  check(not Store.load_game(slot).ok, "Out-of-range reads are rejected.")
 for name in DirAccess.get_files_at(Store.storage_root):
  DirAccess.remove_absolute(Store.storage_root.path_join(name))
 DirAccess.remove_absolute(Store.storage_root)
 print("Save slots: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
