# Tome of Vengeance

Remember every enemy player you've slain and every foe who slew you, in an open-book PvP journal.

## Features

- Account-wide enemy history with per-character, world, battleground and arena counts.
- Race and class pages that unlock as you slay foes.
- Milestone titles, unlock toasts and built-in WoW sounds.
- Nemesis alerts and a recent encounters ledger.
- Parchment pages, a movable book, minimap launcher and settings inside the Tome.

Development is in progress. These describe the v1 feature set; in-game verification is still required before release.

## Screenshots

Screenshots will be added after in-game verification on supported clients.

## Install

Download the zip matching your client, extract it, then copy the `TomeOfVengeance/` folder into the directory below. The TOC must sit directly inside that folder. Restart the client or enable the addon at character selection.

| Client | Release asset suffix | AddOns directory under World of Warcraft |
|--------|----------------------|------------------------------------------|
| Retail | `.zip` (no client suffix) | `_retail_/Interface/AddOns/` |
| Forever | `-forever.zip` | `_forever_/Interface/AddOns/` |
| Classic Era / Hardcore | `-classic.zip` | `_classic_era_/Interface/AddOns/` |
| Burning Crusade Anniversary | `-bc.zip` | `_anniversary_/Interface/AddOns/` |
| Mists of Pandaria Classic | `-mists.zip` | `_classic_/Interface/AddOns/` |

If your launcher uses a different installation location, open that client's installation folder and use its `Interface/AddOns/` directory.

## Usage

| Command | Action |
|---------|--------|
| `/tov` | Toggle the Tome |
| `/tov settings` | Open settings |
| `/tov reset` | Ask for confirmation before erasing the Tome |
| `/tov debug` | Print client flavour, expansion, combat-log registration and record counts |

The `/tome` alias is dropped because [DungeonTome](https://www.curseforge.com/wow/addons/dungeontome-forever) and [Chronicle Tome](https://www.curseforge.com/wow/addons/chronicle-tome) already document it. CurseForge and Wago slash-clash searches on 2026-11-07 found no documented `/tov` conflict; search indexing is incomplete.

## How kills and deaths are counted

Only your killing blow counts, including blows from your own pet or guardian. Group members' killing blows, NPCs, enemy pets and duels do not count.

Your killer is the last hostile player to damage you within 12 seconds before death. Without a qualifying attacker, no PvP death is recorded.

Enemy records are keyed by GUID. Race and class totals receive credit only once that identity is known; later discovery does not retroactively credit earlier kills or deaths. Account history is shared across characters, with per-character breakdowns. The ledger keeps the latest 200 events.

Classic and Forever show races from opposing factions the account has played, plus playable neutral races. Retail shows all playable races.

## Limitations

- Retail arena and rated-battleground tracking is best-effort. Restricted or secret combat-log events are skipped.
- Titles are addon-only; they do not grant Blizzard character titles. Title text is English in v1.
- Death attribution uses the last qualifying attacker, not a replay of the fight.
- Classic release metadata and Wago routing still need the checks listed in [CONTRIBUTING.md](CONTRIBUTING.md).

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for checks, packaging and release configuration. Released under the [MIT licence](LICENSE).
