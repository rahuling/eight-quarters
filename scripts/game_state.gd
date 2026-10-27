## Eight Quarters — logic core.
## Pure, serializable, deterministic (seeded RNG). UI reads this; tests drive this.
extends Node

const DeckScript := preload("res://scripts/deck.gd")

const PC_START := 3
const PC_CAP := 8
const BUDGET_PER_QUARTER := 750  # $k
const CREW_START := 8
const TOTAL_QUARTERS := 8

# ---- state ----
var deck: Dictionary = {}
var seed_value: int = 1
var rng := RandomNumberGenerator.new()

var quarter: int = 1
var budget: int = BUDGET_PER_QUARTER
var crew: float = CREW_START
var pc: int = PC_START
var xp: int = 0
var scandals: int = 0
var audit: int = 50
var shadow: int = 20
var rival: int = 20
var attributed_pct: int = 0
var decisions_changed: int = 0
var clock_due: int = 4
var clock_used_bonus: bool = false
var crew_loss_taken: bool = false
var meeting_used: bool = false
var fork_done: Dictionary = {}          # fork_id -> option_index
var tracks: Dictionary = {}             # track_id -> level (0..3)
var builds: Array = []                  # [{track, left, total, crew}]
var trust: Dictionary = {}              # seat_id -> int -2..2
var bus: Array = []                     # [{id,name,state,level}]
var flags: Dictionary = {}              # name -> true
var promises: Array = []                # [{id,seat,text,check,due,met}]
var debts: Dictionary = {}              # debt_id -> {"answered": bool, "fuse": int}
var mandate: Dictionary = {}
var quirks: Array = []                  # quirk dicts
var pending_seeds: Array = []           # [{event_id, due_q, seed_label}]
var fired_events: Dictionary = {}       # event_id -> true
var current_event: Dictionary = {}
var last_report: Dictionary = {}
var game_over: Dictionary = {}          # {} while playing, else {"kind":"lose"/"end","ending":{}}
var log_lines: Array = []

signal state_changed

# ---------------- lifecycle ----------------

func start_run(pack: Dictionary, run_seed: int) -> void:
	deck = pack
	seed_value = run_seed
	rng.seed = run_seed
	quarter = 1
	budget = BUDGET_PER_QUARTER
	crew = CREW_START
	pc = PC_START
	xp = 0
	scandals = 0
	audit = 50
	shadow = 20
	rival = 20
	attributed_pct = 0
	decisions_changed = 0
	clock_due = 4
	clock_used_bonus = false
	crew_loss_taken = false
	meeting_used = false
	fork_done = {}
	tracks = {}
	builds = []
	flags = {}
	promises = []
	pending_seeds = []
	fired_events = {}
	current_event = {}
	last_report = {}
	game_over = {}
	log_lines = []
	for t in deck["tracks"]:
		tracks[t["id"]] = 0
	trust = {}
	for s in deck["seats"]:
		trust[s["id"]] = int(s["trust0"])
	bus = []
	for b in deck["bus"]:
		bus.append({"id": b["id"], "name": b["name"], "state": b["state"], "level": b["level"]})
	debts = {}
	for d in deck["debts"]:
		debts[d["id"]] = {"answered": false, "fuse": int(d["fuse"])}
	# draw mandate (always includes agents_by_q4 as the classic run? no - true draw)
	var mandates: Array = deck["mandates"]
	mandate = mandates[rng.randi_range(0, mandates.size() - 1)]
	clock_due = int(mandate["due"])
	# draw 2 quirks
	var qpool: Array = deck["quirks"].duplicate()
	quirks = []
	for i in 2:
		var idx := rng.randi_range(0, qpool.size() - 1)
		quirks.append(qpool[idx])
		qpool.remove_at(idx)
	for q in quirks:
		if q.has("effect"):
			apply_effects(q["effect"])
	_emit()

# ---------------- helpers ----------------

func seat(id: String) -> Dictionary:
	for s in deck["seats"]:
		if s["id"] == id:
			return s
	return {}

func bu_state(id: String) -> String:
	for b in bus:
		if b["id"] == id:
			return b["state"]
	return ""

func set_bu(id: String, state: String) -> void:
	for b in bus:
		if b["id"] == id:
			b["state"] = state

func adoption_on() -> int:
	var n := 0
	for b in bus:
		if b["state"] == "on":
			n += 1
	return n

func quirk_has(id: String) -> bool:
	for q in quirks:
		if q["id"] == id:
			return true
	return false

func track_ok(track: String, level: int) -> bool:
	return int(tracks.get(track, 0)) >= level

func clamp_trust(id: String, delta: int) -> void:
	trust[id] = clamp(int(trust.get(id, 0)) + delta, -2, 2)

