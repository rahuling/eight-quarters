## Deck loader + validator. Pure static helpers, no scene dependencies.
extends RefCounted

const PATH := "res://data/banking.json"

static func load_pack(path: String = PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("deck: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("deck: %s is not valid JSON" % path)
		return {}
	var d: Dictionary = parsed
	var problems := validate(d)
	if problems.size() > 0:
		for p in problems:
			push_error("deck: %s" % p)
		return {}
	return d

static func validate(d: Dictionary) -> Array:
	var problems: Array = []
	for key in ["pack", "seats", "bus", "tracks", "mandates", "quirks", "forks", "debts", "events", "meetings", "endings"]:
		if not d.has(key):
			problems.append("missing key: " + str(key))
	if problems.size() > 0:
		return problems
	# seats reference-able ids
	var seat_ids := {}
	for s in d["seats"]:
		seat_ids[s["id"]] = true
	# tracks: costs aligned with levels (level 1..3), gates optional
	for t in d["tracks"]:
		if t["levels"].size() - 1 != t["costs"].size():
			problems.append("track %s: levels/costs mismatch" % t["id"])
		var gates: Array = t.get("gates", [])
		if gates.size() > 0 and gates.size() != t["costs"].size():
			problems.append("track %s: gates/costs mismatch" % t["id"])
	# forks reference seats + option seeds point at existing events
	var ev_ids := {}
	for e in d["events"]:
		ev_ids[e["id"]] = true
	for f in d["forks"]:
		for o in f["options"]:
			var seed_name = o.get("seed", null)
			if seed_name != null and not ev_ids.has(seed_name):
				problems.append("fork %s seeds unknown event %s" % [f["id"], str(seed_name)])
	# meeting seats exist
	for m in d["meetings"]:
		if not seat_ids.has(m["seat"]):
			problems.append("meeting for unknown seat %s" % m["seat"])
	# events: responses have effects
	for e in d["events"]:
		if e["responses"].size() < 2:
			problems.append("event %s needs >=2 responses" % e["id"])
	return problems
