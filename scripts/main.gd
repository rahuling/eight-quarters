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
const COL_PAPER := Color("efe8d8")
const COL_PINK := Color("2b2a24")
const COL_PDIM := Color("6d675a")
const COL_STAMP := Color("b3202a")
const COL_STAMPB := Color("274b8f")

var font_px: Font = null
var font_body: Font = null
var font_type: Font = null
var root_ctl: Control
var game_layer: Control
var game_box: VBoxContainer
var bg_rect: ColorRect
var report_pending := false

func _ready() -> void:
	bg_rect = ColorRect.new()
	bg_rect.color = COL_BG
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)
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
	if FileAccess.file_exists("res://assets/fonts/SpecialElite.ttf"):
		font_type = load("res://assets/fonts/SpecialElite.ttf")

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

func _paper_panel(margin: int = 26) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PAPER
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	return p

func _type_label(text: String, size: int, color: Color = COL_PINK) -> Label:
	var l := Label.new()
	l.text = text
	if font_type:
		l.add_theme_font_override("font", font_type)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _stamp(text: String, color: Color = COL_STAMP, rot: float = -6.0) -> Label:
	var l := _type_label(text, 15, color)
	l.rotation_degrees = rot
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var sb := StyleBoxFlat.new()
	sb.set_border_width_all(3)
	sb.border_color = color
	sb.set_content_margin_all(6)
	l.add_theme_stylebox_override("normal", sb)
	return l

func _autowrap_deep(node: Node) -> void:
	for c in node.get_children():
		if c is Label and c.text.length() > 24:
			c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_autowrap_deep(c)

func _paper_button(text: String, size: int, cb: Callable, accent: Color = COL_PINK) -> Button:
	var b := Button.new()
	b.text = text
	if font_type:
		b.add_theme_font_override("font", font_type)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", accent)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COL_PAPER
		sb.border_color = accent if st != "disabled" else COL_PDIM
		sb.set_border_width_all(2)
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b

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

func _clear_all() -> void:
	for c in get_children():
		if c == bg_rect:
			continue
		remove_child(c)
		c.queue_free()

func _trust_pips(v: int) -> String:
	var out := ""
	for i in range(5):
		var level := i - 2
		out += "#" if v >= level and v > -3 else "."
	return out

# ---------------- title ----------------

func _show_title(deck: Dictionary) -> void:
	_clear_all()
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
	_clear_all()
	game_layer = Control.new()
	game_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	game_layer.add_child(scroll)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 12)
	game_box = _vbox(10)
	game_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(game_box)
	scroll.add_child(margin)
	_populate_game()

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
		v.add_child(_label("%s   [%s]  L%d %s" % [t["name"], cells, lvl, t["levels"][lvl]], 14, COL_OAT))
		if lvl < 3:
			var cost = t["costs"][lvl]
			var track_id: String = t["id"]
			v.add_child(_button("BUILD L%d   $%dk - %d eng - %d quarter(s)" % [lvl + 1, cost["budget"], cost["crew"], cost["quarters"]], 9, func(): _do_build(track_id), COL_GREEN))
		for b in g.builds:
			if b["track"] == t["id"]:
				v.add_child(_label("   >> in progress - %d quarter(s) left" % b["left"], 13, COL_AMBER))
	v.add_child(_label("DECISION DEBT - unanswered questions fire as crises", 8, COL_AMBER, true))
	for d in g.deck["debts"]:
		var dd: Dictionary = g.debts[d["id"]]
		v.add_child(_label("- " + d["question"], 13, COL_TXT()))
		var drow := _hbox(10)
		var d_id: String = d["id"]
		if not dd["answered"]:
			drow.add_child(_button("ANSWER (1 PC + meeting slot)", 9, func(): _do_debt(d_id), COL_AMBER))
		drow.add_child(_label("ANSWERED" if dd["answered"] else "OPEN - fuse %d" % dd["fuse"], 12, COL_GREEN if dd["answered"] else COL_LAVA))
		v.add_child(drow)
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
			var f_id: String = f["id"]
			for i in f["options"].size():
				var idx: int = i
				var opt: Dictionary = f["options"][i]
				var btxt := "> %s   [pc %d, $%dk]" % [opt["label"], int(opt["effects"].get("pc", 0)), abs(int(opt["effects"].get("budget", 0)))]
				v.add_child(_button(btxt, 12, func(): _do_fork(f_id, idx), COL_OAT))
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
	# pending event - arrives as a paper memo modal
	if not g.current_event.is_empty():
		v.add_child(_label("A memo has arrived - see the paper on your desk.", 13, COL_AMBER))
	# end quarter
	var end_row := _hbox(10)
	end_row.add_child(_button("END QUARTER >>", 10, _do_end_quarter, COL_LAVA))
	end_row.add_child(_label("decisions changed so far: %d" % g.decisions_changed, 13, COL_MUT))
	v.add_child(end_row)
	p.add_child(v)
	box.add_child(p)

