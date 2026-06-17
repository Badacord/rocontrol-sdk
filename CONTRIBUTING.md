# Contributing

Thanks for helping improve the RoControl Roblox SDK!

## Setup

```sh
rokit install   # rojo, wally, stylua, selene, lune
wally install
```

## Develop

- Source lives in `src/`. Engine APIs are confined to `src/Internal/*`; everything
  else is pure Luau so it can be unit-tested without a Roblox DataModel.
- Format: `stylua src tests examples`
- Lint: `selene src tests examples`
- Test (pure logic): `luau tests/run.luau` (or `lune run tests/run.luau`)
- Roblox-coupled tests use TestEZ and run in Studio / run-in-roblox.

## Test expectations

- New pure logic needs a `tests/unit/*.spec.luau` registered in `tests/run.luau`.
- Bug fixes should add a regression test.
- Keep secrets out of fixtures and examples.

## Branch naming

`feat/...`, `fix/...`, `docs/...`, `chore/...`.

## Pull request checklist

- [ ] Tests added/updated and passing
- [ ] Docs added/updated
- [ ] No secrets committed
- [ ] Public API compatibility considered (see AGENTS.md)
- [ ] `stylua --check` and `selene` pass
- [ ] `rojo build` succeeds

## Style

Tabs for indentation; `stylua.toml`/`selene.toml` are authoritative. Public types
go in `src/Types.luau` and are re-exported from `src/init.luau`.

## Adding docs or examples

Docs are Markdown under `docs/`. Examples are server-only and must never show an
API key in a replicated location. See AGENTS.md for endpoint/rotation recipes.
