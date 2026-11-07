# Tome of Vengeance — Design

Date: 2026-11-07
Status: ready for approval

## Intent

A World of Warcraft addon that remembers every enemy player you've killed and every enemy player who has killed you, presented the way Warhammer Online's Tome of Knowledge did it: a leather-bound book that fills in as you play, unlocks entries the first time you meet something new, and hands out titles at milestones with a gold toast.

Existing kill trackers (PvPLedger, Headhunter, PvP Stats Classic, Gank Counter) cover the data. They look like spreadsheets. The reason this exists is **polish and the WAR feel**. If it works but feels like a stats table, it has failed.

Released publicly on CurseForge and Wago.

## Goals

- Record player kills (yours) and player deaths (yours, attributed to an enemy player) in world PvP, battlegrounds, and arenas.
- Per-player history: every enemy you've traded blows with gets a record.
- Totals by **race** and **class**, both directions.
- A Tome UI in the open-book, two-page layout (left page: index; right page: entry). Approved mockup: layout "A" (see Visual Reference).
- **Unlocks**: a race or class entry is shown as locked (`???`) until you first kill one.
- **Titles**: earned at kill milestones, shown in the Tome and announced with the unlock toast.
- **Unlock toast**: centre-screen, dark panel, gold border, small-caps title line. Approved as mocked; used for unlocks, titles, and milestone events.
- **Nemesis alerts** (v1): when an enemy player who has killed you before is detected near you, alert with a toast-style banner and a sound.
- **Sounds**: alerts and unlocks play WoW's own built-in sounds (by sound kit / FileDataID). No sound files shipped in v1.
- Runs on **Retail**, **Classic**, and **Forever** (Classic+, patch 1.60, interface 16001).

## Non-goals (v1)

