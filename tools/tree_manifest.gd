extends SceneTree
## Writer briefs for per-PR dialogue trees: one Markdown file per two-day block.
##   sh scripts/run.sh --headless --script res://tools/tree_manifest.gd -- <out_dir>
## Shows each slot's author and the PR's intended change (from the bank, without
## any injected faults), so lines can be specific without ever knowing the answer.
const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Bank = preload("res://content/pr_bank.gd")
const Trees = preload("res://content/trees.gd")

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://tree_briefs"
	DirAccess.make_dir_recursive_absolute(out)
	var entries := {}
	for entry: Dictionary in Bank.entries(): entries[str(entry.title)] = entry
	for block in range(5):
		var first_day := block * 2 + 1
		var lines: Array[String] = ["# Dialogue tree brief: days %d-%d" % [first_day, first_day + 1], "", "Write trees into `%s`. Format and rules: `content/trees.gd` and `tests/test_trees.gd`; model tree: PR-1042 in days_01_02.gd." % Trees.FILES[block], ""]
		for day: int in [first_day, first_day + 1]:
			var rules: Array[String] = []
			for rule: Dictionary in Catalog.rules_for_day(day): rules.append("%s %s" % [rule.id, rule.title])
			lines.append("## Day %d (Helios advice %s). Standards on the slip: %s" % [day, "available" if day >= 3 else "not yet available", ", ".join(rules)])
			lines.append("")
			for packet: Dictionary in Catalog.requests_for_day(day):
				var entry: Dictionary = entries.get(str(packet.title), {})
				# A tree written for the slot's previous author must be rewritten in the new one's voice.
				var tree: Dictionary = Trees.tree(str(packet.title))
				var status := ""
				if not tree.is_empty():
					status = "  (already written)" if str(tree.get("author", "")) == str(packet.author) else "  (REWRITE: the tree still speaks as %s)" % str(tree.get("author", ""))
				lines.append("### %s · %s · author **%s**%s" % [packet.id, packet.title, packet.author, status])
				lines.append("- Phrase: %s" % str(entry.get("phrase", "")))
				for field: String in ["pitch", "pushback", "relief", "grudge"]:
					lines.append("- Bank %s: %s" % [field, str(entry.get(field, ""))])
				lines.append("- Intended change to `%s` (%s):" % [str(entry.get("path", "")), "modified" if entry.has("before") else "new file"])
				lines.append("```diff")
				var before := "\n".join(entry.get("before", [])) if entry.has("before") else ""
				for row: Dictionary in Policy.line_diff(before, "\n".join(entry.get("lines", []))):
					lines.append(str(row.kind) + str(row.text))
				lines.append("```")
				lines.append("")
		var path := out.path_join("days_%02d_%02d.md" % [first_day, first_day + 1])
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
		file.close()
		print("wrote ", path)
	quit()
