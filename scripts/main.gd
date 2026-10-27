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
var intro_layer: Control = null
var intro_clicked := false
var intro_skip := false
var intro_hint: Label = null
var intro_run := 0
var overlay: Control = null

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
	_show_intro(deck)

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

# ---------------- intro cutscene (click to advance, 5s auto) ----------------

func _center_label(text: String, size: int, color: Color, px: bool = false) -> Label:
	var l := _label(text, size, color, px)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _show_intro(deck: Dictionary) -> void:
	_clear_all()
	intro_run += 1
	var my_run := intro_run
	intro_skip = false
	intro_layer = Control.new()
	intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(intro_layer)
	var bgd := ColorRect.new()
	bgd.color = Color(0.02, 0.05, 0.07)
	bgd.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_layer.add_child(bgd)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 50)
	intro_layer.add_child(margin)
	var body := _vbox(14)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(body)
	intro_hint = _label(">> CLICK TO CONTINUE <<", 9, COL_AMBER, true)
	intro_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	intro_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_hint.visible = false
	intro_layer.add_child(intro_hint)
	var catcher := Button.new()
	catcher.flat = true
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		catcher.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	catcher.pressed.connect(func(): intro_clicked = true)
	intro_layer.add_child(catcher)
	var skipb := _button("SKIP", 9, func(): intro_skip = true, COL_MUT)
	skipb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skipb.position = Vector2(-90, 14)
	skipb.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skipb.offset_left = -110.0
	skipb.offset_right = -14.0
	skipb.offset_top = 14.0
	intro_layer.add_child(skipb)
	_play_intro(body, deck, my_run)

func _intro_gate(t: float) -> void:
	intro_clicked = false
	if intro_hint:
		intro_hint.visible = true
	var elapsed := 0.0
	while elapsed < t and not intro_clicked:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if intro_hint:
		intro_hint.visible = false