- Real in-game titles. WoW does not let addons grant titles; all titles are addon-only and live in the Tome.
- Sharing data or titles with other players (addon comms, tooltip titles for other users). Possible later.
- Bundled custom audio. Possible later (CC0 or commissioned "war horn" set).
- NPC kills, duels, and kills of friendly players.
- Damage meters, fight replays, kill maps (Headhunter's territory).

## Anti-goals

- **No Warhammer IP.** No WAR audio, art, fonts, or text, and nothing named "Tome of Knowledge" or "Book of Grudges". WAR's assets are still copyrighted (EA, with Games Workshop licensing) even though the game is shut down; using them would get the public listing taken down.
- **No spreadsheet feel.** Tables are fine inside the book, but the window must read as an in-world artifact.
- **No hedged UI.** Death attribution is a best guess (see below), but the UI states it plainly ("Slain by X") rather than cluttering it with caveats.
- **No combat taint or errors.** It must never break the default UI, block actions in combat, or spam errors when the client restricts data.

## Decisions (from Liam)

| Decision | Choice |
|----------|--------|
| Name | **Tome of Vengeance** (checked: no clash on CurseForge/Wago as of 2026-11-07) |
| Layout | Open book, two-page spread (mockup A) |
| Toast | As mocked: dark panel, gold border, "Tome of Vengeance Unlocked / *Title* / reason" |
| Clients | Retail, Classic, Forever |
| Battlegrounds | Included |
| Nemesis alerts | In v1 |
| Sounds | WoW built-in sounds for v1 |
| Release | CurseForge + Wago, from `~/repos/tome-of-vengeance` |

Accepted without objection (proposed by Claude, not contested):

- Only **your killing blow** counts as your kill. Group members' killing blows do not.
- Your killer is **the last enemy player who damaged you** before you died.
- Data is **account-wide** (all characters share one Tome), with per-character breakdowns kept in the record.
- Titles are addon-only.

## Behaviour

### Kill detection

- Source: combat log. A kill is a `PARTY_KILL` where the source is the player and the destination is a hostile player (combat log flags: type player, reaction hostile).
- Duels are excluded (track duel state via `DUEL_REQUESTED`/`DUEL_FINISHED` or equivalent, and ignore the duel opponent while it's active).
- Each kill is tagged with context: `world`, `battleground`, or `arena` (from `IsInInstance()` / instance type), plus zone/subzone and timestamp.

### Death attribution

- Keep a short rolling record of hostile-player damage events targeting you.
- On your death, the most recent hostile player to damage you within a window is the killer. **Builder's call:** window length (suggested 10–15 s) and whether to record assisting attackers as "assists" (nice to have, not required for v1).
- If no hostile player damaged you within the window, it isn't a PvP death and isn't recorded.

### Player records

Keyed by player GUID (stable per character). Stored per record:

- name, realm, race, class, faction
- last seen level, last seen guild (only available when the unit is visible: target, mouseover, nameplate)
- kills (you killed them), deaths (they killed you), each with per-context counts
- first met, last met (timestamp + zone)
- which of your characters were involved (per-character counts)

Race and class come from `GetPlayerInfoByGUID`, which works without the unit being visible.

### Race and class pages

- One entry per playable race and per class in the current client. The list must come from the client (or a per-flavour data table) so Classic doesn't show Dracthyr, Retail does, and so on.
- **Which races are listed (Liam):** on Classic and Forever, only the races of the faction opposite to the current character (you can't fight your own faction outside duels, so those pages could never unlock). On Retail, every race (cross-faction battlegrounds make all races killable). Because the Tome is account-wide, an account with characters on both factions sees the union. Neutral races (e.g. Pandaren, Dracthyr) are listed wherever they're playable on that client. Class pages list every class playable on the client.
- Locked (`???`) until first kill of that race/class. First kill triggers the unlock toast.
- Entry page shows: slain count, slain-by count, progress bar to next title, titles earned, top players killed of that race/class.

### Titles

- Milestones per race and per class, plus overall milestones (total kills) and special titles (e.g. killing a nemesis, revenge kill within N minutes of being killed by that player).
- Suggested thresholds: 1 (unlock), 10, 50, 100, 250, 500, 1000. **Builder's call** on final thresholds and title wording, within the tone of the mockup ("Gnome Punter", "Scourge of Gnomeregan", "Bane of the Tinkerers"): punchy, a bit tongue-in-cheek, never using Warhammer terms.
- The player can pick one earned title as their "active" title, shown at the top of the Tome.

### Nemesis

- A **nemesis** is a player who has killed you at least N times (suggested N = 3, **builder's call**, with a setting) and whom you've killed fewer times than they've killed you.
- A **Nemeses** section in the Tome lists them with kills/deaths and history.
- **Nemesis alert**: when a nemesis is detected near you, show a banner (toast styling, red accent instead of gold) and play an alert sound. Detection sources: nameplates appearing (`NAME_PLATE_UNIT_ADDED`), target/mouseover changes, and hostile combat log events naming them. Throttle per player (suggested once per 5 minutes).
- Settings: alerts on/off, sound on/off, threshold.

### Sounds

- Use WoW's built-in sounds via `PlaySound`/`PlaySoundFile` with sound kit IDs or FileDataIDs. Separate sounds for: unlock, title earned, nemesis alert.
- Settings offer a small curated shortlist per alert type (war horns, drums, PvP stings, raid warning). **Builder's call** on the shortlist; each ID must be verified to exist on every supported client. Fall back to a safe default if one doesn't.

### UI

- Open-book frame, movable, closes with Escape. Opened by a slash command and a minimap/addon-compartment button.
- Left page: section tabs/index (Races, Classes, Nemeses, Ledger (recent kills and deaths), Titles). Right page: the selected entry.
- Visual polish is the point: parchment pages, leather frame, small-caps headings, dark red accents. **Builder's call** on how to achieve this with WoW's built-in textures (e.g. quest/book parchment art) versus custom textures shipped with the addon. Any custom textures must be original or CC0.
- Slash command: `/tov` (alias `/tome`; check for clashes). Subcommands for open, settings, and reset (with confirmation).

## Platform constraints

- **Retail (Midnight, 12.x):** Blizzard restricted addon access to the combat log in 12.0, then relaxed it. As reported, combat log data is only made secret during raid encounters and Mythic+, and open-world PvP is unaffected. **Unverified for arenas and rated battlegrounds.** The addon must detect restricted/secret values and degrade quietly (skip recording, no errors), and the builder must verify behaviour in-game on world PvP, a random BG, and an arena. **Release gate (Liam):** Retail arena and rated-BG tracking is best-effort and does not block release. Only broken open-world PvP tracking on Retail blocks a Retail release. No second, non-combat-log detection path in v1.
- **Forever (1.60, interface 16001):** shares the client conventions of azeroth-ante and ForeverSkillManager (AddOns folder `_forever_`). Liam believes the API is close to retail; treat every API call as capability-checked rather than assuming a version.
- **Classic:** azeroth-ante does not ship Classic, so this is new packaging work. **Builder's call** on which Classic flavours are currently live and their interface numbers; verify them at build time rather than hard-coding from memory.
- Use capability checks (`C_*` namespace present, function exists) over version checks wherever possible.

## Project conventions (follow azeroth-ante)

- Repo: `~/repos/tome-of-vengeance`, GitHub `lgulliver/tome-of-vengeance` (to be created).
- Layout: `TomeOfVengeance/` addon folder with `Core/` (pure logic, no WoW UI), `Data/` (races, classes, titles, sound lists), `UI/`; `TomeOfVengeance.toc`; SavedVariables `TomeOfVengeanceDB`.
- Tests: plain LuaJIT runner (`tests/run.lua`) that loads `Core/` and `Data/` from the TOC, as in azeroth-ante. Kill/death attribution, nemesis logic, title thresholds, and unlocks must be unit-tested against synthetic combat log events.
- Lint: `.luacheckrc`, `lua51`.
- CI: lint + test workflows; tag-triggered release workflow modelled on azeroth-ante's (TOC version must match tag; GitHub release; CurseForge upload via `CF_API_TOKEN`/`CF_PROJECT_ID`; Wago via GitHub webhook and asset naming). Extended to produce Classic packages as well as Retail and Forever.
- README, CHANGELOG, CONTRIBUTING, LICENSE (MIT, as azeroth-ante).

## Visual reference

Approved mockups: [`assets/2026-11-07-tome-layout-mockup.html`](assets/2026-11-07-tome-layout-mockup.html) (open in a browser). Card **A** (open book) and card **C** (unlock toast) were approved; card B was rejected. The mockup fixes layout, hierarchy and palette (leather frame, parchment pages, small-caps headings, dark red accents, gold-bordered toast), not exact art. Key elements:

- Left page "Bestiary of Foes": race list with counts; locked rows italic and faded showing `???`.
- Right page: entry title in small caps, "Slain: N · Slain by: M", red progress bar, "Next title at 250: **Bane of the Tinkerers**", titles earned, most slain players.
- Toast: "Tome of Vengeance Unlocked" / **Scourge of Gnomeregan** / "100 Gnomes slain".

## Left to the builder

- Death attribution window, assists.
- Title thresholds and wording.
- Nemesis threshold default and alert throttle.
- Sound shortlist and IDs.
- Texture approach for the book.
- Classic flavour list and interface numbers, and how the release script tells Classic Era from Forever (both use five-digit interface numbers, so azeroth-ante's length check won't work).
- Settings panel layout (Blizzard Settings API where available, simple fallback otherwise).
