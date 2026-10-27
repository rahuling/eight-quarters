# Eight Quarters — v0.1 slice (banking pack)

An 8-bit enterprise data & AI platform survival sim. You are the new Head of Data.
Inherit the mess, launch the platform, survive the politics, decide whether the
agents get unleashed. Eight quarters. Every stakeholder is right. Consequences arrive late.

**PLAY IN BROWSER: https://rahuling.github.io/eight-quarters/** (published automatically by CI on every push to main)

Built with Godot 4.7 (MIT). Free, open source, zero dependencies.

## Run it

1. Install Godot 4.7+ (godotengine.org) — no other tools needed.
2. Open this folder as a project in the Godot editor, press F5.
   Or from a terminal:

       Godot --path .

## Headless tests

The logic core (economy, forks, seeds, promises, fail states) has a test suite:

    Godot --headless --path . --script res://tests/test_logic.gd

Exits 0 when green. CI-ready.

## How a quarter plays

1. **Allocate (quiet)** — start builds on 4 maturity tracks (Governance, Identity,
   Paved Road, Agent-Readiness), answer decision-debt questions before their fuses fire.
2. **Featured meeting (loud)** — one set-piece negotiation per quarter. Seal the deal
   and it becomes a dated promise in the ledger. Miss the due date and trust pays.
3. **Resolve (consequence)** — events fire with their seed cited
   ("seeded by Q2: govern around it") and a response choice. Never a dice readout.
4. **Results tally** — Decisions Changed (your score AND your budget leverage),
   buffs, exactly one foreshadow line.

## Systems in this slice

- 6 named seats + 1 rival (Tomas Aguilar, VP Infrastructure — his meter maxes, you're Absorbed)
- CEO mandate drawn per run (5 variants) + 2 of 6 estate quirks
- Agent-readiness gates: L2 needs Governance 2 + Identity 2 + the "agent was wrong" protocol
- Political capital capped at 8 (it's a flow, not a hoard); blame costs trust, not PC
- Fail states: Fired / Defunded / Absorbed / Agent catastrophe — each defensible in hindsight
- Endings: The Agent-Ready CDAO / The Regulator's Favourite / The Survivor
- Seeded runs: your run prints its seed — share it with your score

## Design sources

- `../outline.md` — concept
- `../progression-design.md` — points & leveling systems
- `../greenlight-review.md` — the studio critique that shaped this slice
- `../cast.md` — who these people are
- `../mockups.html`, `../cutscene.html` — the 8-bit look and animated intro

## License

MIT (code). Game text and content: CC BY 4.0.
