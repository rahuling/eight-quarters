## Headless logic tests. Run:
##   Godot --headless --path . --script res://tests/test_logic.gd
## Exits 0 on pass, 1 on failure.
extends SceneTree

const DeckScript := preload("res://scripts/deck.gd")
const GameStateScript := preload("res://scripts/game_state.gd")

var failures := 0
var checks := 0

func check(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  PASS  " + name)
	else:
		failures += 1
		print("* FAIL  " + name)

func _initialize() -> void:
	print("== Eight Quarters — logic tests ==")
	var deck := DeckScript.load_pack()
	check(deck.size() > 0, "deck loads and validates")

	var g := GameStateScript.new()
	g.start_run(deck, 12345)
	check(g.mandate.has("id"), "run starts: mandate drawn")
	check(g.quirks.size() == 2, "run starts: 2 quirks drawn")
	check(g.trust["torres"] == 1 and g.trust["aguilar"] == -2, "starting trust from deck")

	# determinism
	var g2 := GameStateScript.new()
	g2.start_run(deck, 12345)
	check(g2.mandate["id"] == g.mandate["id"], "same seed -> same mandate")
	check(g2.quirks[0]["id"] == g.quirks[0]["id"], "same seed -> same quirks")
	var g3 := GameStateScript.new()
	g3.start_run(deck, 999)
	var differs: bool = g3.mandate["id"] != g.mandate["id"] or g3.quirks[0]["id"] != g.quirks[0]["id"]
	check(differs, "different seed -> different draw (probabilistic)")

	# PC cap
	g.pc = 12
	g.end_quarter()
	check(g.pc <= g.PC_CAP, "PC decays to cap (capital is a flow)")

	# fork: apply + seed scheduling
	g = GameStateScript.new()
	g.start_run(deck, 777)
	var fr := g.make_fork("centralize", 1)   # federate: seeds shadow_prod
	check(fr["ok"], "fork applies")
	check(g.pending_seeds.size() == 1 and g.pending_seeds[0]["event_id"] == "shadow_prod", "fork schedules a seed event")
	check(g.make_fork("centralize", 0)["ok"] == false, "fork cannot be re-taken")
	check(g.make_fork("govern_around", 0)["ok"] == false, "future fork not available yet")

	# builds: budget/crew deduction + completion
	g = GameStateScript.new()
	g.start_run(deck, 42)
	var b0 := g.budget
	var r := g.start_build("governance")     # L1: 200k, 1 eng, 1 quarter
	check(r["ok"], "build starts: governance L1")
	check(g.budget == b0 - 200, "build charges budget")
	g.end_quarter()
	check(g.track_ok("governance", 1), "build completes after its quarters")

	# agent gates: L1 (read-only pilots) allowed, L2 blocked until the foundation exists
	g = GameStateScript.new()
	g.start_run(deck, 42)
	check(g.start_build("agent")["ok"] == true, "agent L1 (read-only pilot) allowed")
	g.tracks["agent"] = 1
	var l2 := g.start_build("agent")
	check(l2["ok"] == false, "agent L2 gated: answers-with-receipts needs Gov2+Id2+protocol")
	g.tracks["governance"] = 2
	g.tracks["identity"] = 2
	g.debts["agent_wrong"]["answered"] = true
	check(g.start_build("agent")["ok"] == true, "agent L2 unlocks when the foundation exists")

	# events: req gating
	g = GameStateScript.new()
	g.start_run(deck, 555)
	for e in deck["events"]:
		if e["id"] == "schema_friday":
			g.current_event = e.duplicate(true)
	var resp_ok := g.resolve_event(0)      # req joined_ownership debt — not answered
	check(resp_ok["ok"] == true, "event resolves")
	# gating is a UI-visibility rule; engine enforces via response_available
	g.current_event = {}
	for e in deck["events"]:
		if e["id"] == "schema_friday":
			g.current_event = e.duplicate(true)
	check(g.response_available(g.current_event["responses"][0]) == false, "req-gated response hidden (ownership unanswered)")
	g.debts["joined_ownership"]["answered"] = true
	check(g.response_available(g.current_event["responses"][0]) == true, "req-gated response unlocks after answering the debt")

	# promises: met and missed paths
	g = GameStateScript.new()
	g.start_run(deck, 31337)
	for m in deck["meetings"]:
		if m["seat"] == "cruz":
			var mr := g.accept_meeting(m)
			check(mr["ok"], "meeting deal seals (cruz)")
			check(g.promises.size() == 1, "promise recorded")
	g.tracks["paved"] = 1                     # fulfil "paved L1 by Q3" early
	while g.quarter <= 3:
		g.end_quarter()
	var found_met := false
	for pr in g.promises:
		if pr["seat"] == "cruz":
			found_met = pr["met"]
	check(found_met, "promise evaluates met when condition holds")

	# rival lose state
	g = GameStateScript.new()
	g.start_run(deck, 8)
	g.rival = 100
	g.end_quarter()
	check(g.game_over.get("kind", "") == "lose" and g.game_over["ending"]["id"] == "absorbed", "rival meter maxes -> ABSORBED")

	# decisions scoring scales with adoption + governance multiplier
	var ga := GameStateScript.new()
	ga.start_run(deck, 90210)
	var low := 0
	ga.end_quarter()
	low = ga.last_report["decisions"]
	ga.tracks["governance"] = 2
	ga.end_quarter()
	var high: int = int(ga.last_report["decisions"])
	check(high > low, "governance L2 multiplies decisions changed (%d -> %d)" % [low, high])

	# save / load round trip (file IO)
	g = GameStateScript.new()
	g.start_run(deck, 4242)
	g.save_state()
	check(FileAccess.file_exists("user://save.json"), "save writes user://save.json")

	# full 8-quarter lockstep run reaches an ending, no crash
	g = GameStateScript.new()
	g.start_run(deck, 2026)
	var crashed := false
	while g.game_over.is_empty() and g.quarter <= g.TOTAL_QUARTERS:
		for f in deck["forks"]:
			if f["quarter"] == g.quarter and not g.fork_done.has(f["id"]):
				g.make_fork(f["id"], 0)
		if not g.current_event.is_empty():
			var picks := -1
			for i in g.current_event["responses"].size():
				if g.response_available(g.current_event["responses"][i]):
					picks = i
					break
			if picks >= 0:
				g.resolve_event(picks)
		g.end_quarter()
	check(not crashed and not g.game_over.is_empty(), "8 quarters run to a resolution")
	if not g.game_over.is_empty():
		print("  ->  final state: %s / %s | decisions=%d audit=%d rival=%d scandals=%d" % [g.game_over["kind"], g.game_over["ending"]["title"], g.decisions_changed, g.audit, g.rival, g.scandals])

	print("== %d checks, %d failures ==" % [checks, failures])
	quit(1 if failures > 0 else 0)
