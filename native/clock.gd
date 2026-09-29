extends RefCounted
## Converts frame time to whole simulation ticks. Rules never depend on FPS.

var remainder: float = 0.0

func consume(elapsed: float, speed: int) -> int:
	if speed == 0:
		remainder = 0.0
		return 0
	if not is_finite(elapsed) or elapsed <= 0.0:
		return 0
	remainder += minf(elapsed, 1.0) * speed
	var ticks: int = int(floor(remainder))
	remainder -= ticks
	return ticks

func reset() -> void:
	remainder = 0.0
