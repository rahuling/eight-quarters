## Eight Quarters — screens: title, quarter loop, event modal, results, ending.
## UI is built in code (no .tscn nesting) so headless tests can exercise it.
extends Node

const DeckScript := preload("res://scripts/deck.gd")

const COL_BG := Color("071319")
const COL_PANEL := Color("0d2530")
const COL_LINE := Color("274a56")
const COL_OAT := Color("f9f7f4")
const COL_INK := Color("0b2026")
const COL_LAVA := Color("ff3621")
const COL_AMBER := Color("ffb020")
const COL_GREEN := Color("3ecf8e")
const COL_BLUE := Color("5aa7d6")
const COL_MUT := Color("7f97a1")

var font_px: Font = null
var font_body: Font = null
var root_ctl: Control
var game_layer: Control

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_load_fonts()
	var deck := DeckScript.load_pack()
	if deck.is_empty():
		var err := _label("DECK FAILED TO LOAD - check data/banking.json", 12, COL_LAVA, true)
		err.set_anchors_preset(Control.PRESET_CENTER)
		add_child(err)
		return
	GameState.state_changed.connect(_on_state_changed)
	if OS.get_environment("EQ_SMOKE") == "1":
		_smoke(deck)
		return
	_show_title(deck)

func _load_fonts() -> void:
	if FileAccess.file_exists("res://assets/fonts/PressStart2P.ttf"):
		font_px = load("res://assets/fonts/PressStart2P.ttf")
	if FileAccess.file_exists("res://assets/fonts/VT323.ttf"):
		font_body = load("res://assets/fonts/VT323.ttf")

# ---------------- widget helpers ----------------

func _label(text: String, size: int, color: Color, px: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if px and font_px:
		l.add_theme_font_override("font", font_px)
	elif font_body:
		l.add_theme_font_override("font", font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, size: int, cb: Callable, accent: Color = COL_OAT) -> Button:
	var b := Button.new()
	b.text = text
	if font_px:
		b.add_theme_font_override("font", font_px)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", COL_OAT)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COL_INK if st != "hover" else Color("12333f")
		sb.border_color = accent if st != "disabled" else COL_MUT
		sb.set_border_width_all(2)
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override(st, sb)
	b.disabled = false
	b.pressed.connect(cb)
	return b

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = COL_LINE
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

func _hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func _trust_pips(v: int) -> String:
	var out := ""
	for i in range(5):
		var level := i - 2
		out += "#" if v >= level and v > -3 else "."
	return out

# ---------------- title ----------------

func _show_title(deck: Dictionary) -> void:
	_clear(self)
	for c in [root_ctl, game_layer]:
		if c:
			c.queue_free()
	game_layer = null
	var box := _vbox(18)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right"]:
		wrap.add_theme_constant_override(m, 60)
	wrap.add_child(box)
	add_child(wrap)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var l1 := _label("EIGHT QUARTERS", 32, COL_OAT, true)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l1)
	var l2 := _label("THE WEIGHT OF THE PLATFORM", 10, COL_AMBER, true)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l2)
	var l3 := _label("an 8-bit enterprise data & AI platform survival sim - banking pack", 18, COL_MUT)
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l3)
	box.add_child(HSeparator.new())
	box.add_child(_label("YOU ARE THE NEW HEAD OF DATA.", 16, COL_TXT(), true))
	box.add_child(_label("EVERY STAKEHOLDER IS RIGHT. CONSEQUENCES ARRIVE LATE.", 16, COL_MUT, true))
	var row := _hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_button("NEW GAME", 10, func(): start_game(deck, int(Time.get_unix_time_from_system()) % 1000000), COL_LAVA))
	var cont := _button("CONTINUE (v0.2)", 10, func(): pass, COL_MUT)
	cont.disabled = true
	row.add_child(cont)
	box.add_child(row)
	var f := _label("MIT licensed - source on github - v0.1 slice", 12, COL_MUT)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(f)

func COL_TXT() -> Color:
	return Color("c9d6dc")

func start_game(deck: Dictionary, run_seed: int) -> void:
	GameState.start_run(deck, run_seed)
	_build_game_layer()

# ---------------- game screen ----------------

func _build_game_layer() -> void:
	_clear(self)
	game_layer = Control.new()
	game_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)
	var box := _vbox(10)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 12)
	margin.add_child(box)
	game_layer.add_child(margin)
	rebuild_game()

