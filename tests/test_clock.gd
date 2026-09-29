extends SceneTree

const Clock = preload("res://native/clock.gd")

func _initialize() -> void:
	var slow = Clock.new()
	var fast = Clock.new()
	var slow_ticks: int = 0
	var fast_ticks: int = 0
	for index in range(20):
		slow_ticks += slow.consume(0.1, 1)
	for index in range(100):
		fast_ticks += fast.consume(0.02, 1)
	# Floating-point frame sums need not land exactly on a tick boundary.
	slow_ticks += slow.consume(0.000001, 1)
	fast_ticks += fast.consume(0.000001, 1)
	if slow_ticks != 2 or fast_ticks != slow_ticks:
		push_error("Frame rates produced different tick counts")
		quit(1)
		return
	var clock = Clock.new()
	if clock.consume(0.25, 4) != 1 or clock.consume(20.0, 0) != 0:
		push_error("Speed or pause timing failed")
		quit(1)
		return
	clock.consume(0.9, 1)
	clock.reset()
	if clock.consume(0.1, 1) != 0 or clock.consume(60.0, 2) != 2:
		push_error("Clock reset or long-frame bound failed")
		quit(1)
		return
	print("Clock checks passed")
	quit(0)
