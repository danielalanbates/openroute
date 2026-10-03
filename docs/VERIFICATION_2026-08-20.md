# Verification run — 2026-08-20

Every result below came from the live clients on this machine, not from offline tests.
Chart of record: `docs/verification.sqlite` (schema + report queries in `docs/verification.sql`).

## Guide coverage — does every guide load on every version?

`/cr verifyall` parses **and fully loads** every registered guide (both factions), then reports.
Armed without typing in the client via `tools/queue_verify.py` (see below).

| flavor | client | guides OK | total | failed |
|---|---|---:|---:|---:|
| era | `_classic_era_` | 1445 | 1445 | **0** |
| tbc | `_anniversary_` | 1641 | 1641 | **0** |
| mop | `_classic_` | 4430 | 4430 | **0** |
| retail | `_retail_` | 9519 | 9519 | **0** |

Mists started this run at 4420/4423. The three failures were real defects, fixed and re-verified:
* WoW-Pro `s` (speak-with) steps were rejected as a bad action → now normalise to a note step.
* Two imported legacy guides supply their text through a lazy function that returns empty, which slipped past
  `Guide.Register`'s placeholder guard and appeared in the browser as unloadable 0-step entries →
  `Guide.Steps` now marks them `g.empty` and `Guide.Available` hides them.

(For reference, the same sweep on 2026-08-19 reported 52 failures on Mists.)

## Feature matrix — does each feature actually work on each version?

`/cr verifyfeatures`, which also runs silently 30s after every login.

| feature | check | era | tbc | mop | retail |
|---|---|---|---|---|---|
| account | store initialised | PASS | PASS | PASS | PASS |
| account | opt-in flag | PASS | PASS | PASS | PASS |
| account | opt-in gate honoured | PASS | PASS | PASS | PASS |
| account | character roster | PASS | PASS | PASS | PASS |
| account | per-guide progress math | PASS | PASS | PASS | PASS |
| account | quest-level union | PASS | PASS | PASS | PASS |
| beacon | module loaded | PASS | PASS | PASS | PASS |
| beacon | names mined from current step | PASS | PASS | PASS | PASS |
| beacon | nameplate API present | PASS | PASS | PASS | PASS |
| beacon | nameplate rescan runs | PASS | PASS | PASS | PASS |
| beacon | map pin library | PASS | PASS | PASS | PASS |
| beacon | pins placed for step coords | PASS | PASS | PASS | PASS |
| beacon | target button secure macro | PASS | PASS | PASS | PASS |
| core | guides registered | PASS | PASS | PASS | PASS |
| core | guide loaded + routed | PASS | PASS | PASS | PASS |
| core | arrow shown | PASS | PASS | PASS | PASS |

`core / arrow shown` failed on the first TBC run. It was a verifier race, not a fault — the arrow
only paints on its own OnUpdate tick, and the check ran before the first tick. The check now drives
one `Arrow.Update()` first. Confirmed by probe in the live client: `UPD true nil true`.

## Screenshots (`docs/screenshots/`)

| file | what it shows |
|---|---|
| `guide_menu_tbc.png` | the renamed browser, "CompletionRoute Guides (1524)", **Next Step** first |
| `next_step_category_tbc.png` | Next Step expanded at level 66: 77 level-matched guides, ETA-sorted — Terokkar Forest [64-66] ~4m, then Blade's Edge Mountains [65-67] ~7m (active) |
| `arrow_and_route_tbc.png` | the arrow with target name, distance and ETA, plus the `/run` probes |
| `inworld_era.png` | Classic Era, Mankrik: guide loaded, arrow routing to Thunder Bluff, 16/16 features |
| `inworld_mop.png` | Mists: Vashj'ir guide, route "take the boat Menethil Harbor", 16/16 features |

## How this was driven (for the next AI)

* **Do not type long slash commands through synthetic keystrokes.** WoW's chat edit box regularly
  swallows everything after the first character; the command silently does nothing and you will
  chase a phantom. Evidence: a screenshot showing `Say: /` after sending `/cr verifyall`.