func _rebuild_hud(box: VBoxContainer) -> void:
	var g := GameState
	var top := _panel()
	var tv := _vbox(4)
	var row := _hbox(24)
	var yr := 1 + int((g.quarter - 1) / 4.0)
	row.add_child(_label("Q%d/%d  YEAR %d" % [g.quarter, g.TOTAL_QUARTERS, yr], 10, COL_OAT, true))
	row.add_child(_label("BUDGET $%dk" % g.budget, 10, COL_OAT, true))
	row.add_child(_label("CREW %d" % int(g.crew), 10, COL_OAT, true))
	row.add_child(_label("PC %d/%d" % [g.pc, g.PC_CAP], 10, COL_LAVA, true))
	row.add_child(_label("STANDING L%d %s" % [g.standing_level(), g.standing_title().to_upper()], 10, COL_AMBER, true))
	tv.add_child(row)
	tv.add_child(_label("MANDATE: %s   (CLOCK: Q%d)" % [g.mandate["text"], g.clock_due], 15, COL_AMBER))
	top.add_child(tv)
	box.add_child(top)

func _rebuild_council(box: VBoxContainer) -> void:
	var g := GameState
	var p := _panel()
	var v := _vbox(4)
	v.add_child(_label("THE COUNCIL", 8, COL_AMBER, true))
	for s in g.deck["seats"]:
		var t: int = g.trust[s["id"]]
		var line := "%s  %s" % [s["name"], s["role"]]
		v.add_child(_label(line, 14, COL_OAT))
		v.add_child(_label("trust %s  (%+d)" % [_trust_pips(t), t], 12, COL_MUT))
	p.add_child(v)
	box.add_child(p)

func _rebuild_platform(box: VBoxContainer) -> void:
	var g := GameState
	var p := _panel()
	var v := _vbox(6)
	v.add_child(_label("PLATFORM MATURITY - BUILD ORDER IS THE GAME", 8, COL_AMBER, true))
	for t in g.deck["tracks"]:
		var lvl := int(g.tracks[t["id"]])
		var cells := ""
		for i in range(4):
			cells += "#" if i < lvl else "."
		var row := _hbox(10)
		row.add_child(_label(t["name"], 14, COL_OAT))
		row.add_child(_label("[%s] L%d %s" % [cells, lvl, t["levels"][lvl]], 14, COL_GREEN if lvl > 0 else COL_MUT))
		var cost = t["costs"][lvl] if lvl < 3 else null
		if cost != null:
			var track_id: String = t["id"]
			row.add_child(_button("BUILD L%d $%dk" % [lvl + 1, cost["budget"]], 8, func(): _do_build(track_id), COL_GREEN))
		p.add_child(row)
		for b in g.builds:
			if b["track"] == t["id"]:
				p.add_child(_label("  >> in progress - %d quarter(s) left" % b["left"], 13, COL_AMBER))
	v.add_child(_label("DECISION DEBT", 8, COL_AMBER, true))
	for d in g.deck["debts"]:
		var dd: Dictionary = g.debts[d["id"]]
		var state_txt := "ANSWERED" if dd["answered"] else "OPEN - fuse %d" % dd["fuse"]
		var debt_row := _hbox(10)
		debt_row.add_child(_label("- %s" % d["question"], 13, COL_TXT()))
		var d_id: String = d["id"]
		if not dd["answered"]:
			debt_row.add_child(_button("ANSWER (1 PC + meeting slot)", 8, func(): _do_debt(d_id), COL_AMBER))
		debt_row.add_child(_label(state_txt, 12, COL_GREEN if dd["answered"] else COL_LAVA))
		v.add_child(debt_row)
	p.add_child(v)
	box.add_child(p)

func _rebuild_right(box: VBoxContainer) -> void:
	var g := GameState
	var col := _vbox(10)
	var p1 := _panel()
	var v1 := _vbox(4)
	v1.add_child(_label("BUSINESS UNITS", 8, COL_AMBER, true))
	for b in g.bus:
		var c := COL_GREEN
		if b["state"] != "on":
			c = COL_AMBER if b["state"] == "pilot" else COL_LAVA
		v1.add_child(_label("%s - %s (L%d)" % [b["name"], b["state"].to_upper(), b["level"]], 13, c))
	p1.add_child(v1)
	col.add_child(p1)
	var p2 := _panel()
	var v2 := _vbox(4)
	v2.add_child(_label("PRESSURES", 8, COL_AMBER, true))
	v2.add_child(_label("AGUILAR'S INSTANCE  [%s] %d%%" % [_bar(g.rival), g.rival], 13, COL_LAVA if g.rival >= 60 else COL_TXT()))
	v2.add_child(_label("SHADOW-IT INDEX     [%s] %d%%" % [_bar(g.shadow), g.shadow], 13, COL_TXT()))
	v2.add_child(_label("AUDIT PATIENCE      [%s] %d%%" % [_bar(g.audit), g.audit], 13, COL_TXT()))
	v2.add_child(_label("BOARD SCANDALS: %d" % g.scandals, 13, COL_LAVA if g.scandals > 0 else COL_MUT))
	p2.add_child(v2)
	col.add_child(p2)
	var p3 := _panel()
	var v3 := _vbox(2)
	v3.add_child(_label("LOG", 8, COL_AMBER, true))
	var lines: Array = g.log_lines
	var start_i: int = maxi(0, lines.size() - 5)
	for i in range(start_i, lines.size()):
		v3.add_child(_label(lines[i], 12, COL_MUT))
	p3.add_child(v3)
	col.add_child(p3)
	box.add_child(col)

