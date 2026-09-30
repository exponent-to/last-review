extends SceneTree

const MainMenu = preload("res://native/main_menu.gd")
var checks := 0
var failures := 0
var new_calls := 0
var load_calls := 0
var quit_calls := 0


func _initialize() -> void:
	load("res://content/catalog.gd").campaign_version = 4
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	root.push_input(event, true)


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)


func _run() -> void:
	root.size = Vector2i(1280, 900)
	var menu := MainMenu.new()
	menu.set_motion(false)
	menu.set_load_available(false)
	menu.show_error("A saved run could not be read. Start a new game or try loading again.")
	menu.new_game_requested.connect(func(_slot: int) -> void: new_calls += 1)
	menu.load_game_requested.connect(func(_slot: int) -> void: load_calls += 1)
	menu.quit_requested.connect(func() -> void: quit_calls += 1)
	root.add_child(menu)
	for frame in range(4):
		await process_frame
	_check(menu._new_game.has_focus(), "New Game is the default keyboard action.")
	_check(menu._load_game.disabled, "Load Game is disabled without a save.")
	_check(not menu._backdrop._motion, "Reduced motion configured before ready reaches the backdrop.")
	_check(menu._error.text.begins_with("A saved run"), "Errors configured before ready remain visible.")
	_click(menu._load_game)
	_check(load_calls == 0, "A disabled load button cannot emit a load request.")
	menu.focus_default()
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, true, true)
	_key(KEY_ENTER, false)
	_check(new_calls == 0 and menu._slot_buttons[0].visible, "New Game shows three slots before starting a run.")
	menu._slot_buttons[1].pressed.emit()
	_check(new_calls == 1, "Choosing an empty slot emits one New Game request.")
	menu.show_home()
	menu.set_slots([{"occupied": true, "summary": "Day 1 · 09:00"}, {"occupied": false, "summary": "Empty"}, {"occupied": false, "summary": "Empty"}])
	menu._load_game.pressed.emit()
	_check(not menu._slot_buttons[0].disabled and menu._slot_buttons[1].disabled, "Load only enables occupied slots.")
	menu._slot_buttons[0].pressed.emit()
	_check(load_calls == 1, "Choosing an occupied slot loads that run.")
	menu.show_home()
	menu._new_game.pressed.emit()
	menu._slot_buttons[0].pressed.emit()
	_check(new_calls == 1 and menu._replace.visible, "New Game requires confirmation before replacing a run.")
	menu._replace.hide()
	menu._replace.confirmed.emit()
	_check(new_calls == 2, "Confirmed replacement starts exactly once.")
	menu.show_home()
	if not OS.has_feature("web"):
		_click(menu._quit)
		_check(quit_calls == 1, "Native Quit emits a request without quitting the view's process.")
	else:
		_check(not menu._quit.visible, "Browser builds hide Quit.")
	for viewport: Vector2i in [Vector2i(1280, 900), Vector2i(1120, 800)]:
		root.size = viewport
		for frame in range(4):
			await process_frame
		var screen_rect: Rect2 = menu._screen.get_global_rect()
		_check(menu.get_global_rect().encloses(screen_rect), "Monitor screen stays inside viewport %s." % viewport)
		_check(screen_rect.encloses(menu._content.get_global_rect()), "All menu content fits the monitor at %s." % viewport)
		for button: Button in [menu._new_game, menu._load_game, menu._quit]:
			_check(button.size.y >= 44 and button.size.x >= 300, "Menu actions remain readable and easy to target at %s." % viewport)
	menu._show_slots("new")
	for frame in range(4): await process_frame
	_check(menu._screen.get_global_rect().encloses(menu._content.get_global_rect()), "All three slot choices fit the minimum viewport.")
	menu.show_error("")
	_check(menu._error.text.is_empty(), "The application can clear a previous loading error.")
	menu.queue_free()
	await process_frame
	print("Main menu: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