* Use `python3 tools/queue_verify.py <flavor…>` instead. It writes
  `CompletionRouteDB.autoVerifyAll = true` into the account SavedVariables; the addon runs the
  sweep itself 35s after login and clears the flag. For a client that has never written
  SavedVariables, hand-write a two-line stub file — that works too, and is how retail was armed.
* **Arm *after* the previous session has fully quit.** The client rewrites SavedVariables from
  memory on logout and will clobber an arm written while it was still running. This cost one run.
* Battle.net: the GAME VERSION dropdown must be opened **and** clicked inside the *same* python
  process — re-activating the app closes the popup. The full product list lives on the WoW page.
  Classic Era launches into Hardcore by default; switch realms from the character screen
  (Change Realm → a `Normal` realm) rather than fighting the LAUNCH INTO dropdown.
* Screenshot with `screencapture -x -o -l <window id>`: it works on occluded windows, so nothing
  has to be raised or minimised. The retina buffer is 2x — click points are screenshot pixels ÷ 2
  (or × window_width / image_width when the shot was downsized).
* The CGWindow owner name is `Wow`, not `World of Warcraft`.
* Do not enter the world on a Hardcore character to run tests, and check whether the character you
  land on is dead before doing anything.

---

# Second pass — every feature exercised in-world (Mists, a different character)

Run on **Thorfirn-Maladath**, a level 16 Rogue in Darnassus — deliberately not the character used
in the first pass. Name check first: **CompletionRoute** is unused — 0 projects on CurseForge,
0 repositories on GitHub, no web results.

| Feature | Evidence |
|---|---|
| Over-head marker | `docs/screenshots/overhead_icon_mop.png` — the game's yellow quest `!` over two Darnassus Sentinels and on the target frame; `demo (settled): modernPlates=6 overHeadMarkers=2` |
| Target/mouseover frame marker | same shot, `targetFrameMarker=true` |
| One-click target button | `targetButton=Darnassus Sentinel` |
| Map pins | `pins=1 pin(s) on map 89` (Darnassus) |
| Next Step category | `docs/screenshots/next_step_mop.png` — 272 matches at level 16, every bracket contains 16, ETA-sorted (6m, 11m, 20m, 22m, 24m…), with account-wide % badges |
| Account-wide roster | `docs/screenshots/account_roster_mop.png` — three characters across three realms, current one starred |
| Guide browser | 4264 guides, 12 categories, Next Step first |
| Arrow + routing | "Talk to Darnassus Sentinel, 0 yd, ETA ~0s" |
| Whole-catalogue sweep | 4430/4430, 0 failed |
| Feature verifier | 16/16 |

## Defects this pass found (all fixed, all now covered by offline tests)

1. **The over-head marker never worked.** `C_NamePlate.GetNamePlates(true)` passes `isSecure`;
   from insecure addon code that returns nothing. The self-check had been reporting PASS because it
   only asserted the *API existed*. Fixed, plus a WorldFrame fallback for clients that expose no
   plates through `C_NamePlate` at all.
2. **A refactor had deleted five slash commands** (`chars`, `accountwide`, `forget`, `beacon`,
   `verifyfeatures`) when a dead code block was removed. Nothing caught it because those commands
   are only reachable by typing. Restored, and there is now a test asserting every documented
   command is both handled and advertised in the help line.
3. **The bulk sweep wrote into real progress** — 4470 steps across 4384 guides on one character.
   Now sandboxed; `tools/clean_sweep_progress.py` cleaned the records older builds wrote.
4. **The marker stuttered** because it was re-anchored on every rescan mid-animation. Anchoring is
   now idempotent and the bob is optional.
5. **An unplaced map pin floated in the middle of the screen** — we were calling `Show()` on pin
   frames that HereBeDragons had declined to place. HBD owns their visibility now.
6. **The arrow's item button painted an empty ring** when a recommendation had neither an item nor
   a spell.

Note: the gold starburst visible near the arrow in these screenshots belongs to the legacy commercial addon, which was
still installed on this client — not to CompletionRoute.

## Verification lesson

The feature verifier passed 16/16 while the headline feature was completely broken, because the
checks asserted that APIs *existed* rather than that the feature *did something*. Checks now assert
observable effects (markers actually shown, pins actually placed, errors surfaced instead of
swallowed by `pcall`). When adding a feature, make its check fail if the feature does nothing.
