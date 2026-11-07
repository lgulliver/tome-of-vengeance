# Contributing

This is a small project, so the process is light.

## Reporting a bug

Open an issue and include:

- What you expected and what happened
- PvP context: world, battleground or arena, and which characters were involved
- Your client and version: Retail, Classic or Forever
- Any Lua error text (use BugSack if errors are hidden)

## Development setup

There is no build step. The addon is plain Lua.

1. Clone the repo.
2. Symlink `TomeOfVengeance/` into your client's `Interface/AddOns/` directory.
3. Edit, then `/reload` in game to pick up Lua changes. Texture changes need a full client restart.

Run these checks from the repo root. They need [LuaJIT](https://luajit.org/) and [luacheck](https://github.com/lunarmodules/luacheck):

```sh
luajit tests/run.lua
luajit tests/syntax.lua
luacheck TomeOfVengeance
if [ -f tests/smoke_ui.lua ]; then luajit tests/smoke_ui.lua; fi
```

CI runs unit tests, syntax checks, lint and the UI smoke test once present. Add new WoW API globals to `read_globals` in `.luacheckrc`.

## Code style

- Use two spaces for indentation and Lua 5.1 syntax. Comments explain non-obvious reasons.
- Addon files start with `local _, ns = ...` and export through `ns`.
- Only SavedVariables, slash-command globals and the compartment callback may be global.
- `Core/` and `Data/` never call WoW APIs. Pass time, identity and lookups in.
- Saved state is plain data. Migrate older saves rather than discarding them.
- New addon files go in `TomeOfVengeance/TomeOfVengeance.toc` in dependency order.
- Write failing tests before implementing behavior.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/).
- Keep a pull request to one change.
- Update `CHANGELOG.md` under "Unreleased" and the README when behavior or commands change.
- Describe checks run and what you tested in the client.

## Licence

By contributing you agree your work is released under the [MIT licence](LICENSE).

## Client packaging research (2026-11-07)

| Flavour | Current interface / patch | CurseForge game-version type ID | Asset suffix |
|---------|---------------------------|--------------------------------|--------------|
| Retail | Retain sibling targets: `120100`, `120105`, `120107` / 12.1.0, 12.1.5, 12.1.7 | `517` | `.zip` |
| Forever | `16001` / 1.60.1 | `88568` (sibling convention) | `-forever.zip` |
| Classic Era / Hardcore | `11509` / 1.15.9 | TODO: API inaccessible; resolve from exact `apiVersion` at upload | `-classic.zip` |
| Burning Crusade Anniversary | `20506` / 2.5.6 | TODO: API inaccessible; resolve from exact `apiVersion` at upload | `-bc.zip` |
| Mists of Pandaria Classic | `50504` / 5.5.4 | TODO: API inaccessible; resolve from exact `apiVersion` at upload | `-mists.zip` |

The [Warcraft Wiki TOC table](https://warcraft.wiki.gg/wiki/Interface_version) currently lists Era, TBC and Mists interfaces above. Its [Mists patch page](https://warcraft.wiki.gg/wiki/5.5.4) dates 5.5.4 to June 2, 2026. This identifies three Classic targets, including Anniversary's Burning Crusade client. The Retail list deliberately retains the plan's compatibility targets; it includes versions beyond the wiki's live Retail row. It is not a claim that every listed Retail version is live.

Use one comma-list TOC, matching Azeroth Ante. The [TOC documentation](https://warcraft.wiki.gg/wiki/TOC_format) recommends comma-delimited interfaces where possible. All packages contain the same addon and load order. No flavour-specific Lua is needed.

[WowUp's own documentation](https://wowup.io/guide/get-addons/overview) confirms these Classic asset suffixes for GitHub installs. Wago's developer page could not be fetched, so these are provisional Wago routing names, not verified Wago acceptance.

### Verification TODOs before publishing

| TODO | Reason / verification method |
|------|------------------------------|
| Confirm each client interface in game | Run `/dump select(4, GetBuildInfo())` on Era, Anniversary and Mists; wiki search snapshots were available, direct patch pages returned HTTP 403. Update TOC and explicit script table together if changed. |
| Record Classic CurseForge type IDs | `https://wow.curseforge.com/api/game/wow/versions` was inaccessible via web tools; shell network DNS also failed. With authorized credentials, inspect each exact `apiVersion` record and record its `gameVersionTypeID` here. No CurseForge call was made successfully during implementation. |
| Confirm Wago suffix routing | Developer page unavailable. Confirm `.zip`, `-forever.zip`, `-classic.zip`, `-bc.zip`, `-mists.zip` in Wago project setup before enabling webhook; rename table suffixes if required. |
| Verify live release targets | Recheck patch availability immediately before tagging. Upload code validates exact interface and patch against the live CurseForge list; packaging itself is offline and does not prove a client is live. |

## Releasing

The tag-triggered workflow follows Azeroth Ante's pinned checkout action, generated GitHub release notes, optional CurseForge upload and Wago webhook model. Project creation and publishing remain maintainer actions after in-game verification.

The explicit table in `.github/scripts/build-release.sh` defines each flavour's interfaces, suffix and known CurseForge type. Five-digit interfaces are never used to infer flavour. Classic CurseForge type IDs are discovered only from unique live records matching both exact `apiVersion` and patch name, excluding Retail and Forever types. Missing or ambiguous metadata skips that flavour with a warning; other uploads continue. Network or upload failures fail the job after uploads have been attempted.

A `v0.1.0` tag requires `## Version: 0.1.0`. Hyphenated tags such as `v0.1.0-alpha.1` also require the plain TOC version, create GitHub prereleases, and upload as CurseForge **beta**. Re-running replaces GitHub assets. CurseForge does not provide the same replacement guarantee; reruns can create duplicate files there.

Build locally without publishing (requires Bash, zip and standard Unix tools):

```sh
GITHUB_REF_NAME=v0.1.0 DIST_DIR=/tmp/tov-release bash .github/scripts/build-release.sh
unzip -l /tmp/tov-release/TomeOfVengeance-0.1.0-classic.zip
unzip -p /tmp/tov-release/TomeOfVengeance-0.1.0-classic.zip TomeOfVengeance/TomeOfVengeance.toc
```

Each zip contains only `TomeOfVengeance/`, including `LICENSE`. Source TOC version and every classified interface are checked before building; unknown interfaces fail rather than silently disappearing. Use a fresh output directory for each local tag. CI uses a clean checkout and sets `VERSION`, `STABILITY`, `DIST_DIR` and `NOTES_FILE` through `GITHUB_ENV` for later steps.

Configure `CF_API_TOKEN` as an Actions secret and `CF_PROJECT_ID` as an Actions variable to enable CurseForge. The upload needs curl and jq; it sends one file per flavour with only that flavour's game-version IDs. Without both values the step is skipped.

After confirming routing, configure the Wago project for multiple game versions and its GitHub release webhook at `https://addons.wago.io/api/github/webhook`. No Wago credentials are stored in this workflow. Neither project setup nor a release is created by local packaging.
