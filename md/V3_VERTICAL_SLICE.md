# COUNTER CORE v3 — Vertical Slice

## Experience target

The prototype is one short run:

1. Read three visually distinct enemy bullets.
2. Move toward the bullet type players want and parry it.
3. Decode analysis weapons through successful parries.
4. Lock exactly two decoded weapons before the boss.
5. Parry boss bullets to fill COUNTER CHARGE.
6. Manually fire one decisive COUNTER SYSTEM attack.

The primary playtest question is: **Did the player voluntarily approach danger to decode the weapon they wanted?**

## Prototype scope

- One stage and one boss
- One preselected main weapon and shield
- Three analysis weapons: RAPID, SPREAD, PIERCE
- Two locked analysis slots
- One COUNTER SYSTEM activation per boss attempt
- No combat-time main-weapon switching
- No random level-up choices or experience drops
- No permanent-stat dependency

## Readability contract

| Bullet | Analysis | Combat identity |
|---|---|---|
| Blue straight | RAPID | More frequent fire |
| Green wave | SPREAD | Wider control area |
| Red charge | PIERCE | High-risk, heavy penetration |

Color is reinforced by trajectory and card text; color alone must not carry the distinction.

## Initial tuning

- Analysis: 24 points per parry, plus 2 per current streak step (maximum +8)
- Four clean parries complete one weapon
- Wave duration: 75 seconds across three escalating scan phases
- COUNTER: 22 points per boss parry, with the same streak bonus
- Four clean boss parries ready COUNTER
- Boss core HP: 4,200
- Boss support-drone interval: 12 seconds

At the boss gate, the two most advanced scans are safely decoded if fewer than two were completed. This keeps an imperfect learning run moving without making parries irrelevant: player intent still determines which scans receive priority.

## Playtest observations

Record behavior, not only opinions:

- Which bullet did the player deliberately leave alive?
- Could they name blue/green/red effects after one run?
- Did they move toward a dangerous bullet to finish a scan?
- How long did the two-slot decision take?
- Could they explain both selected effects during the boss?
- Did they understand COUNTER only charges from boss parries?
- Did they choose a different pair for a second attempt?

Stop adding content if players cannot answer these through play. Improve telegraphing, timing, impact, or choice balance first.

## Automated check

Run with Godot 4.7:

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path . --script res://game/tests/test_v3_core.gd
```

Expected output: `V3_CORE_TEST_OK`.