func _play_intro(body: VBoxContainer, deck: Dictionary, my_run: int) -> void:
	var smoke := OS.get_environment("EQ_SMOKE") == "1"
	var gate_t := 0.2 if smoke else 5.0
	var alive := func() -> bool: return not intro_skip and my_run == intro_run and is_instance_valid(body)
	# beat 1 - the bank
	_clear(body)
	body.add_child(_center_label("SOMEWHERE IN THE REGION", 10, COL_LAVA, true))
	body.add_child(_center_label("A LARGE BANK", 30, COL_OAT, true))
	body.add_child(_center_label("IN SOUTHEAST ASIA", 30, COL_OAT, true))
	var sky := _hbox(6)
	sky.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 5:
		var r := ColorRect.new()
		r.color = Color("123540")
		r.custom_minimum_size = Vector2(60 + (i * 37) % 80, 90 + (i * 53) % 120)
		r.size_flags_vertical = Control.SIZE_SHRINK_END
		sky.add_child(r)
	body.add_child(sky)
	body.add_child(_center_label("Eight thousand people. Sixty systems. One very old warehouse.", 18, COL_MUT))
	await _intro_gate(gate_t)
	if not alive.call(): return
	# beat 2 - the inheritance
	_clear(body)
	body.add_child(_center_label("WHAT YOU INHERIT", 10, COL_LAVA, true))
	for s in ["A data warehouse, eight years old. The regulator expects its reports every quarter.",
	"An analytics env Marketing stood up on a different cloud. Ungoverned. Production-critical.",
	"A half-finished migration. The last CTO started it. Nobody remembers why.",
	"And treasury's nightly reconciliation - running on someone's laptop."]:
		body.add_child(_center_label(s, 17, COL_TXT()))
	await _intro_gate(gate_t)
	if not alive.call(): return
	# beat 3 - the offer
	_clear(body)
	body.add_child(_center_label("The CEO has a job for you.", 20, COL_TXT()))
	body.add_child(_center_label("HEAD OF DATA", 32, COL_OAT, true))
	body.add_child(_center_label("Your term: EIGHT QUARTERS. Two fiscal years, one sitting.", 18, COL_MUT))
	body.add_child(_center_label("Your budget: whatever survives the board.", 18, COL_MUT))
	await _intro_gate(gate_t)
	if not alive.call(): return
	# beat 4 - the stakes, explicit
	_clear(body)
	body.add_child(_center_label("THE STAKES - WHAT YOU CAN LOSE", 10, COL_LAVA, true))
	body.add_child(_center_label("YOUR JOB - two board scandals with your standing at zero.", 16, COL_AMBER))
	body.add_child(_center_label("YOUR BUDGET - adoption below one BU, and the cuts come for you.", 16, COL_AMBER))
	body.add_child(_center_label("THE PLATFORM - Aguilar's meter at 100%%, and the remit is his.", 16, COL_AMBER))
	body.add_child(_center_label("THE AGENTS - one scandal you cannot contain ends the program.", 16, COL_AMBER))
	body.add_child(_center_label("The mandate clock is real. Miss it and it is a scandal.", 16, COL_MUT))
	await _intro_gate(gate_t)
	if not alive.call(): return
	# beat 5 - the rules, explicit design points
	_clear(body)
	body.add_child(_center_label("THE FIVE RULES OF THIS WORLD", 10, COL_LAVA, true))
	body.add_child(_center_label("1. Foundation before AI - the gates are real.", 16, COL_OAT))
	body.add_child(_center_label("2. Adoption is a series of purchases - BUs choose you.", 16, COL_OAT))
	body.add_child(_center_label("3. Ownership reaches the tables - or 2am owns you.", 16, COL_OAT))
	body.add_child(_center_label("4. Blame costs trust, not capital - keep the ledger true.", 16, COL_OAT))
	body.add_child(_center_label("5. Decisions changed is the only score.", 16, COL_OAT))
	await _intro_gate(gate_t)
	if not alive.call(): return
	# beat 6 - the cast
	_clear(body)
	body.add_child(_center_label("SIXTEEN SEATS AT THE TABLE", 10, COL_AMBER, true))
	body.add_child(_center_label("A CEO who wants agents. A CISO who will veto them. A CFO who owns your budget.", 17, COL_TXT()))
	body.add_child(_center_label("A CRO who owns the regulator. A BU lead who will route around you.", 17, COL_TXT()))
	body.add_child(_center_label("And Tomas Aguilar, who thinks the platform should be his - and is not wrong.", 17, COL_AMBER))
	body.add_child(_center_label("Some will save you. Some will end you. All of them are right.", 18, COL_OAT))
	await _intro_gate(gate_t)
	if not alive.call(): return
	_show_title(deck)

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
	row.add_child(_button("REPLAY INTRO", 9, func(): _show_intro(deck), COL_MUT))
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
	intro_run += 1
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
	row.add_child(_button("? HELP", 8, _help_view, COL_BLUE))
	tv.add_child(row)
	tv.add_child(_label("MANDATE: %s   (CLOCK: Q%d)" % [g.mandate["text"], g.clock_due], 15, COL_AMBER))
	if g.clock_due - g.quarter <= 1:
		tv.add_child(_label("!! MANDATE DUE NEXT QUARTER - MISS = BOARD SCANDAL", 12, COL_LAVA, true))
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
	v2.add_child(_label("rival 100 = remit moves: ABSORBED", 11, COL_LAVA))
	v2.add_child(_label("2 scandals + standing 0 = FIRED", 11, COL_LAVA))
	v2.add_child(_label("adoption <1 BU = DEFUNDED", 11, COL_LAVA))
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
			v.add_child(_label("DECISION REQUIRED", 9, COL_LAVA, true))
			v.add_child(_label("FORK: %s" % f["title"], 14, COL_OAT, true))
			var open_row := _hbox(10)
			var f_ref: Dictionary = f
			open_row.add_child(_button("OPEN DECISION >>", 10, func(): _decision_view(f_ref), COL_LAVA))
			open_row.add_child(_label("both options, full effects and seeded consequences shown", 12, COL_MUT))
			v.add_child(open_row)
	# meeting
	if not g.meeting_used:
		var deal: Dictionary = g.featured_meeting()
		if not deal.is_empty():
			v.add_child(_label("FEATURED MEETING: %s" % deal["seat"].to_upper(), 14, COL_BLUE, true))
			v.add_child(_label("you commit: %s" % deal["give"], 13, COL_TXT()))
			v.add_child(_label("you get:    %s" % deal["get"], 13, COL_TXT()))
			var pr: Dictionary = deal["promise"]
			var pl := _label("PROMISE: %s - due Q%d. %s" % [pr["text"], pr["due"], _promise_miss_text(pr)], 12, COL_MUT)
			pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(pl)
			var gain := ", ".join(_fx_summary(deal["effects"]))
			if gain != "":
				var gl := _label("also gains: " + gain, 12, COL_GREEN)
				gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				v.add_child(gl)
			var mrow := _hbox(10)
			mrow.add_child(_button("SEAL IT (PC %d)" % deal["pc"], 9, func(): _do_meeting(deal), COL_GREEN))
			mrow.add_child(_label("walk away: nothing promised, nothing owed", 12, COL_MUT))
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