func agent_gate_ok(level: int) -> bool:
	for t in deck["tracks"]:
		if t["id"] == "agent":
			var gates: Array = t.get("gates", [])
			if gates.size() >= level and not gates[level - 1].is_empty():
				var g: Dictionary = gates[level - 1]
				for k in g:
					if k == "debt":
						if not debts[g[k]]["answered"]:
							return false
					elif not track_ok(k, int(g[k])):
						return false
			return true
	return false

# ---------------- actions ----------------

func apply_effects(e: Dictionary) -> void:
	if e.has("budget"):      budget += int(e["budget"])
	if e.has("pc"):          pc = clamp(pc + int(e["pc"]), 0, 99)
	if e.has("audit"):       audit = clamp(audit + int(e["audit"]), 0, 100)
	if e.has("scandal"):     scandals += int(e["scandal"])
	if e.has("shadow"):      shadow = clamp(shadow + int(e["shadow"]), 0, 100)
	if e.has("rival"):       rival = clamp(rival + int(e["rival"]), 0, 100)
	if e.has("xp"):          xp += int(e["xp"])
	if e.has("points"):      decisions_changed += int(e["points"])
	if e.has("trust"):
		for seat_id in e["trust"]:
			clamp_trust(seat_id, int(e["trust"][seat_id]))
	if e.has("progress"):
		for track_id in e["progress"]:
			tracks[track_id] = clamp(int(tracks[track_id]) + int(e["progress"][track_id]), 0, 3)
	if e.has("adoption"):
		for bu_id in e["adoption"]:
			set_bu(bu_id, e["adoption"][bu_id])
	if e.has("flag"):
		flags[e["flag"]] = true
	if e.has("crew_loss") and not crew_loss_taken:
		crew = maxf(crew * (1.0 - float(e["crew_loss"])), 2.0)
		crew_loss_taken = true
	if e.has("progress_loss"):
		for track_id in e["progress_loss"]:
			tracks[track_id] = clamp(int(tracks[track_id]) - int(e["progress_loss"][track_id]), 0, 3)

func response_available(resp: Dictionary) -> bool:
	var req = resp.get("req", null)
	if req == null:
		return true
	if req.has("track"):
		if not track_ok(req["track"], int(req["level"])):
			return false
	if req.has("debt"):
		if not debts[req["debt"]]["answered"]:
			return false
	return true

func start_build(track_id: String) -> Dictionary:
	if track_id == "agent" and not agent_gate_ok(int(tracks["agent"]) + 1):
		return {"ok": false, "reason": "Agent gates not met - the foundation comes first."}
	for t in deck["tracks"]:
		if t["id"] == track_id:
			var lvl := int(tracks[track_id])
			if lvl >= 3:
				return {"ok": false, "reason": "Track already at max."}
			var cost: Dictionary = t["costs"][lvl]
			if budget < int(cost["budget"]):
				return {"ok": false, "reason": "Not enough budget ($%dk needed)." % int(cost["budget"])}
			if crew < float(cost["crew"]):
				return {"ok": false, "reason": "Not enough crew."}
			if pc < int(cost["pc"]):
				return {"ok": false, "reason": "Not enough political capital."}
			budget -= int(cost["budget"])
			pc -= int(cost["pc"])
			builds.append({"track": track_id, "left": int(cost["quarters"]), "total": int(cost["quarters"]), "crew": int(cost["crew"])})
			_emit()
			return {"ok": true, "reason": "%s L%d underway." % [t["name"], lvl + 1]}
	return {"ok": false, "reason": "Unknown track."}

func make_fork(fork_id: String, option_idx: int) -> Dictionary:
	for f in deck["forks"]:
		if f["id"] == fork_id and not fork_done.has(fork_id) and f["quarter"] == quarter:
			var opt: Dictionary = f["options"][option_idx]
			fork_done[fork_id] = option_idx
			apply_effects(opt["effects"])
			if opt.get("seed", null) != null:
				pending_seeds.append({"event_id": opt["seed"], "due_q": quarter + rng.randi_range(1, 3), "seed_label": "your Q%d fork: %s" % [quarter, f["title"].to_lower()]})
			log_lines.append("Q%d fork: %s" % [quarter, opt["label"]])
			_emit()
			return {"ok": true}
	return {"ok": false, "reason": "Fork unavailable."}

func answer_debt(debt_id: String) -> Dictionary:
	if pc < 1 or meeting_used:
		return {"ok": false, "reason": "Needs 1 PC and the quarter's meeting slot."}
	debts[debt_id]["answered"] = true
	pc -= 1
	meeting_used = true
	xp += 10
	log_lines.append("Q%d answered: %s" % [quarter, debt_id])
	_emit()
	return {"ok": true}

