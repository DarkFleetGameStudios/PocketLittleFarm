# Pocket Little Farm — Build Plan: "Design Your Farm" (v2)

Status: proposed. Supersedes v1. The difference from v1 is not features — it's the
**driver philosophy**. v1 kept the current time-punishes-you model and built on top of it.
v2 rebuilds the core loop around the FarmTown-solo feel: you plant, you leave, you come
back to *collect*, and design is the thing you're actually building toward.

## The one design rule everything obeys

> **The clock may cost efficiency. It may never cost progress.
> The login grants progress. It never just prevents loss.**

Time is *texture* — crops grow, hens lay, the world feels alive while you're gone. Logins
are the *driver* — showing up is what banks rewards and advances the farm. Today it's
inverted: the wall clock destroys crops and spoils goods, while returning gives almost
nothing but the morning post. v2 flips the weight. Tune every number in this doc against
the rule above; don't re-litigate it per feature.

## Why (the short version)

The player resets their own farm to have something to do. That's the whole diagnosis: there
is no farm being *built*, and the clock only ever *takes*, so loss is painless and novelty
means wiping. Fix isn't harder farming — it's a farm worth returning to, a soft clock, and a
tempo the player chooses.

---

## The core-loop model (FarmTown-solo)

FarmTown — the single-player experience, which is the one that matters here — worked like
this, and it's the target:

- **Plant once, harvest once.** No frantic mid-growth tending. FarmTown had *no watering at
  all*; the only interaction was plant → wait → harvest.
- **Crop choice is your tempo.** Quick crops for active players; slow cash crops for
  once-a-day players. The seed menu sets the cadence, not the engine.
- **The only failure was a soft one:** miss the (generous) harvest window after maturity and
  the crop degrades. One deadline, at the end, forgiving.
- **Level up → unlock** crops, buildings, and farm expansions. Design and decoration were
  the point.

We keep watering, because it's a verb the player likes — but we **demote it from kill-switch
to yield dial.** New model:

- A planted crop **always grows to ripe and is always harvestable.** Neglect never kills it
  mid-growth.
- **Watering sets yield, not survival.** Final yield scales with the fraction of grow time
  the plot was watered, floored at ~50%. Water on your check-ins → full yield. Never water →
  half yield, but you keep the crop.
- After ripe, a long **over-ripe window** (≈ 2× grow time). Past it, the crop drops to
  "past-prime" (reduced yield), and only after a further long stretch becomes compost. No
  instant funerals.
- The **Well decoration auto-waters its neighbors** → passive full yield. Now watering is
  something you can *build your way out of needing*, which is exactly the point of the build
  loop.

This is what fixes "the engine's too fast." The felt speed comes mostly from the 30-minute
watering-or-death cadence, which FarmTown never had — not from grow durations alone.

---

## Phase 0 — Save safety (precondition, unchanged from v1)

Every phase below adds fields to the save. Today a save missing *any* non-optional field
throws and `SaveStore.load` silently returns `.fresh()` — a wipe. We cannot build safely
until saves survive schema growth.

- **Tolerant decoding:** custom `SaveGame.init(from:)` with `decodeIfPresent` + defaults.
- **Real migration:** a `migrate(_:from:to:)` step so `currentVersion` bumps mean something;
  each new field lands with its default here.
- **Quarantine, don't wipe:** on decode failure, rename to `savegame.corrupt-<ts>.json`
  before returning fresh.
- **Backup on write:** keep the previous good file as `savegame.bak`.
- **Fix the spoilage merge bug:** `addItem` merges without updating `acquiredAt`, so
  `spoilInventory` drops whole stacks — including fresh items — on the oldest member's age
  (verified: 30 fresh radishes vanish because 3 stack-mates were 11h old). Weighted-average
  `acquiredAt` on merge. Needed before Phase 2's Shed/Scarecrow touch spoilage.

**Exit:** old/short saves load intact; corrupt file quarantined + fresh; mixed-age merge
spoilage test passes.

---

## Phase 1 — Core-loop reframe (the "too fast" fix) ⭐ NEW, do right after Phase 0

This is the feel fix and the heart of the FarmTown-solo target. It's contained almost
entirely in the sim (`FarmSimulator` + `CropDefinition`), so it's fast and fully unit-testable.