func _clear_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

func _fx_summary(e: Dictionary) -> Array:
	var out: Array = []
	if e.has("budget"):
		out.append(("$%dk" % int(e["budget"])) if int(e["budget"]) >= 0 else ("- $%dk" % -int(e["budget"])))
	if e.has("pc"):
		out.append(("PC +%d" % int(e["pc"])) if int(e["pc"]) >= 0 else ("PC -%d" % -int(e["pc"])))
	if e.has("audit"):
		out.append(("audit +%d" % int(e["audit"])) if int(e["audit"]) >= 0 else ("audit -%d" % -int(e["audit"])))
	if e.has("scandal"):
		out.append("+%d board scandal(s)" % int(e["scandal"]))
	if e.has("shadow"):
		out.append(("shadow-it +%d" % int(e["shadow"])) if int(e["shadow"]) >= 0 else ("shadow-it -%d" % -int(e["shadow"])))
	if e.has("rival"):
		out.append(("Aguilar +%d" % int(e["rival"])) if int(e["rival"]) >= 0 else ("Aguilar -%d" % -int(e["rival"])))
	if e.has("xp"):
		out.append(("standing +%d" % int(e["xp"])) if int(e["xp"]) >= 0 else ("standing %d" % int(e["xp"])))
	if e.has("points"):
		out.append("+%d decisions" % int(e["points"]))
	if e.has("progress"):
		for t in e["progress"]:
			out.append("%s +%d level(s)" % [str(t).to_upper(), int(e["progress"][t])])
	if e.has("progress_loss"):
		for t in e["progress_loss"]:
			out.append("%s -%d level(s)" % [str(t).to_upper(), int(e["progress_loss"][t])])
	if e.has("adoption"):
		for b in e["adoption"]:
			out.append("%s -> %s" % [str(b).to_upper(), str(e["adoption"][b])])
	if e.has("trust"):
		for s in e["trust"]:
			var sname := str(s).to_upper()
			for seat in GameState.deck["seats"]:
				if seat["id"] == s:
					sname = str(seat["name"])
			out.append("%s %+d trust" % [sname, int(e["trust"][s])])
	if e.has("flag"):
		out.append("unlocks: %s" % str(e["flag"]).replace("_", " "))
	if e.has("crew_loss"):
		out.append("platform team halved")
	return out

func _promise_miss_text(pr: Dictionary) -> String:
	var c: Dictionary = pr["check"]
	match c["type"]:
		"track":
			return "Miss = %s must reach L%d or trust pays." % [str(c["track"]).to_upper(), int(c["level"])]
		"attributed":
			return "Miss = attribution under %d%% at the due quarter costs trust." % int(c["value"])
		"adoption":
			return "Miss = %s not %s costs trust." % [str(c["bu"]).to_upper(), str(c["state"])]
		"flag":
			return "Miss = the commitment stays on file, unredeemed."
		_:
			return "Miss = trust -1, audit -5."

func rebuild_game() -> void:
	if game_layer == null or game_box == null:
		_build_game_layer()
		return
	_clear(game_box)
	_clear_overlay()
	_populate_game()

func _decision_view(f: Dictionary) -> void:
	var g := GameState
	_clear_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_layer.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 18)
	overlay.add_child(margin)
	var v := _vbox(8)
	margin.add_child(v)
	v.add_child(_label("A STRUCTURAL DECISION - the consequences land 2 to 6 quarters from now", 9, COL_LAVA, true))
	v.add_child(_label(f["title"], 17, COL_OAT, true))
	var dp := _label("DESIGN POINT - from '%s': %s" % [f["article"], f.get("lesson", "")], 12, COL_MUT)
	dp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(dp)
	var opts := _hbox(14)
	opts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(opts)
	for i in f["options"].size():
		var idx: int = i
		var opt: Dictionary = f["options"][i]
		var card := _panel()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opts.add_child(card)
		var cv := _vbox(6)
		card.add_child(cv)
		var ol := _label(opt["label"], 13, COL_OAT, true)
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(ol)
		if opt.has("desc"):
			var dl := _label(opt["desc"], 13, COL_TXT())
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(dl)
		cv.add_child(_label("EFFECTS:", 8, COL_AMBER, true))
		for fx in _fx_summary(opt["effects"]):
			cv.add_child(_label("- " + fx, 12, COL_TXT()))
		var seed_name = opt.get("seed", null)
		if seed_name != null:
			for e in g.deck["events"]:
				if e["id"] == seed_name:
					var sl := _label("SEEDS: '%s' - it will land in a later quarter." % e["title"], 12, COL_LAVA)
					sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					cv.add_child(sl)
					break
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(spacer)
		cv.add_child(_button("CHOOSE THIS", 10, func(): _choose_fork(f["id"], idx), COL_LAVA))
	v.add_child(_label("HELP: forks are the structural bets - centralize or federate, govern in or around, standardize or not, foundation or AI. No option is 'correct'; each one seeds different events and changes which seats trust you. Costs are political capital and budget; both are visible above.", 12, COL_MUT))
	var hl := v.get_child(v.get_child_count() - 1)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _choose_fork(fork_id: String, option_idx: int) -> void:
	GameState.make_fork(fork_id, option_idx)
	rebuild_game()

