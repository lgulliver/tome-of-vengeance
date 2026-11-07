# In-game verification

Run this before tagging `v0.1.0`. Unit and smoke tests cover the logic headlessly; this checklist covers what only a real client can prove. Record results in the table at the bottom and file a fix for every failure.

Install the matching zip from `.github/scripts/build-release.sh` output (or copy `TomeOfVengeance/` straight into the AddOns folder). Enable Lua errors first: `/console scriptErrors 1`.

## 1. Load (every client)

Clients: Retail, Classic Era, Burning Crusade Anniversary, Mists of Pandaria Classic, Forever.

- [ ] Log in: no Lua errors.
- [ ] `/tov debug` prints the right flavour and expansion, and `CLEU registered: yes`.
- [ ] `/dump select(4, GetBuildInfo())` matches that client's number in the TOC `## Interface:` line. If not, update the TOC and the flavour table in `build-release.sh` together.
- [ ] `/tov` opens the book; Escape closes it; dragging moves it and the position survives `/reload`.
- [ ] Minimap button shows, drags round the edge, opens the book; tooltip shows total kills/deaths.
- [ ] Addon compartment entry opens the book (Retail).

## 2. Kills and deaths (every client)

- [ ] World PvP killing blow on an enemy player: total kills +1, gold unlock toast for the race and class (first time), "Blooded" title toast (first kill ever), sound plays.
- [ ] Ledger shows the kill with zone and `world` tag.
- [ ] Die to an enemy player: deaths +1, ledger shows "Slain by", that player's page shows them.
- [ ] Kill the same player within 5 minutes of them killing you: "Vengeance Is Mine" toast.
- [ ] A group member's killing blow does **not** count.
- [ ] Hunter or warlock: a pet's killing blow **does** count.
- [ ] Duel (one you accept and one you issue, ideally cross-realm): nothing recorded.

## 3. Instanced PvP (Retail first, then Classic flavours)

- [ ] Random battleground: kills and deaths tagged `battleground`.
- [ ] Arena (Retail): note whether events arrive or come through as secret values. Best-effort; this does not block release. Only broken open-world tracking on Retail blocks a Retail release.
- [ ] No Lua errors during a full battleground.

## 4. Nemesis

- [ ] Set the threshold to 2 in settings, die twice to one player.
- [ ] Their nameplate, target or mouseover triggers the red-bordered banner and the alert sound.
- [ ] It does not fire again for that player within 5 minutes.
- [ ] Sound off in settings: banner shows, no sound.
- [ ] Killing them earns "Nemesis Slayer".

## 5. Client data checks

- [ ] Retail: target a Haranir and an Earthen and run `/dump UnitRace("target")` and `/dump C_CreatureInfo.GetRaceInfo(<id>)`. `Data/Races.lua` currently guesses `Harronir` / raceID 86 and `EarthenDwarf` / raceID 84. Fix any mismatch.
- [ ] On each client run `/dump SOUNDKIT.<key>` for every key in `Data/Sounds.lua`: `LEVEL_UP`, `READY_CHECK`, `UI_BATTLEGROUND_COUNTDOWN_FINISHED`, `PVP_THROUGH_QUEUE`, `RAID_WARNING`, `ALARM_CLOCK_WARNING_3`. Remove any key that is `nil` on any client (it would fall back to sound 8959). Use the play button in settings to judge each one by ear.
- [ ] Classic/Forever: the race list shows only the opposite faction plus neutral races; Retail shows all.

## 6. Look and feel

- [ ] Compare the book and toast to `docs/superpowers/specs/assets/2026-11-07-tome-layout-mockup.html`: parchment pages, leather frame, small-caps headings, dark red accents, gold-bordered toast.
- [ ] Check the textures render on every client. `Interface\Stationery\StationeryTest1` (parchment) and `Interface\AchievementFrame\UI-Achievement-AchievementBackground` (leather) may not exist on Classic Era; if a page is blank or green, swap the path in `UI/Theme.lua`.
- [ ] Take screenshots (book on races, a race entry, the toast, the nemesis banner) for the README and the CurseForge/Wago listings.

## 7. Before publishing (maintainer only)

Nothing is pushed or published until these are done and you give the go-ahead:

- [ ] Create `lgulliver/tome-of-vengeance` on GitHub.
- [ ] Create the CurseForge project; set `CF_API_TOKEN` and `CF_PROJECT_ID` repo secrets; record the Classic game-version type IDs in `build-release.sh` (see CONTRIBUTING "Verification TODOs").
- [ ] Create the Wago project, confirm the asset suffix routing, add the webhook.
- [ ] Update CHANGELOG and README screenshots, tag `v0.1.0`.

## Results

| Check | Retail | Era | Anniversary | Mists | Forever | Notes |
|-------|--------|-----|-------------|-------|---------|-------|
| Load | | | | | | |
| Kills/deaths | | | | | | |
| Instanced PvP | | | | | | |
| Nemesis | | | | | | |
| Data checks | | | | | | |
| Look and feel | | | | | | |