func _bar(v: int) -> String:
	var filled := int(v / 10.0)
	var out := ""
	for i in range(10):
		out += "#" if i < filled else "."
	return out

func _rebuild_actions(box: VBoxContainer) -> void:
	var g := GameState
	var p := _panel()
	var v := _vbox(6)
	v.add_child(_label("THIS QUARTER", 8, COL_AMBER, true))
	# fork
	for f in g.deck["forks"]:
		if f["quarter"] == g.quarter and not g.fork_done.has(f["id"]):
			v.add_child(_label("FORK: %s" % f["title"], 14, COL_LAVA, true))
			for i in f["options"].size():
				var idx: int = i
				var opt: Dictionary = f["options"][i]
				var btxt := "> %s   [pc %d, $%dk]" % [opt["label"], int(opt["effects"].get("pc", 0)), abs(int(opt["effects"].get("budget", 0)))]
				v.add_child(_button(btxt, 12, func(): _do_fork(f["id"], idx), COL_OAT))
	# meeting
	if not g.meeting_used:
		var deal: Dictionary = g.featured_meeting()
		if not deal.is_empty():
			v.add_child(_label("FEATURED MEETING: %s" % deal["seat"].to_upper(), 14, COL_BLUE, true))
			v.add_child(_label("you commit: %s" % deal["give"], 13, COL_TXT()))
			v.add_child(_label("you get:    %s" % deal["get"], 13, COL_TXT()))
			var mrow := _hbox(10)
			mrow.add_child(_button("SEAL IT (PC %d)" % deal["pc"], 9, func(): _do_meeting(deal), COL_GREEN))
			mrow.add_child(_label("walk away: nothing happens, nothing is promised", 12, COL_MUT))
			v.add_child(mrow)
	else:
		v.add_child(_label("Meeting slot used this quarter.", 12, COL_MUT))
	# pending event
	if not g.current_event.is_empty():
		v.add_child(_label("!! " + g.current_event["title"], 13, COL_LAVA, true))
		v.add_child(_label(g.current_event["text"], 14, COL_TXT()))
		v.add_child(_label("(%s)" % g.current_event["seed_label"], 12, COL_MUT))
		for i in g.current_event["responses"].size():
			var idx2: int = i
			var resp: Dictionary = g.current_event["responses"][i]
			var avail := g.response_available(resp)
			var req_txt := ""
			if not avail:
				req_txt = "  [locked: needs the foundation / answered debt]"
			var rb := _button("%d. %s%s" % [i + 1, resp["label"], req_txt], 12, func(): _do_event(idx2), COL_AMBER if avail else COL_MUT)
			rb.disabled = not avail
			v.add_child(rb)
	# end quarter
	var end_row := _hbox(10)
	end_row.add_child(_button("END QUARTER >>", 10, _do_end_quarter, COL_LAVA))
	end_row.add_child(_label("decisions changed so far: %d" % g.decisions_changed, 13, COL_MUT))
	v.add_child(end_row)
	p.add_child(v)
	box.add_child(p)

func rebuild_game() -> void:
	if game_layer == null:
		return
	var g := GameState
	var box: VBoxContainer = null
	for c in game_layer.get_children():
		if c is MarginContainer:
			box = c.get_child(0)
	_clear(game_layer)
	if box == null:
		_build_game_layer()
		return
	var content := _hbox(10)
	var left := _vbox(10)
	var center := _vbox(10)
	var right := _vbox(10)
	content.add_child(left)
	content.add_child(center)
	content.add_child(right)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(content)
	_rebuild_hud(box)
	_rebuild_council(left)
	_rebuild_platform(center)
	_rebuild_right(right)
	_rebuild_actions(box)
	if not g.game_over.is_empty():
		_show_ending()

func _on_state_changed() -> void:
	if game_layer:
		pass  # rebuilds are triggered explicitly after actions

# ---------------- action wrappers ----------------

func _do_build(track_id: String) -> void:
	var r: Dictionary = GameState.start_build(track_id)
	if not r["ok"]:
		print(r["reason"])
	rebuild_game()

