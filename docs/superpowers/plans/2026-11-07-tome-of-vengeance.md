# Tome of Vengeance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW addon (Retail, Classic, Forever) that records every enemy player you kill and who kills you, and presents it as a WAR-style open-book Tome with unlocks, titles, toasts and nemesis alerts.

**Architecture:** Pure-Lua `Core/` (combat-log classification, attribution, records, titles, nemesis) and `Data/` (races, classes, titles, sounds) are unit-tested under LuaJIT with no WoW API. A thin WoW glue layer (`Compat.lua`, `TomeOfVengeance.lua`) turns client events into Core calls and Core's returned announcements into UI calls. `UI/` renders the book, toast and settings, and is smoke-tested headless against a minimal WoW API stub.

**Tech Stack:** Lua 5.1 (WoW), LuaJIT for tests, luacheck, GitHub Actions, CurseForge API, Wago (GitHub webhook).

**Spec:** `docs/superpowers/specs/2026-11-07-tome-of-vengeance-design.md` (mockup: `docs/superpowers/specs/assets/2026-11-07-tome-layout-mockup.html`). Conventions reference: `~/repos/azeroth-ante`.

## Global Constraints

- Addon folder `TomeOfVengeance/`, TOC `TomeOfVengeance.toc`, SavedVariables `TomeOfVengeanceDB` (account-wide).
- Every file starts `local _, ns = ...` and exports onto `ns` (azeroth-ante pattern). No globals except `TomeOfVengeanceDB`, slash-command globals and the compartment callback.
- `Core/` and `Data/` must not call any WoW API. Time, player GUID, secret-value checks and lookups are passed in.
- No Warhammer IP: no WAR audio, art, fonts or text; never the strings "Tome of Knowledge" or "Book of Grudges".
- No bundled audio in v1. Sounds are WoW built-ins resolved at runtime.
- Must never throw in combat or taint the default UI. Every WoW-event handler body runs inside `pcall`. Restricted/secret combat-log values are skipped quietly.
- Use capability checks (function/namespace exists) over version checks.
- Kills: only killing blows by you (or your own pet/guardian, see Review Focus) on hostile **players**. Duels excluded.
- Deaths: attributed to the last hostile player who damaged you within the attribution window. No hostile player in the window → not recorded.
- Race pages: Classic/Forever list only races of the faction(s) opposite to factions the account has played, plus neutral races; Retail lists every race. Class pages list every class playable on the client.
- Retail arena/rated-BG tracking is best-effort and does not block release.
- UI tone: leather frame, parchment pages, small-caps headings, dark red accents, gold-bordered toast (per mockup). Not a spreadsheet.
- Indent 2 spaces in Lua/TOC; `.editorconfig` and `.gitignore` already copied from azeroth-ante.
- Commits: `lgulliver <liamgulliver@gmail.com>`, Conventional Commits, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Decisions made in this plan (builder's calls from the spec)

- Attribution window **12 s**. No assists in v1.
- Title tiers **10, 50, 100, 250, 500, 1000** per race and per class (first kill = unlock, no title). Overall tiers **1, 10, 50, 100, 250, 500, 1000**. Titles are enUS only in v1. Race/class display names come from the client (localised).
- Nemesis threshold default **3**. Alert throttle **300 s** per player. Revenge window **300 s**.
- Ledger keeps the last **200** events.
- Sounds resolved by `SOUNDKIT` key with numeric fallback 8959 (raid warning).
- Settings live as a page inside the Tome (works on every flavour). A Blizzard Settings category is registered only as a launcher where `Settings.RegisterCanvasLayoutCategory` exists.
- Minimap button on all flavours (toggleable). Addon compartment entry on Retail via TOC `AddonCompartmentFunc`.
- Slash commands `/tov` and `/tome` (verify no clash on CurseForge in Task 1).
- Book textures: WoW built-in art first. A custom texture is only added if built-ins can't hit the mockup, and must be original or CC0.

## Review Focus

1. **Pet/guardian killing blows.** A hunter's pet or warlock's demon landing the blow on an enemy player should count as your kill. Test in Task 3.
2. **Non-player hostile targets.** Killing an enemy hunter's pet, a mind-controlled NPC or a totem must not count, even though it's hostile. Test in Task 3.
3. **Player info not cached yet.** `GetPlayerInfoByGUID` can return nil for a GUID seen for the first time. The record must still be written (name from the combat log, race/class backfilled later) and must not unlock or credit a race/class until known. Test in Task 4.
4. **Secret or missing combat-log values** (Retail raids/M+, possibly arenas). Any secret field → event skipped, no error, nothing recorded. Test in Task 3.
5. **Duel ending in "death".** A duel loss isn't a death and a duel win isn't a kill, including a hit from the duel opponent just before an unrelated real death. Test in Task 3.

---

## File structure

```
TomeOfVengeance/
  TomeOfVengeance.toc
  TomeOfVengeance.lua      -- bootstrap: SavedVariables, event frame, slash commands, glue Core <-> UI
  Compat.lua               -- WoW API wrappers: flavour, player info, secret check, instance context, sound
  Data/Races.lua           -- race list: raceFile, raceID, faction, since(expansion)
  Data/Classes.lua         -- class list: classFile, classID, since
  Data/Titles.lua          -- tier thresholds, templates, per-entry overrides, overall + special titles
  Data/Sounds.lua          -- curated sound shortlist per alert kind
  Core/Store.lua           -- DB schema, defaults, migrate, player record get/create
  Core/Roster.lua          -- which races/classes the Tome lists for a flavour + factions
  Core/Attribution.lua     -- rolling hostile-damage buffer, killer lookup
  Core/CombatLog.lua       -- classify a combat-log event into kill/damage/ignore
  Core/Record.lua          -- apply a kill/death to the DB, return announcements
  Core/Titles.lua          -- evaluate newly earned titles
  Core/Nemesis.lua         -- nemesis test, list, alert throttle
  UI/Theme.lua             -- colours, fonts, texture paths, frame helpers
  UI/Toast.lua             -- queued unlock/title toast and red nemesis banner, plays sound
  UI/Book.lua              -- open-book frame, left index, right page host, Escape to close
  UI/Pages/Races.lua       -- race index + race entry
  UI/Pages/Classes.lua     -- class index + class entry
  UI/Pages/Nemeses.lua
  UI/Pages/Ledger.lua
  UI/Pages/Titles.lua      -- earned titles, choose active title
  UI/Pages/Settings.lua
  UI/Minimap.lua           -- minimap button + compartment callback
tests/
  run.lua                  -- copy of azeroth-ante runner, folder name changed
  syntax.lua
  wow_stub.lua             -- minimal WoW API stub for headless runs
  smoke_ui.lua             -- loads full TOC under stub, drives events and UI
  test_store.lua, test_roster.lua, test_combatlog.lua, test_record.lua,
  test_titles.lua, test_nemesis.lua
.github/workflows/{test,lint,release}.yml
.github/scripts/upload-curseforge.sh
.luacheckrc, README.md, CHANGELOG.md, CONTRIBUTING.md, LICENSE
```

## Shared shapes (all tasks use these)

```lua
-- Normalised combat-log event (built by glue from CombatLogGetCurrentEventInfo)
ev = { subevent = "PARTY_KILL", sourceGUID = "...", sourceName = "...", sourceFlags = 0x...,
       destGUID = "...", destName = "...", destFlags = 0x... }

-- Context passed with every kill/death
ctx = { now = <epoch seconds, time()>, clock = <GetTime()>, kind = "world"|"battleground"|"arena",
        zone = "Elwynn Forest", subzone = "Goldshire", char = "Name-Realm", faction = "Horde"|"Alliance" }

-- Enemy identity (glue fills from GetPlayerInfoByGUID; fields may be nil if not cached)
who = { guid = "Player-...", name = "Fizzlewick", realm = "Stormrage", raceFile = "Gnome",
        raceID = 7, classFile = "MAGE", faction = "Alliance" }

-- Announcement (Core -> UI)
ann = { kind = "unlock"|"title"|"nemesis", header = "...", title = "...", reason = "..." }
```

DB (`TomeOfVengeanceDB`, `version = 1`):

```lua
{ version = 1,
  settings = { alerts = true, sound = true, nemesisThreshold = 3, minimap = true,
               sounds = { unlock = "RAID_WARNING", title = "RAID_WARNING", nemesis = "RAID_WARNING" } },
  players  = { [guid] = { name, realm, raceFile, raceID, classFile, faction, level, guild,
                          kills = 0, deaths = 0,
                          ctx = { world = {k=0,d=0}, battleground = {k=0,d=0}, arena = {k=0,d=0} },
                          chars = { ["Me-Realm"] = {k=0,d=0} },
                          first = { t, zone }, last = { t, zone }, killedMeAt = nil } },
  races    = { [raceFile]  = { kills = 0, deaths = 0, unlockedAt = nil } },
  classes  = { [classFile] = { kills = 0, deaths = 0, unlockedAt = nil } },
  total    = { kills = 0, deaths = 0 },
  titles   = { [titleId] = earnedAt }, activeTitle = nil,
  ledger   = { { t, kind = "kill"|"death", guid, zone, ctxKind }, ... },  -- newest last, max 200
  factionsSeen = { Horde = true } }
```

---

### Task 1: Scaffold + Store

**Files:**
- Create: `TomeOfVengeance/TomeOfVengeance.toc`, `TomeOfVengeance/Core/Store.lua`, `tests/run.lua`, `tests/syntax.lua`, `tests/test_store.lua`, `.luacheckrc`, `.github/workflows/test.yml`, `.github/workflows/lint.yml`, `LICENSE` (MIT, "Liam Gulliver"), `README.md` (stub: name, one-line pitch, install), `CHANGELOG.md` (`## Unreleased`), `CONTRIBUTING.md` (adapt azeroth-ante's).

**Interfaces:**
- Produces: `ns.Store.DEFAULTS`, `ns.Store.migrate(db) -> db` (fills missing keys in place, sets `version = 1`, idempotent), `ns.Store.player(db, who, ctx) -> rec` (get or create; updates name/realm/race/class/faction only when the new value is non-nil; sets `first` on create and `last` every call), `ns.Store.charKey(name, realm) -> "Name-Realm"`.

- [ ] **Step 1:** Copy `~/repos/azeroth-ante/tests/run.lua` and `tests/syntax.lua`; replace `AzerothAnte` with `TomeOfVengeance`. Copy `.luacheckrc` structure with globals `TomeOfVengeanceDB`, `SLASH_TOMEOFVENGEANCE1`, `SLASH_TOMEOFVENGEANCE2`, `SlashCmdList`, `TomeOfVengeance_OnCompartmentClick`; extend `read_globals` as later tasks add API use.
- [ ] **Step 2:** Write TOC: `## Interface:` with current Retail and Forever (16001) interfaces copied from azeroth-ante (`120100, 120105, 120107, 16001`), `## Title: Tome of Vengeance`, `## Notes: Remember every foe you've slain and every foe who slew you.`, `## SavedVariables: TomeOfVengeanceDB`, `## Version: 0.1.0`, `## AddonCompartmentFunc: TomeOfVengeance_OnCompartmentClick`. File list in load order: Data/*, Core/*, Compat.lua, UI/*, TomeOfVengeance.lua. (Classic interfaces are added in Task 11.)
- [ ] **Step 3: Failing tests** in `tests/test_store.lua`:

```lua
T.test("migrate_fills_defaults", function()
  local db = ns.Store.migrate({})
  T.eq(db.version, 1)
  T.eq(db.settings.nemesisThreshold, 3)
  T.eq(db.total, { kills = 0, deaths = 0 })
  T.eq(db.ledger, {})
end)
T.test("migrate_keeps_existing", function()
  local db = ns.Store.migrate({ settings = { nemesisThreshold = 5 }, total = { kills = 9, deaths = 1 } })
  T.eq(db.settings.nemesisThreshold, 5); T.eq(db.settings.alerts, true); T.eq(db.total.kills, 9)
end)
T.test("player_create_and_backfill", function()
  local db = ns.Store.migrate({})
  local ctx = { now = 100, zone = "Duskwood" }
  local r = ns.Store.player(db, { guid = "G1", name = "Fizz" }, ctx)
  T.eq(r.raceFile, nil); T.eq(r.first, { t = 100, zone = "Duskwood" })
  ns.Store.player(db, { guid = "G1", raceFile = "Gnome", classFile = "MAGE" }, { now = 200, zone = "Elwynn Forest" })
  T.eq(r.name, "Fizz"); T.eq(r.raceFile, "Gnome"); T.eq(r.last, { t = 200, zone = "Elwynn Forest" })
  T.eq(r.first.t, 100)
end)
T.test("same_name_different_guid", function()
  local db = ns.Store.migrate({})
  local a = ns.Store.player(db, { guid = "G1", name = "Bob", realm = "A" }, { now = 1 })
  local b = ns.Store.player(db, { guid = "G2", name = "Bob", realm = "B" }, { now = 1 })
  T.ok(not rawequal(a, b))
end)
```

- [ ] **Step 4:** `luajit tests/run.lua store` → FAIL (`ns.Store` nil).
- [ ] **Step 5:** Implement `Core/Store.lua`.
- [ ] **Step 6:** `luajit tests/run.lua && luajit tests/syntax.lua && luacheck TomeOfVengeance` → all pass, 0 warnings.
- [ ] **Step 7:** Workflows: copy azeroth-ante `test.yml` (drop the seed sweep and Media steps; keep unit tests, smoke (added in Task 7, guard with `if [ -f tests/smoke_ui.lua ]` until then), syntax) and `lint.yml` (args `TomeOfVengeance`). Same pinned action SHAs.
- [ ] **Step 8:** Search CurseForge/Wago for `/tov` and `/tome` slash clashes; note result in README "Usage". If `/tome` clashes with a popular addon, drop the alias.
- [ ] **Step 9: Commit** `feat: scaffold addon and saved-variable store`.

### Task 2: Races, classes, roster

**Files:**
- Create: `TomeOfVengeance/Data/Races.lua`, `Data/Classes.lua`, `Core/Roster.lua`, `tests/test_roster.lua`

**Interfaces:**
- Produces: `ns.Data.Races` = array of `{ raceFile, raceID, faction = "Alliance"|"Horde"|"Neutral", since = <expansion index 0=Vanilla..>, plural = "Gnomes", singular = "Gnome" }` (enUS nouns, used only for title text). `ns.Data.Classes` = array of `{ classFile, classID, since, plural, singular }`.
- Produces: `ns.Roster.races(expansion, isRetail, factionsSeen) -> array of race entries` (Data order), `ns.Roster.classes(expansion) -> array`, `ns.Roster.race(raceFile) -> entry|nil`, `ns.Roster.class(classFile) -> entry|nil`.

Rules: entry listed if `since <= expansion`. Retail: all races passing `since`. Non-Retail: race listed if `faction == "Neutral"` or its faction is the opposite of any faction in `factionsSeen`. Empty `factionsSeen` on non-Retail → empty list. Forever counts as expansion 0 unless the Forever client exposes a different `GetClientDisplayExpansionLevel()` (glue decides; Roster just takes the number).

Data must cover every playable race and class through Midnight, with correct `since`. `raceFile` values are the client tokens (`Scourge` for Undead, `HighmountainTauren`, `Dracthyr`, `EarthenDwarf`, etc.). Dracthyr and Earthen are faction-flexible at creation: mark them `Neutral`. Pandaren: `Neutral`.

- [ ] **Step 1: Failing tests:**

```lua
T.test("classic_horde_sees_alliance", function()
  local files = {}
  for _, r in ipairs(ns.Roster.races(0, false, { Horde = true })) do files[#files + 1] = r.raceFile end
  T.eq(files, { "Human", "Dwarf", "NightElf", "Gnome" })
end)
T.test("classic_both_factions_sees_all_eight", function()
  T.eq(#ns.Roster.races(0, false, { Horde = true, Alliance = true }), 8)
end)
T.test("classic_no_faction_empty", function() T.eq(#ns.Roster.races(0, false, {}), 0) end)
T.test("mists_includes_pandaren_for_alliance", function()
  local has = false
  for _, r in ipairs(ns.Roster.races(4, false, { Alliance = true })) do has = has or r.raceFile == "Pandaren" end
  T.ok(has)
end)
T.test("retail_lists_every_race", function()
  T.eq(#ns.Roster.races(99, true, { Horde = true }), #ns.Data.Races)
end)
T.test("classic_classes", function()
  T.eq(#ns.Roster.classes(0), 9)   -- no Death Knight, Monk, DH, Evoker
end)
T.test("data_tokens_unique", function()
  local seen = {}
  for _, r in ipairs(ns.Data.Races) do T.ok(not seen[r.raceFile], r.raceFile); seen[r.raceFile] = true end
end)
```

- [ ] **Step 2:** Run `luajit tests/run.lua roster` → FAIL.
- [ ] **Step 3:** Write the data tables and `Core/Roster.lua`.
- [ ] **Step 4:** Run full suite → PASS.
- [ ] **Step 5: Commit** `feat: race and class roster per flavour`.

### Task 3: Combat-log classification and death attribution

**Files:**
- Create: `TomeOfVengeance/Core/Attribution.lua`, `Core/CombatLog.lua`, `tests/test_combatlog.lua`

**Interfaces:**
- Produces: `ns.CombatLog.FLAGS` (copy of the needed `COMBATLOG_OBJECT_*` bit values as constants, since Core can't read WoW globals: `TYPE_PLAYER=0x400`, `TYPE_PET=0x1000`, `TYPE_GUARDIAN=0x2000`, `CONTROL_PLAYER=0x100`, `REACTION_HOSTILE=0x40`, `AFFILIATION_MINE=0x1`).
- Produces: `ns.CombatLog.new(opts) -> state` where `opts = { playerGUID, isSecret = function(v) -> bool, window = 12 }`.
- Produces: `ns.CombatLog.handle(state, ev, clock) -> result|nil`, where `result = { kind = "kill", who = { guid, name } }`. Damage events (`SWING_DAMAGE`, `RANGE_DAMAGE`, `SPELL_DAMAGE`, `SPELL_PERIODIC_DAMAGE`, `SPELL_BUILDING_DAMAGE`) with dest = player and source = hostile player are fed to Attribution and return nil.
- Produces: `ns.CombatLog.onPlayerDeath(state, clock) -> { kind = "death", who = { guid, name } } | nil`. Clears the buffer.
- Produces: `ns.CombatLog.setDuel(state, opponentName|nil)`. While set, events whose other party's name matches are ignored, and on duel end (`nil`) any buffered hits from that opponent are discarded.
- Produces (Attribution): `ns.Attribution.new(window)`, `:note(clock, guid, name)`, `:killer(clock) -> guid, name | nil`, `:drop(name)`, `:reset()`.

Kill rule: `subevent == "PARTY_KILL"`, source is the player **or** has `AFFILIATION_MINE` with `TYPE_PET`/`TYPE_GUARDIAN`, dest has `TYPE_PLAYER` and `CONTROL_PLAYER` and `REACTION_HOSTILE`. Any field of `ev` where `isSecret(v)` → return nil.

- [ ] **Step 1: Failing tests** (helper `mk(sub, srcGUID, srcFlags, dstGUID, dstFlags)` in the test file):

```lua
local F = ns.CombatLog.FLAGS
local ENEMY = F.TYPE_PLAYER + F.CONTROL_PLAYER + F.REACTION_HOSTILE
local MYPET = F.TYPE_PET + F.AFFILIATION_MINE
T.test("own_killing_blow", function() ... handle(s, mk("PARTY_KILL","ME",0x511,"E1",ENEMY), 1) -> T.eq(r.kind,"kill"); T.eq(r.who.guid,"E1") end)
T.test("pet_killing_blow_counts", ...)          -- source "PET1" flags MYPET -> kill
T.test("groupmate_killing_blow_ignored", ...)    -- source "ALLY" -> nil
T.test("hostile_pet_not_a_kill", ...)            -- dest flags TYPE_PET+REACTION_HOSTILE -> nil
T.test("hostile_npc_not_a_kill", ...)            -- dest TYPE_NPC (0x800)+HOSTILE -> nil
T.test("secret_field_skipped", ...)              -- isSecret returns true for destGUID -> nil, no error
T.test("death_last_hostile_in_window", ...)      -- hits from E1 at 1, E2 at 5; death at 10 -> E2
T.test("death_outside_window_not_recorded", ...) -- hit at 1, death at 14 (window 12) -> nil
T.test("death_no_hits_nil", ...)
T.test("buffer_cleared_after_death", ...)        -- second death with no new hits -> nil
T.test("duel_opponent_ignored", ...)             -- setDuel("Duelist"); hit from Duelist; setDuel(nil); death -> nil
T.test("duel_kill_not_counted", ...)             -- setDuel("Duelist"); PARTY_KILL on Duelist -> nil
```

- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement `Core/Attribution.lua` and `Core/CombatLog.lua`. Bit tests use a local `band` that works under both LuaJIT (`bit.band`) and WoW (`bit.band`).
- [ ] **Step 4:** Run full suite → PASS.
- [ ] **Step 5: Commit** `feat: classify combat-log kills and attribute deaths`.

### Task 4: Recording kills and deaths

**Files:**
- Create: `TomeOfVengeance/Core/Record.lua`, `tests/test_record.lua`

**Interfaces:**
- Consumes: `ns.Store.player`, `ns.Store.charKey`, `ns.Roster.race/class`.
- Produces: `ns.Record.kill(db, who, ctx) -> anns`, `ns.Record.death(db, who, ctx) -> anns`. `anns` is an array of announcements (possibly empty).
- Produces: `ns.Record.LEDGER_MAX = 200`.

Behaviour: increment player kills/deaths, `ctx[kind]`, `chars[ctx.char]`, `total`, and `races[raceFile]`/`classes[classFile]` **only when known**. Set `factionsSeen[ctx.faction] = true`. Append ledger, trimming oldest past 200. On death set `rec.killedMeAt = ctx.now`. On first kill of a race/class set `unlockedAt` and emit:
`{ kind = "unlock", header = "Tome of Vengeance Unlocked", title = <client race/class display name passed in who.raceName / who.className, else Data plural>, reason = "First <singular> slain" }`.
If race/class becomes known on a later sighting (backfill), counts are **not** retro-credited (simple, documented in README).
Titles are added in Task 6 (Record calls `ns.Titles.evaluate` there).

- [ ] **Step 1: Failing tests:**

```lua
T.test("kill_counts_everywhere", ...)  -- totals, player.kills, ctx.world.k, chars["Me-R"].k, races.Gnome.kills, classes.MAGE.kills all 1
T.test("first_kill_unlocks_once", ...) -- first kill anns has 1 unlock with reason "First Gnome slain"; second kill no unlock
T.test("unknown_race_no_credit", ...)  -- who without raceFile: player.kills==1, races empty, no unlock ann
T.test("death_sets_killedMeAt", ...)
T.test("ledger_capped", ...)           -- 205 kills -> #ledger == 200, ledger[1] is the 6th event
T.test("battleground_context", ...)    -- ctx.kind "battleground" -> rec.ctx.battleground.k == 1
```

- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Full suite PASS.
- [ ] **Step 5: Commit** `feat: record kills and deaths with unlocks`.

### Task 5: Nemesis

**Files:**
- Create: `TomeOfVengeance/Core/Nemesis.lua`, `tests/test_nemesis.lua`

**Interfaces:**
- Produces: `ns.Nemesis.is(rec, threshold) -> bool` (`rec.deaths >= threshold and rec.kills < rec.deaths`), `ns.Nemesis.list(db) -> array of rec` sorted by deaths desc then name, each rec has `.guid` set, `ns.Nemesis.THROTTLE = 300`, `ns.Nemesis.sighted(db, state, guid, now) -> ann|nil` where `state` is a plain table of last-alert times kept by glue (not saved).
- Sighting announcement: `{ kind = "nemesis", header = "Nemesis Sighted", title = rec.name, reason = "Has slain you <deaths> times" }`. Returns nil if alerts are off, the GUID isn't a nemesis, or it was alerted within 300 s.

- [ ] **Step 1: Failing tests:** `threshold_boundary` (2 deaths no, 3 yes), `evened_score_not_nemesis` (3 deaths 3 kills → false), `custom_threshold` (settings 5), `sighted_throttled` (alert at 0, nil at 299, alert at 300), `alerts_off`, `list_sorted`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat: nemesis detection and alert throttle`.

### Task 6: Titles

**Files:**
- Create: `TomeOfVengeance/Data/Titles.lua`, `Core/Titles.lua`, `tests/test_titles.lua`
- Modify: `Core/Record.lua` (append `ns.Titles.evaluate` results to `anns` in `kill`)

**Interfaces:**
- Produces: `ns.Data.Titles.TIERS = { 10, 50, 100, 250, 500, 1000 }`, `.TEMPLATES` (index matches TIERS), `.OVERRIDES[raceFile|classFile][tier] = "name"`, `.OVERALL = { {n=1,id="total:1",name="Blooded"}, {10,"Skirmisher"}, {50,"Raider"}, {100,"Warmonger"}, {250,"Butcher"}, {500,"Warlord"}, {1000,"Avatar of Vengeance"} }`, `.SPECIAL = { nemesis = "Nemesis Slayer", revenge = "Vengeance Is Mine" }`.
- Templates (`%s` = singular for 10/50/500, plural for 100/250/1000): `"%s Hunter"`, `"%s Slayer"`, `"Scourge of the %s"`, `"Bane of the %s"`, `"%s Reaper"`, `"Doom of the %s"`.
- Overrides at least: Gnome `{[10]="Gnome Punter",[100]="Scourge of Gnomeregan",[250]="Bane of the Tinkerers"}`. Add a few more in the same tongue-in-cheek tone; never Warhammer terms.
- Title ids: `"race:Gnome:100"`, `"class:MAGE:10"`, `"total:50"`, `"special:nemesis"`, `"special:revenge"`.
- Produces: `ns.Titles.evaluate(db, rec, ctx, wasNemesis) -> anns`, `ns.Titles.name(id) -> string`, `ns.Titles.progress(db, kind, key) -> count, nextTier|nil, nextName|nil`.
- Title announcement: `{ kind = "title", header = "Tome of Vengeance Unlocked", title = <name>, reason = "<count> <plural> slain" }`; overall reason `"<count> foes slain"`; revenge reason `"Avenged yourself on <name>"`; nemesis reason `"Slew your nemesis <name>"`.

Special rules: revenge if `rec.killedMeAt` and `ctx.now - rec.killedMeAt <= 300`. Nemesis if `wasNemesis` (Record computes `ns.Nemesis.is(rec, threshold)` **before** incrementing, from Task 5). Each title earned once.

- [ ] **Step 1: Failing tests:** `gnome_10_override` (10th Gnome kill emits "Gnome Punter"), `template_used_without_override` (10th Human kill emits "Human Hunter"), `tier_not_repeated` (11th kill emits nothing), `overall_first_blood` (first kill ever emits "Blooded" plus the race unlock), `revenge_within_5min`, `revenge_too_late` (301 s), `nemesis_slayer`, `progress_next_tier` (`progress(db,"race","Gnome")` after 211 kills → `211, 250, "Bane of the Tinkerers"`).
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Full suite PASS.
- [ ] **Step 5: Commit** `feat: milestone, overall and special titles`.

### Task 7: WoW glue + headless smoke harness

**Files:**
- Create: `TomeOfVengeance/Compat.lua`, `TomeOfVengeance/TomeOfVengeance.lua`, `tests/wow_stub.lua`, `tests/smoke_ui.lua`
- Modify: `.luacheckrc` (read_globals for every API used)

**Interfaces:**
- Produces `ns.Compat`: `isRetail() -> bool` (`WOW_PROJECT_ID == WOW_PROJECT_MAINLINE`), `expansion() -> int` (`GetClientDisplayExpansionLevel` if present, else derived from `select(4, GetBuildInfo())`), `playerGUID()`, `who(guid, fallbackName) -> who` (via `GetPlayerInfoByGUID`; adds `raceName`, `className`, `faction` from Roster data; nil-safe), `enrich(who, unit)` (level, guild when unit visible), `isSecret(v)` (`issecretvalue` if it exists, else false), `context() -> ctx` (from `IsInInstance`, `GetRealZoneText`, `GetSubZoneText`, `time`, `GetTime`, `UnitName/GetRealmName`, `UnitFactionGroup`), `playSound(key)` (`PlaySound(SOUNDKIT[key] or 8959, "Master")` inside pcall).
- Produces `ns.App`: `ns.App.db`, `ns.App.announce(anns)` (forwards each to `ns.UI.Toast.show` if present), `ns.App.toggle()`.
- Events: `ADDON_LOADED` (migrate DB, build CombatLog state, create UI), `PLAYER_LOGIN` (record faction in `factionsSeen`), `COMBAT_LOG_EVENT_UNFILTERED` (register inside `pcall`; read `CombatLogGetCurrentEventInfo`, normalise to `ev`, `CombatLog.handle` → `Record.kill` → `announce`), `PLAYER_DEAD` (`onPlayerDeath` → `Record.death`), `DUEL_REQUESTED`/`DUEL_INBOUNDS`/`DUEL_FINISHED` (+ `UnitName("target")` when you initiate) → `setDuel`, `NAME_PLATE_UNIT_ADDED`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT` (hostile player unit → `Nemesis.sighted` → announce; also `enrich`). Every handler body in `pcall`.
- Slash: `SLASH_TOMEOFVENGEANCE1 = "/tov"` only (`/tome` dropped in Task 1: clashes with DungeonTome-Forever); `""` toggles book, `"settings"` opens settings page, `"reset"` asks via `StaticPopup` (confirm text "Erase every page of the Tome of Vengeance?"), `"debug"` prints flavour, expansion, CLEU registered yes/no, record counts.
- `TomeOfVengeance_OnCompartmentClick` global → `ns.App.toggle()`.

`tests/wow_stub.lua`: returns an env table usable as `setfenv` target: `CreateFrame` returning a frame object whose unknown methods are no-ops (metatable `__index`) but which records `RegisterEvent` and `SetScript("OnEvent")`; stubs for every API in Compat; `fire(event, ...)` helper; a settable `cleu` table for `CombatLogGetCurrentEventInfo`.

- [ ] **Step 1: Write `tests/smoke_ui.lua`** that loads every TOC file under the stub (Retail profile, then again with a Classic profile: `WOW_PROJECT_ID = 2`, no `issecretvalue`, no `Settings`), and asserts:
  - `ADDON_LOADED` creates `TomeOfVengeanceDB` with `version == 1`;
  - firing a CLEU `PARTY_KILL` (player → hostile player GUID whose `GetPlayerInfoByGUID` returns Gnome/MAGE) leaves `db.total.kills == 1`, `db.races.Gnome.unlockedAt ~= nil` and the toast queue holding one unlock + "Blooded";
  - CLEU damage from a hostile player then `PLAYER_DEAD` → `db.total.deaths == 1`;
  - a CLEU event where `issecretvalue` returns true changes nothing and raises nothing;
  - `/tov` toggles book shown state; `/tov reset` doesn't erase without confirm.
- [ ] **Step 2:** Run `luajit tests/smoke_ui.lua` → FAIL (glue missing).
- [ ] **Step 3:** Implement `Compat.lua`, `TomeOfVengeance.lua`, `tests/wow_stub.lua`. Until Tasks 8–9 exist, smoke assertions on toast/book read through `ns.UI` stubs created in the smoke test; switch to real UI when those tasks land.
- [ ] **Step 4:** Run `luajit tests/run.lua && luajit tests/smoke_ui.lua && luajit tests/syntax.lua && luacheck TomeOfVengeance` → all pass.
- [ ] **Step 5: Commit** `feat: wire client events to core recording`.

### Task 8: Toast, nemesis banner, sounds

**Files:**
- Create: `TomeOfVengeance/UI/Theme.lua`, `UI/Toast.lua`, `Data/Sounds.lua`
- Modify: `tests/smoke_ui.lua`

**Interfaces:**
- Produces `ns.UI.Theme`: colour constants matching the mockup (`PARCHMENT_LIGHT = {0.953,0.890,0.749}`, `PARCHMENT_DARK = {0.886,0.788,0.576}`, `INK = {0.231,0.149,0.078}`, `BLOOD = {0.541,0.110,0.063}`, `GOLD = {0.788,0.635,0.290}`, `GOLD_TEXT = {1,0.906,0.627}`, `TOAST_BG = {0.106,0.071,0.043}`), `Theme.font(size, smallcaps)` helper, texture path constants, `Theme.panel(parent, kind)` backdrop helper.
- Produces `ns.UI.Toast.show(ann)`: queues; shows one at a time centre-screen (upper third) for 4 s with fade in/out; `kind == "nemesis"` uses `BLOOD` border instead of `GOLD`. Header line small, title line large small-caps gold, reason line small. Plays `ns.Data.Sounds.forKind(kind, settings)` if `settings.sound`. `ns.UI.Toast.queueLength()` for tests.
- Produces `ns.Data.Sounds.LIST = { unlock = {...}, title = {...}, nemesis = {...} }`, each a shortlist of `{ key = "SOUNDKIT_NAME", label = "War horn" }`; `forKind(kind, settings) -> key`. Candidates to verify on each client: `RAID_WARNING`, `READY_CHECK`, `UI_BATTLEGROUND_COUNTDOWN_FINISHED`, `PVP_THROUGH_QUEUE`, `LEVEL_UP`, `ALARM_CLOCK_WARNING_3`. Keep only keys that exist in `SOUNDKIT` on every supported client (check in-game via `/dump SOUNDKIT.X` during Task 12; until then keep all, runtime falls back to 8959).
- [ ] **Step 1:** Extend smoke: after a kill, `Toast.queueLength() == 2`; after advancing the stub's `OnUpdate` 4+ s, it's 1; nemesis ann sets border colour to `BLOOD`; with `settings.sound = false`, `PlaySound` stub is not called.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** smoke + unit + lint PASS.
- [ ] **Step 5:** Visual check: open `docs/superpowers/specs/assets/2026-11-07-tome-layout-mockup.html` and compare toast proportions; adjust sizes in Theme.
- [ ] **Step 6: Commit** `feat: unlock toast and nemesis banner with sounds`.

### Task 9: The Book — frame, races and classes

**Files:**
- Create: `TomeOfVengeance/UI/Book.lua`, `UI/Pages/Races.lua`, `UI/Pages/Classes.lua`
- Modify: `tests/smoke_ui.lua`

**Interfaces:**
- Produces `ns.UI.Book`: `create()`, `toggle()`, `open(section, key?)`, `isShown()`, `registerSection(id, { label, order, buildIndex(leftPage, db), buildEntry(rightPage, db, key) })`. Sections: `races`, `classes`, `nemeses`, `ledger`, `titles`, `settings`. Section tabs sit along the top of the left page as small-caps text links (layout A has no side ribbons). Frame movable, saved position in `db.settings.bookPos`, added to `UISpecialFrames` for Escape. Header shows the active title if set.
- Races left page "Bestiary of Foes": rows `<race display name> … <kills>`; locked rows italic, faded, `???` for name and count. Right page for selected race: small-caps name, `Slain: N · Slain by: M`, red progress bar to next tier, `Next title at <tier>: <name>` (or "Every title earned"), "Titles earned" list, "Most slain" top 5 players of that race by kills. Locked entry right page: `???` and "Slay one to fill this page."
- Classes: same structure, left page titled "Roll of Callings"; class name tinted with class colour.
- Sizes: two pages side by side with a gutter; builder's call within the mockup's proportions (about 1.6:1 overall). Textures: built-in book/parchment art first (e.g. quest/item-text parchment, spellbook frame), leather frame from built-in UI art or tinted backdrop; custom textures only if needed and original/CC0.
- [ ] **Step 1:** Extend smoke: `/tov` shows book on `races`; with no kills on a Horde Classic profile, left page has 4 rows all locked; after a Gnome kill, the Gnome row is unlocked showing `1`; `Book.open("races","Gnome")` renders "Slain: 1"; Escape closes (`UISpecialFrames` contains the frame name).
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat: open-book tome with race and class pages`.

### Task 10: Remaining pages, minimap, settings

**Files:**
- Create: `UI/Pages/Nemeses.lua`, `UI/Pages/Ledger.lua`, `UI/Pages/Titles.lua`, `UI/Pages/Settings.lua`, `UI/Minimap.lua`
- Modify: `tests/smoke_ui.lua`

**Interfaces:**
- Nemeses: left list from `ns.Nemesis.list(db)` as `<name> <race class> <kills> / <deaths>`; right page: name, realm, race/class, level/guild if known, first met, last met, per-context K/D, "Avenged" marker if your latest event with them was a kill. Empty state: "No one has bested you thrice. Yet."
- Ledger: newest-first list of `db.ledger` (time, Slew/Slain by, name, zone, context icon or tag). Clicking a name opens that player's page (reuse the Nemeses entry renderer for any player).
- Titles: all earned titles grouped (Overall, Races, Classes, Deeds); click sets `db.activeTitle`; locked tiers not listed (only next tier per entry shown in race/class pages).
- Settings: checkboxes `alerts`, `sound`, `minimap`; nemesis threshold slider 2–10; per-kind sound dropdown from `Data.Sounds.LIST` with a "play" button; "Erase the Tome" button using the same confirm as `/tov reset`. Where `Settings.RegisterCanvasLayoutCategory` exists, register a small category whose button opens this page.
- Minimap: round button with a book icon (built-in icon texture), drag around minimap edge, angle saved in `db.settings.minimapAngle`, hidden when `minimap = false`; tooltip "Tome of Vengeance" + total K/D.
- [ ] **Step 1:** Extend smoke: three deaths to one GUID → Nemeses section lists them; ledger shows newest first; clicking a title sets `activeTitle` and the book header shows it; toggling minimap setting hides the button; threshold slider to 4 → the 3-death player leaves the list. Both Retail and Classic profiles.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat: nemeses, ledger, titles and settings pages`.

### Task 11: Classic packaging and release pipeline

**Files:**
- Create: `.github/workflows/release.yml`, `.github/scripts/upload-curseforge.sh`
- Modify: `TomeOfVengeance/TomeOfVengeance.toc`, `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`

- [ ] **Step 1: Research** (warcraft.wiki.gg "TOC format", "Patch" pages; CurseForge `api/game/wow/versions`): which Classic flavours are live today (expect Classic Era/Anniversary and Mists Classic; confirm), each one's current interface number, its CurseForge game-version type id, and Wago's expected zip suffix per flavour. Record findings as a table in `CONTRIBUTING.md`.
- [ ] **Step 2:** Decide TOC strategy: one TOC with every interface (as azeroth-ante) if all target clients accept a comma list; otherwise flavour TOCs (`TomeOfVengeance_Vanilla.toc`, `_Mists.toc`) alongside the main one. Document the choice in `CONTRIBUTING.md`.
- [ ] **Step 3:** Release workflow based on azeroth-ante's, with flavours identified by an **explicit table in the script** (`FOREVER_INTERFACES="16001"`, `CLASSIC_ERA_INTERFACES=...`, etc.), not by digit count, since Classic Era and Forever are both five digits. Build one zip per flavour with the suffixes found in Step 1 (`.zip` Retail, `-forever.zip` Forever, Classic suffixes per Wago). TOC version must equal tag. Hyphenated tags → pre-release / beta.
- [ ] **Step 4:** Upload script: one CurseForge upload per zip with that flavour's game versions; missing version → warning and skip that flavour, not fail the others.
- [ ] **Step 5:** Verify locally: `act` is not required; run the build portion of the script against a fake tag (`GITHUB_REF_NAME=v0.1.0 bash -c '<build step>'`) and list the produced zips; confirm each zip's TOC.
- [ ] **Step 6:** README: features, screenshots placeholder, install per client (Retail `_retail_`, Forever `_forever_`, Classic folders), usage table (`/tov`, `/tov settings`, `/tov reset`, `/tov debug`), "How kills and deaths are counted" (killing blows incl. your pet; last enemy player to hit you within 12 s; duels ignored; race/class credited only once known), limitations (Retail arenas best-effort; titles are addon-only).
- [ ] **Step 7: Commit** `ci: release Retail, Classic and Forever packages`.

### Task 12: In-game verification (Liam, manual)

Not code. Checklist the implementer prepares in `docs/verification.md` and hands to Liam; results feed fixes before tagging `v0.1.0`.

- [ ] Load on Retail, each live Classic flavour, Forever: no Lua errors on login, `/tov debug` shows CLEU registered.
- [ ] World PvP kill and death on each client: counts, unlock toast, sound, ledger entry.
- [ ] Pet killing blow (hunter or warlock) counts.
- [ ] Random BG on Retail: kills tagged `battleground`.
- [ ] Arena (Retail): note whether events arrive or are secret. Best-effort; doesn't block.
- [ ] Duel: nothing recorded.
- [ ] Nemesis alert fires on nameplate/target, once per 5 min.
- [ ] Retail: confirm Haranir race token (`Harronir`?) and raceID 86, and Earthen raceID, via `/dump UnitRace("target")` and `C_CreatureInfo.GetRaceInfo`; fix `Data/Races.lua`.
- [ ] `/dump SOUNDKIT.<key>` for every `Data/Sounds` key on each client; remove missing ones.
- [ ] Book visually matches the mockup's feel; screenshot for README and CurseForge.
- [ ] Before any push: Liam creates `lgulliver/tome-of-vengeance` on GitHub, CurseForge project, Wago project + webhook, sets `CF_API_TOKEN`/`CF_PROJECT_ID`. No pushing or publishing without his go-ahead.