func rebuild_game() -> void:
	if game_layer == null or game_box == null:
		_build_game_layer()
		return
	_clear(game_box)
	_populate_game()

func _populate_game() -> void:
	var g := GameState
	_rebuild_hud(game_box)
	var content := _hbox(10)
	var left := _vbox(10)
	var center := _vbox(10)
	var right := _vbox(10)
	left.custom_minimum_size = Vector2(225, 0)
	right.custom_minimum_size = Vector2(250, 0)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(left)
	content.add_child(center)
	content.add_child(right)
	game_box.add_child(content)
	_rebuild_council(left)
	_rebuild_platform(center)
	_rebuild_right(right)
	_rebuild_actions(game_box)
	_autowrap_deep(left)
	_autowrap_deep(right)
	_autowrap_deep(center)
	if not g.current_event.is_empty():
		_event_modal(game_layer)
	if not g.game_over.is_empty():
		_show_ending()

func _on_state_changed() -> void:
	if game_layer:
		pass  # rebuilds are triggered explicitly after actions

# ---------------- action wrappers ----------------

func _event_modal(parent: Control) -> void:
	var g := GameState
	var ev: Dictionary = g.current_event
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var pp := _paper_panel(28)
	pp.custom_minimum_size = Vector2(580, 0)
	center.add_child(pp)
	var v := _vbox(6)
	pp.add_child(v)
	var head := _type_label("INTEROFFICE MEMORANDUM", 18)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	v.add_child(HSeparator.new())
	v.add_child(_type_label("FROM:    The building", 14))
	v.add_child(_type_label("TO:      Head of Data", 14))
	v.add_child(_type_label("RE:      " + ev["title"], 14))
	v.add_child(_type_label(ev["text"], 15))
	v.add_child(_type_label("SEED NOTE: " + ev["seed_label"], 12, Color("8c2a20")))
	v.add_child(_type_label("Please indicate your course of action and return this memo:", 13, COL_PDIM))
	for i in ev["responses"].size():
		var idx: int = i
		var resp: Dictionary = ev["responses"][i]
		var avail: bool = g.response_available(resp)
		var locktxt := "" if avail else "   [needs the foundation / answered debt]"
		var b := _paper_button("[ ]  " + resp["label"] + locktxt, 14, func(): _do_event(idx), COL_PINK if avail else COL_PDIM)
		b.disabled = not avail
		v.add_child(b)
	var stamprow := _hbox(0)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamprow.add_child(spacer)
	stamprow.add_child(_stamp("FILED Q%d" % g.quarter))
	v.add_child(stamprow)
	v.add_child(_type_label("sign & return by end of quarter - cc: The Council", 12, COL_PDIM))

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
	if report_pending:
		report_pending = false
		_show_results(GameState.last_report)
	else:
		rebuild_game()

func _do_end_quarter() -> void:
	var report: Dictionary = GameState.end_quarter()
	if not GameState.current_event.is_empty():
		report_pending = true
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
		wrap.add_theme_constant_override(m, 30)
	add_child(wrap)
	var pp := _paper_panel(30)
	wrap.add_child(pp)
	var v := _vbox(7)
	pp.add_child(v)
	var head := _type_label("INTEROFFICE MEMORANDUM - QUARTER RESULTS", 17)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	v.add_child(HSeparator.new())
	v.add_child(_type_label("RE: Quarter %d - filed by the Head of Data" % report["quarter"], 14, COL_PDIM))
	v.add_child(_type_label("DECISIONS CHANGED +%d   (running total: %d)" % [report["decisions"], g.decisions_changed], 16, Color("1d7a52")))
	for b in report["builds_done"]:
		v.add_child(_type_label("delivered to the estate: %s" % b, 14))
	for pm in report["promises_met"]:
		var metrow := _hbox(12)
		metrow.add_child(_stamp("DELIVERED", Color("1d7a52"), -4.0))
		metrow.add_child(_type_label(pm, 14))
		v.add_child(metrow)
	for pm in report["promises_missed"]:
		var missrow := _hbox(12)
		missrow.add_child(_stamp("MISSED - ON FILE", COL_STAMP, 3.0))
		missrow.add_child(_type_label(pm, 14, Color("8c2a20")))
		v.add_child(missrow)
	for n in report["notes"]:
		v.add_child(_type_label(n, 14, Color("8c2a20")))
	if report.has("event") and report["event"] != null:
		v.add_child(_type_label("the quarter closed on: %s" % report["event"], 14, COL_PDIM))
	if g.game_over.is_empty():
		var foreshadow: Array = g.deck["foreshadow"]
		var line: String = foreshadow[g.rng.randi_range(0, foreshadow.size() - 1)]
		v.add_child(_type_label("NEXT QUARTER: " + line, 14, COL_PDIM))
		var btnrow := _hbox(0)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btnrow.add_child(sp)
		var cb := _paper_button("CONTINUE >>", 14, _next_after_results, COL_STAMPB)
		btnrow.add_child(cb)
		v.add_child(btnrow)
	else:
		_show_ending()

