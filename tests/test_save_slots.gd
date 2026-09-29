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
func _initialize() -> void: run.call_deferred()
func run() -> void:
 Store.storage_root = "user://save-slot-test-%d" % Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute(Store.storage_root)
 check(not Store.has_save(), "Fresh storage has no saves.")
 # A legacy save is read directly as slot 1; no destructive migration.
 var legacy := FileAccess.open(Store.storage_root.path_join("review-save-v4.json"), FileAccess.WRITE)
 legacy.store_string(Sim.serialize_save(Sim.advance(Sim.initial_state(), 17)))
 legacy.close()
 check(Store.load_game(1).state.shift_seconds == 17, "Existing single-slot saves appear in slot 1.")
 var original := FileAccess.get_file_as_bytes(Store.slot_path(1))
 check(Store.save_game(Tutorial.initial_practice_state(), Tutorial.initial_progress(), 2).ok, "Slot 2 stores orientation.")
 check(Store.save_game(Sim.advance(Sim.initial_state(), 70), {}, 3).ok, "Slot 3 stores career progress.")
 check(FileAccess.get_file_as_bytes(Store.slot_path(1)) == original, "Writing other slots never changes the legacy save.")
 check(Store.load_game(2).tutorial.stage == 0, "Tutorial progress loads independently.")
 check(Store.load_game(3).state.shift_seconds == 70, "Career time loads independently.")
 var summaries := Store.list_slots()
 check(summaries.size() == 3 and summaries[1].summary == "Orientation" and summaries[2].summary.contains("10:45"), "Slot picker summaries reflect each run.")
 check(Store.save_game(Sim.advance(Sim.initial_state(), 80), {}, 3).ok, "Updating a slot preserves its previous backup.")
 var corrupt := FileAccess.open(Store.slot_path(3), FileAccess.WRITE)
 corrupt.store_string("broken")
 corrupt.close()
 check(Store.load_game(3).ok and Store.load_game(3).state.shift_seconds == 70, "A corrupt slot recovers only its own backup.")
 check(Store.list_slots()[2].summary.ends_with("backup"), "Recovery is visible in the slot summary.")
 check(Store.load_game(1).state.shift_seconds == 17, "Recovery leaves other slots intact.")
 for slot in [-1, 0, 4]:
  check(not Store.save_game(Sim.initial_state(), {}, slot).ok, "Out-of-range writes are rejected.")
  check(not Store.load_game(slot).ok, "Out-of-range reads are rejected.")
 for name in DirAccess.get_files_at(Store.storage_root):
  DirAccess.remove_absolute(Store.storage_root.path_join(name))
 DirAccess.remove_absolute(Store.storage_root)
 print("Save slots: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