func featured_meeting() -> Dictionary:
	# the seat under most pressure this quarter (rival > clock > lowest trust)
	if meeting_used:
		return {}
	var candidates: Array = []
	for m in deck["meetings"]:
		candidates.append(m)
	# pressure order: rival-ish seats and the clock; keep deterministic per quarter
	candidates.sort_custom(func(a, b): return a["seat"] < b["seat"])
	var pick = candidates[(quarter + int(rng.randi() % candidates.size())) % candidates.size()]
	return pick

func accept_meeting(deal: Dictionary) -> Dictionary:
	if meeting_used:
		return {"ok": false, "reason": "The quarter's meeting slot is used. (A second meeting costs 1 PC - v2.)"}
	if pc < int(deal["pc"]):
		return {"ok": false, "reason": "Not enough political capital."}
	pc -= int(deal["pc"])
	meeting_used = true
	var pr: Dictionary = deal["promise"]
	promises.append({"id": "%s_q%d" % [deal["seat"], quarter], "seat": deal["seat"], "text": pr["text"], "check": pr["check"], "due": int(pr["due"]), "effects": pr["effects"], "met": false})
	apply_effects(deal["effects"])
	log_lines.append("Q%d deal with %s" % [quarter, deal["seat"]])
	_emit()
	return {"ok": true}

func resolve_event(option_idx: int) -> Dictionary:
	if current_event.is_empty():
		return {"ok": false, "reason": "No event pending."}
	var resp: Dictionary = current_event["responses"][option_idx]
	apply_effects(resp["effects"])
	fired_events[current_event["id"]] = true
	log_lines.append("Q%d event: %s -> %s" % [quarter, current_event["id"], resp["label"]])
	current_event = {}
	_emit()
	return {"ok": true}

# ---------------- quarter resolution ----------------

func _check_promise(pr: Dictionary) -> bool:
	var c: Dictionary = pr["check"]
	match c["type"]:
		"track":
			return track_ok(c["track"], int(c["level"]))
		"adoption":
			return bu_state(c["bu"]) == c["state"]
		"flag":
			return flags.has(c["flag"])
		"attributed":
			return attributed_pct >= int(c["value"])
		"audit":
			return audit >= int(c["value"])
		_:
			return false

