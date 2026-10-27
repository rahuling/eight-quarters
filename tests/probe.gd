extends SceneTree

const DeckScript := preload("res://scripts/deck.gd")
const GS := preload("res://scripts/game_state.gd")

func _initialize() -> void:
	print("probe: start")
	var deck := DeckScript.load_pack()
	print("probe: deck size ", deck.size())
	var g := GS.new()
	print("probe: game_state instantiated")
	g.start_run(deck, 12345)
	print("probe: run started, mandate=", g.mandate["id"], " quirks=", g.quirks.size())
	var r := g.end_quarter()
	print("probe: end_quarter returned, quarter=", g.quarter, " decisions=", r["decisions"])
	quit(0)