func _do_debt(debt_id: String) -> void:
	GameState.answer_debt(debt_id)
	rebuild_game()

func _do_fork(fork_id: String, idx: int) -> void:
	GameState.make_fork(fork_id, idx)
	rebuild_game()

func _do_meeting(deal: Dictionary) -> void:
	GameState.accept_meeting(deal)
	rebuild_game()

func _do_event(idx: int) -> void:
	GameState.resolve_event(idx)
	rebuild_game()

func _do_end_quarter() -> void:
	var report: Dictionary = GameState.end_quarter()
	if not GameState.current_event.is_empty():
		rebuild_game()
		return
	_show_results(report)

# ---------------- results / ending ----------------

func _show_results(report: Dictionary) -> void:
	_clear(game_layer)
	var g := GameState
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		wrap.add_theme_constant_override(m, 40)
	var v := _vbox(10)
	wrap.add_child(v)
	add_child(wrap)
	var head := _label("QUARTER %d RESULTS" % report["quarter"], 18, COL_OAT, true)
	v.add_child(head)
	v.add_child(_label("DECISIONS CHANGED +%d   (total %d)" % [report["decisions"], g.decisions_changed], 15, COL_GREEN))
	for b in report["builds_done"]:
		v.add_child(_label("build delivered: %s" % b, 14, COL_GREEN))
	for pm in report["promises_met"]:
		v.add_child(_label("promise kept: %s" % pm, 14, COL_GREEN))
	for pm in report["promises_missed"]:
		v.add_child(_label("promise MISSED: %s" % pm, 14, COL_LAVA))
	for n in report["notes"]:
		v.add_child(_label(n, 14, COL_LAVA))
	if report.has("event") and report["event"] != null:
		v.add_child(_label("the quarter closed on: %s" % report["event"], 14, COL_AMBER))
	if GameState.game_over.is_empty():
		var foreshadow: Array = g.deck["foreshadow"]
		var line: String = foreshadow[g.rng.randi_range(0, foreshadow.size() - 1)]
		v.add_child(_label("NEXT QUARTER: " + line, 14, COL_MUT))
		v.add_child(_button("CONTINUE >>", 10, _next_after_results, COL_LAVA))
	else:
		_show_ending_panel(v)

func _next_after_results() -> void:
	if GameState.game_over.is_empty():
		_build_game_layer()

func _show_ending() -> void:
	_clear(game_layer)
	var v := _vbox(12)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		wrap.add_theme_constant_override(m, 50)
	wrap.add_child(v)
	add_child(v)
	_show_ending_panel(v)

func _show_ending_panel(v: VBoxContainer) -> void:
	var g := GameState
	var e: Dictionary = g.game_over["ending"]
	var is_win: bool = g.game_over["kind"] == "end"
	v.add_child(_label("PERFORMANCE REVIEW", 10, COL_MUT, true))
	v.add_child(_label(e["title"], 24, COL_GREEN if is_win else COL_LAVA, true))
	v.add_child(_label("decisions changed: %d" % g.decisions_changed, 15, COL_TXT()))
	v.add_child(_label("adoption: %d/6 BUs on platform" % g.adoption_on(), 15, COL_TXT()))
	v.add_child(_label("audit patience: %d%%   rival meter: %d%%   scandals: %d" % [g.audit, g.rival, g.scandals], 15, COL_TXT()))
	v.add_child(_label("final standing: L%d %s" % [g.standing_level(), g.standing_title()], 15, COL_AMBER))
	v.add_child(_label("RUN SEED: %d - post it with your score." % g.seed_value, 14, COL_MUT))
	v.add_child(_button("NEW RUN", 10, func(): _show_title(GameState.deck), COL_LAVA))

# ---------------- headless smoke ----------------

func _smoke(deck: Dictionary) -> void:
	print("SMOKE: starting run")
	start_game(deck, 2026)
	var guard := 0
	while GameState.game_over.is_empty() and guard < 40:
		guard += 1
		for f in GameState.deck["forks"]:
			if f["quarter"] == GameState.quarter and not GameState.fork_done.has(f["id"]):
				GameState.make_fork(f["id"], 0)
		if not GameState.current_event.is_empty():
			for i in GameState.current_event["responses"].size():
				if GameState.response_available(GameState.current_event["responses"][i]):
					GameState.resolve_event(i)
					break
		if GameState.game_over.is_empty():
			GameState.end_quarter()
			if GameState.game_over.is_empty():
				rebuild_game()
	print("SMOKE: finished - %s / %s | decisions=%d" % [GameState.game_over.get("kind", "?"), GameState.game_over.get("ending", {}).get("title", "?"), GameState.decisions_changed])
	print("SMOKE OK")
	get_tree().quit(0)