func end_quarter() -> Dictionary:
	var report := {"quarter": quarter, "builds_done": [], "promises_met": [], "promises_missed": [], "event": null, "decisions": 0, "notes": []}
	# 1. builds tick
	var still := []
	for b in builds:
		b["left"] -= 1
		if b["left"] <= 0:
			tracks[b["track"]] = clamp(int(tracks[b["track"]]) + 1, 0, 3)
			report["builds_done"].append(b["track"])
		else:
			still.append(b)
	builds = still
	# 2. promises come due
	for pr in promises:
		if not pr["met"] and quarter >= int(pr["due"]):
			pr["met"] = true
			if _check_promise(pr):
				report["promises_met"].append(pr["text"])
				apply_effects(pr["effects"])
				clamp_trust(pr["seat"], 1)
				xp += 15
			else:
				report["promises_missed"].append(pr["text"])
				clamp_trust(pr["seat"], -1)
				xp -= 15
				audit = clamp(audit - 5, 0, 100)
	# 3. decisions changed - each on-platform BU produces governed decisions
	var mult := 1.0
	if track_ok("governance", 2):
		mult *= 1.5
	if flags.has("gov_in"):
		mult *= 1.25
	var base := 0
	for b in bus:
		if b["state"] == "on":
			base += 10 + int(b["level"])
	var q_decisions := int(round(base * mult * rng.randf_range(0.8, 1.2)))
	decisions_changed += q_decisions
	report["decisions"] = q_decisions
	attributed_pct = clamp(attributed_pct + (8 if track_ok("governance", 2) else 3), 0, 95)
	# 4. event: due seed beats random chain draw
	var ev: Dictionary = {}
	var seed_hit := -1
	for i in pending_seeds.size():
		if int(pending_seeds[i]["due_q"]) <= quarter + 1 and not fired_events.has(pending_seeds[i]["event_id"]):
			seed_hit = i
			break
	if seed_hit >= 0:
		var ps: Dictionary = pending_seeds[seed_hit]
		for e in deck["events"]:
			if e["id"] == ps["event_id"]:
				ev = e.duplicate(true)
				ev["seed_label"] = ps["seed_label"]
				break
		pending_seeds.remove_at(seed_hit)
	if ev.is_empty() and rng.randf() < 0.75:
		var pool: Array = []
		for e in deck["events"]:
			if quarter >= int(e.get("min_q", 99)) and not fired_events.has(e["id"]) and (int(e.get("fixed_q", -1)) == -1 or int(e["fixed_q"]) == quarter):
				if e["id"] == "cfcs_laptop_fails" and not quirk_has("cfcs_laptop"):
					continue
				var chains: Array = e.get("chains", [])
				if chains.size() > 0:
					for c in chains:
						if (c == "govern_around" and not flags.has("gov_around")) or (c == "centralize_federate" and not fork_done.has("centralize")) or (c == "standardize" and not fork_done.has("standardize")):
							continue
				pool.append(e)
		if pool.size() > 0:
			ev = pool[rng.randi_range(0, pool.size() - 1)].duplicate(true)
	# fixed events
	if ev.is_empty():
		for e in deck["events"]:
			if e.has("fixed_q") and int(e["fixed_q"]) == quarter and not fired_events.has(e["id"]):
				if e["id"] == "cfcs_laptop_fails" and not quirk_has("cfcs_laptop"):
					continue
				ev = e.duplicate(true)
				break
	if not ev.is_empty():
		current_event = ev
		report["event"] = ev["title"]
	# 5. debts tick
	for d in debts:
		if not debts[d]["answered"]:
			debts[d]["fuse"] = int(debts[d]["fuse"]) - 1
			if int(debts[d]["fuse"]) <= 0:
				debts[d]["answered"] = true  # decided by default
				scandals += 1
				audit = clamp(audit - 10, 0, 100)
				xp -= 20
				report["notes"].append("Debt '%s' fired as a crisis - decided by default." % d)
	# 6. mandate pressure
	if quarter >= clock_due and not _check_promise({"check": mandate["check"]}):
		xp -= 25
		scandals += 1
		trust["sandoval"] = clamp(int(trust["sandoval"]) - 1, -2, 2)
		report["notes"].append("Mandate missed: %s" % mandate["text"])
	# 7. PC decay to cap (capital is a flow)
	if pc > PC_CAP:
		pc = PC_CAP
	# 7b. quirk floors (e.g. load-bearing shadow env)
	for q in quirks:
		if q.has("effect") and q["effect"].has("shadow_floor"):
			shadow = max(shadow, int(q["effect"]["shadow_floor"]))
	# 8. budget refresh
	quarter += 1
	if quarter <= TOTAL_QUARTERS:
		budget += BUDGET_PER_QUARTER
		meeting_used = false
	# 9. fail states
	game_over = _fail_check()
	if game_over.is_empty() and quarter > TOTAL_QUARTERS:
		game_over = {"kind": "end", "ending": _compute_ending()}
	last_report = report
	_emit()
	return report

func _fail_check() -> Dictionary:
	if xp <= -60 and scandals >= 2:
		return {"kind": "lose", "ending": {"id": "fired", "title": "QUIETLY MOVED ON"}}
	if adoption_on() < 1 and quarter > 3:
		return {"kind": "lose", "ending": {"id": "defunded", "title": "DEFUNDED"}}
	if rival >= 100:
		return {"kind": "lose", "ending": {"id": "absorbed", "title": "ABSORBED"}}
	if scandals >= 4 and not track_ok("agent", 3):
		return {"kind": "lose", "ending": {"id": "catastrophe", "title": "THE AGENT CATASTROPHE"}}
	return {}

func _compute_ending() -> Dictionary:
	for e in deck["endings"]:
		var c: Dictionary = e["check"]
		if c.is_empty():
			continue
		if c["type"] == "track" and track_ok(c["track"], int(c["level"])):
			return e
		if c["type"] == "audit" and audit >= int(c["value"]):
			return e
	return deck["endings"][-1]

func standing_level() -> int:
	if xp >= 200: return 5
	if xp >= 120: return 4
	if xp >= 60:  return 3
	if xp >= 15:  return 2
	return 1

func standing_title() -> String:
	return ["New hire", "Known quantity", "The person who fixed Q3", "Cabinet member", "The quiet veto"][standing_level() - 1]

func save_state() -> void:
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"quarter": quarter, "seed": seed_value, "budget": budget, "crew": crew, "pc": pc,
			"xp": xp, "scandals": scandals, "audit": audit, "shadow": shadow, "rival": rival, "attributed_pct": attributed_pct,
			"decisions_changed": decisions_changed, "tracks": tracks, "trust": trust, "flags": flags, "debts": debts,
			"fork_done": fork_done, "mandate": mandate["id"], "builds": builds, "promises": promises, "bus": bus}))

func _emit() -> void:
	state_changed.emit()
