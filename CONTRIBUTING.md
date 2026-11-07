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
