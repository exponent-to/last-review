extends SceneTree
const Bank = preload("res://content/pr_bank.gd")
func _initialize() -> void:
	var entries: Array = Bank.entries()
	entries.append(Bank.practice())
	var re_def := RegEx.new(); re_def.compile("def\\s+([A-Za-z0-9_]+)")
	var counts := {}
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		for key in ["before", "lines"]:
			if not e.has(key): continue
			for line: String in e[key]:
				var low := line.to_lower()
				for m in re_def.search_all(line):
					var n := m.get_string(1).to_lower()
					for w in ["fire", "layoff", "union", "lunch", "terminat", "quit", "strike"]:
						if w in n: print("DEF %d %s %s: %s" % [i, key, w, line])
				if "#" in line and "helios" in low.substr(low.find("#")): print("HELIOSCOMMENT %d %s: %s" % [i, key, line])
				if "todo" in low: print("TODO %d %s: %s" % [i, key, line])
				if "load-bearing" in low: print("LB %d %s: %s" % [i, key, line])
		for w in ["quick", "small", "just"]:
			if w in str(e.title).to_lower(): print("TITLE %d %s" % [i, e.title])
	quit()