func _next_after_results() -> void:
	if GameState.game_over.is_empty():
		_build_game_layer()

func _show_ending() -> void:
	_clear(game_layer)
	var v := _vbox(12)
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		wrap.add_theme_constant_override(m, 50)
	wrap.add_child(v)
	add_child(wrap)
	_show_ending_panel(v)

func _show_ending_panel(v: VBoxContainer) -> void:
	var g := GameState
	var e: Dictionary = g.game_over["ending"]
	var is_win: bool = g.game_over["kind"] == "end"
	var pp := _paper_panel(34)
	v.add_child(pp)
	var v2 := _vbox(9)
	pp.add_child(v2)
	var head := _type_label("PERFORMANCE REVIEW - END OF YEAR 3 - CONFIDENTIAL", 15, COL_PDIM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v2.add_child(head)
	v2.add_child(HSeparator.new())
	var et := _type_label(e["title"], 26, Color("1d7a52") if is_win else COL_STAMP)
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v2.add_child(et)
	v2.add_child(_type_label("decisions changed: %d" % g.decisions_changed, 15))
	v2.add_child(_type_label("business units on the platform: %d of 6" % g.adoption_on(), 15))
	v2.add_child(_type_label("audit patience: %d%%   -   Aguilar's instance: %d%%   -   board scandals: %d" % [g.audit, g.rival, g.scandals], 15))
	v2.add_child(_type_label("final standing: L%d %s" % [g.standing_level(), g.standing_title()], 15, COL_PDIM))
	var stamprow := _hbox(0)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamprow.add_child(sp)
	stamprow.add_child(_stamp(e["title"], Color("1d7a52") if is_win else COL_STAMP, -3.0))
	v2.add_child(stamprow)
	v2.add_child(_type_label("RUN SEED: %d - post it with your score." % g.seed_value, 13, COL_PDIM))
	var btnrow := _hbox(0)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btnrow.add_child(sp2)
	btnrow.add_child(_paper_button("NEW RUN", 14, func(): _show_title(GameState.deck), COL_STAMP))
	v2.add_child(btnrow)

# ---------------- headless smoke ----------------

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/eq_" + name + ".png")

func _smoke(deck: Dictionary) -> void:
	print("SMOKE: starting run")
	start_game(deck, 2026)
	await _shot("game")
	var guard := 0
	while GameState.game_over.is_empty() and guard < 40:
		guard += 1
		for f in GameState.deck["forks"]:
			if f["quarter"] == GameState.quarter and not GameState.fork_done.has(f["id"]):
				GameState.make_fork(f["id"], 0)
		if not GameState.current_event.is_empty():
			rebuild_game()
			await _shot("event")
			for i in GameState.current_event["responses"].size():
				if GameState.response_available(GameState.current_event["responses"][i]):
					GameState.resolve_event(i)
					break
		if GameState.game_over.is_empty():
			GameState.end_quarter()
			if GameState.game_over.is_empty():
				rebuild_game()
	print("SMOKE: finished - %s / %s | decisions=%d" % [GameState.game_over.get("kind", "?"), GameState.game_over.get("ending", {}).get("title", "?"), GameState.decisions_changed])
	if GameState.last_report.size() > 0:
		_show_results(GameState.last_report)
		await _shot("results")
	_show_ending()
	await _shot("ending")
	print("SMOKE OK")
	get_tree().quit(0)