func _help_view() -> void:
	_clear_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_layer.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var pp := _paper_panel(30)
	pp.custom_minimum_size = Vector2(640, 0)
	center.add_child(pp)
	var v := _vbox(8)
	pp.add_child(v)
	var head := _type_label("HOW THIS WORKS", 20)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	v.add_child(HSeparator.new())
	var sections := [
		["THE LOOP", "Each quarter: allocate budget and crew, hold one featured meeting, take the quarter's decisions, resolve what comes due, read the results. Eight quarters, one sitting."],
		["CURRENCIES", "POLITICAL CAPITAL buys decisions and deals. It caps at 8 - spend it or lose it. BUDGET builds tracks. CREW builds them. All three are shown in the HUD."],
		["TRACKS", "Governance, Identity and Paved Road unlock capabilities for the estate. Agent-Readiness is gated: you cannot build it without the foundation - ship early and the wrong-answer event picks the moment."],
		["MAKING CHOICES", "FORKS are structural bets: what you pick seeds future events and changes which seats trust you. MEMOS (events) demand a response - the seed note tells you which past decision caused them."],
		["PROMISES", "Meeting deals become dated promises. Met: trust +1 and the deal's effects. Missed: trust -1, audit -5, and it stays on file."],
		["METERS", "Adoption = BUs building on the platform. Shadow-IT = work routing around you. Audit patience = the regulator's mood. Aguilar = the rival's instance gaining on you."],
		["FAILING", "You lose the job (2 scandals + standing 0), the budget (adoption under 1 BU), the platform (Aguilar 100), or the agents (4 scandals). Every one is defensible in hindsight."],
		["SCORING", "Decisions Changed is the score AND your budget leverage with the CFO. Certified data, receipts and joint ownership multiply it."],
	]
	for s in sections:
		v.add_child(_type_label(s[0], 14, Color("8c2a20")))
		var b := _type_label(s[1], 14)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(b)
	var btnrow := _hbox(0)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btnrow.add_child(sp)
	btnrow.add_child(_paper_button("CLOSE", 14, _close_help, COL_STAMPB))
	v.add_child(btnrow)

func _close_help() -> void:
	_clear_overlay()
	rebuild_game()

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
	if ev.has("lesson"):
		v.add_child(_type_label("DESIGN NOTE: " + ev["lesson"], 13, Color("1d7a52")))
	v.add_child(_type_label("Please indicate your course of action and return this memo:", 13, COL_PDIM))
	for i in ev["responses"].size():
		var idx: int = i
		var resp: Dictionary = ev["responses"][i]
		var avail: bool = g.response_available(resp)
		var locktxt := "" if avail else "   [needs the foundation / answered debt]"
		var b := _paper_button("[ ]  " + resp["label"] + locktxt, 14, func(): _do_event(idx), COL_PINK if avail else COL_PDIM)
		b.disabled = not avail
		v.add_child(b)
		var chiprow := _hbox(8)
		for fx in _fx_summary(resp["effects"]):
			chiprow.add_child(_type_label("- " + fx, 12, COL_PDIM))
		v.add_child(chiprow)
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
	if report.has("lesson") and str(report["lesson"]) != "":
		v.add_child(_type_label("WHAT THIS TAUGHT: " + str(report["lesson"]), 14, Color("1d7a52")))
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
	print("SMOKE: intro")
	_show_intro(deck)
	await _shot("intro")
	print("SMOKE: starting run")
	start_game(deck, 2026)
	await _shot("game")
	var guard := 0
	while GameState.game_over.is_empty() and guard < 40:
		guard += 1
		for f in GameState.deck["forks"]:
			if f["quarter"] == GameState.quarter and not GameState.fork_done.has(f["id"]):
				_decision_view(f)
				await _shot("decision")
				GameState.make_fork(f["id"], 0)
				rebuild_game()
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