- **Remove wilt-to-lost as a death path during growth.** `advancePlot` no longer transitions
  a growing crop to `.lost` from neglect. Growth always completes.
- **Watering → yield.** Track watered fraction on the plot; compute harvest yield from it,
  floored at 50%. Repurpose the existing `thirstyAccumulated`/`sinceWatered` fields (or add
  `growWateredTime`) — additive schema change, handled by Phase 0 migration.
- **Over-ripe window.** Add `ripeSince`; ripe crops hold for ≈ 2× grow time, then degrade to
  past-prime (reduced yield), then compost. Keeps "come back and collect" pressure without
  loss.
- **Stretch timers so crop choice = tempo.** See the balance table below.
- **Re-tune the `.thirsty`/`.wilted` phases** as *cosmetic/advisory* states ("needs water for
  best yield") rather than a countdown to death. The status chips in `FarmScene` become
  guidance, not alarms.

**Exit:** an unwatered crop reaches ripe at ~50% yield and never dies; a watered one hits
full yield; a ripe crop left for a day is still harvestable; time-skip tests cover all three.

### Proposed crop balance (starting point — tune, don't treat as final)

Watering is now a yield dial, so the table shows full vs. floor yield. Timers stretched so
the menu spans "quick turn" to "daily crop." Short crops earn more per hour (reward active
play); long crops earn less per hour but are set-and-forget (reward patience) — the FarmTown
tempo tradeoff.

| Crop | Grow (was → now) | Water model | Yield full / floor | Sell | Over-ripe window | Role |
|------|------------------|-------------|--------------------|------|------------------|------|
| Radish | 45m → **2h** | optional, +yield | 3 / 2 | 14 | +4h | quick turn |
| Lettuce | 2h → **4h** | optional, +yield | 3 / 2 | 20 | +8h | short |
| Tomato | 4h → **8h** | optional, +yield | 3 / 2 | 34 | +16h | half-day |
| Corn | 6h → **12h** | optional, +yield | 4 / 2 | 42 | +1d | evening/morning |
| Pumpkin | 14h → **24h** | optional, +yield | 2 / 1 | 130 | +2d | daily cash crop |

Key change vs. today: **`waterEvery` / `thirstGrace` / `wiltToLost` stop being death timers.**
`waterEvery` becomes "how often watering tops up the yield meter"; the wilt fields retire or
become advisory. Radish stays the fast option but at 2h it's no longer a 75-minute leash.

---

## Phase 2 — Functional decoration placement (the keystone)

The feature that turns "meh grid" into "layout matters." Mostly wired already:
`placeDecoration` exists in the sim with **no UI calling it**, `PlacedDecoration` carries
`row`/`col`, and `rebuildDecor` already renders placed items.

- **Effect metadata on `DecorationDefinition`:** `waterAdjacent` (Well → passive full yield
  for neighbors), `protectYield` (Scarecrow → radius keeps full yield with no watering),
  `preserveGoods` (Shed / the "bunk for sorting goods" → stored goods don't spoil),
  `growthBoost` (Lantern → faster growth in radius), `none` (pure charm). Plus a `charm` value.
- **Fix the `emoji` field** — it mixes real emoji with literal words (`"Scarecrow"`,
  `"lantern"`); `rebuildDecor` would render the text. Real emoji or atlas keys.
- **Placement mode:** tap a decoration in the bag → tap a tile → `placeDecoration`. Highlight
  valid tiles using the existing status-chip layer.
- **Remove / refund:** new `removeDecoration(id:)` returning the item to the bag. Today
  decorations are a one-way sink.
- **Buff engine:** a pure `activeBuffs(for:in:)` reading nearby decorations by row/col; wire
  into `advancePlot` (Well/Scarecrow/Lantern) and `spoilInventory` (Shed). Stays testable
  with no scene state.

**First shippable slice:** placement + the **Well** + remove/refund. Smallest change that
proves "where I put this matters," and it makes watering optional exactly where you build it.

---

## Phase 3 — Progression / the unlock spine

Make `unlockedCropIds` real — today it exists on `SaveGame` and is just set to all crops and
ignored. This is the farm-to-build-toward.

- **Radish is the free floor;** everything else is earned. The morning post always tops up
  radish + coins, so you can't lock yourself out.
- **XP + levels** from planting/harvesting/fulfilling requests; levels unlock crops,
  buildings, and plot rows (FarmTown's actual spine).
- **Gate the shop:** `ShopView` shows unlock requirements on locked rows instead of a price.
- **Plot expansion:** `gridRows`/`gridCols` are constants → expansion is a data change, not
  an engine rewrite. Start new farms *smaller* (e.g. 4×4) so growth is a visible reward;
  migrate existing 6×6 saves to fully-unlocked.
- **Farm Charm:** sum `charm` over placed decorations → scales the daily morning-post payout.
  Now the path, fence, and washi *pay coins* — designing is an income strategy. (This is the
  clean expression of the driver rule: cosmetic effort pays out **on the login**, via the
  morning post, not via the clock.)

**Exit:** fresh save starts radish-only and small; earning levels unlocks a crop + a plot
row; charm changes the next morning post.

---

## Phase 4 — The login-driven reasons to return

Retention and coin-sink are the same object; all of it pays out **on arrival**, per the rule.

- **Market Board:** a daily rotating request ("5 radishes + 3 eggs → 60 coins + XP"). Drains
  the bag, pays on the visit, rerolls each day so novelty replaces resets. Seed it
  deterministically from the day key — stable within a day, fully offline.
- **Streaks as reward, not threat:** the existing `careStreakDays` grants escalating morning
  posts, never punishes a miss. (Also fixes `noteCare`, whose streak branches are currently
  identical.)
- **Weekly shop rotation / traveling merchant:** a small changing stock — a reason to peek.
- **Local notifications:** wire the already-present-but-dead `notificationsEnabled` flag —
  "your pumpkins are ripe," "today's board expires soon." This is what actually pulls people
  back, and it's the login model's natural nudge. Offline, no server.

**Exit:** a request appears, is fulfillable, pays out, rerolls next day; opting in schedules a
real local reminder.

---

## Phase 5 — Rebalance & cleanup

Three sinks now live (functional decor, plot expansion, Market Board), so retune coins and
verify the tempo table feels right in real time-skip testing. Fold in the review housekeeping:

- `feedAllChickens` charges feed even when hens are already content (`hungryCount` is really
  total count) — only charge when someone's hungry.
- Dead `guard def.kind != .seed || true` in `sell` — remove.
- `debugSkip` ships think-out-loud comments and drops real elapsed time — clean up (public repo).
- Wire `PlayerSettings.soundEnabled` / `reduceMotion` (README lists accessibility as a want;
  the field already exists).
- Swift 6 readiness: `FarmBalance.dayKeyFormatter` is a shared non-`Sendable` `DateFormatter`
  across actors — fine in 5.9, a hard error under Swift 6 language mode.

---

## Sequencing

| Phase | Ships | Delivers |
|-------|-------|----------|
| 0 | Save migration, spoilage fix | Safe to grow the schema |
| 1 | ⭐ Core-loop reframe + crop retune | "Not too fast" — the FarmTown feel |
| 2 | Placement + Well + remove/refund | "Layout matters" |
| 3 | XP/unlocks, plots, charm | "A farm to build toward" |
| 4 | Market Board, streaks, notifications | "A reason to come back" |
| 5 | Rebalance + cleanup | Ship-ready |

Every phase is independently shippable and testable. The sim stays a pure
`(SaveGame, Date) -> SaveGame` engine throughout, so all of it is unit-testable without the
UI — the current test pattern extends directly.

## Open questions (decide before Phase 3)

1. **Unlock currency:** XP/levels only, or a separate token from the Market Board too?
   Recommend XP/levels as the spine, board pays coins + XP.
2. **Starting grid:** keep 6×6, or start 4×4 so expansion is a reward? Recommend 4×4 for new
   saves, migrate existing to fully-unlocked.
3. **Watering payoff shape:** linear yield-with-watered-fraction, or a simpler
   watered-once-for-bonus? Recommend the fraction model, but validate it isn't fiddly in
   time-skip testing.
4. **Do the `.thirsty`/`.wilted` phases stay visible** (as advisory "wants water") or get
   folded into a single "growing" state with a yield meter? Leaning advisory-visible so
   watering still feels responsive.
