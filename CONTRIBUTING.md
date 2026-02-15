# Contributing to murderface-pets

Thanks for your interest in contributing! This project is open source under GPL-3.0 and welcomes bug reports, feature ideas, and pull requests.

## Reporting Bugs

Use the [Bug Report](https://github.com/fruitmob/murderface-pets/issues/new?template=bug_report.yml) template. Include:

- The version or commit hash you're running
- Steps to reproduce the issue
- Server and client console errors (F8 console or server terminal)
- Your ox_inventory version and game build number

## Suggesting Features

Use the [Feature Request](https://github.com/fruitmob/murderface-pets/issues/new?template=feature_request.yml) template. Describe what you'd like and why it would improve RP.

## Pull Requests

1. Fork the repo and create a branch from `master`
2. Make your changes — keep them focused on a single feature or fix
3. Test in-game on a Qbox server with ox_inventory before submitting
4. Open a PR with a clear description of what changed and why

### Code Style

- Follow the existing patterns in the codebase
- Use `ox_lib` for UI (context menus, notifications, progress bars, alerts)
- Use `ox_target` for 3D world interactions
- Use `lib.callback` for client-server RPC (not raw net events for request/response)
- Server-side validation for all player actions — never trust the client
- Keep performance in mind: no per-frame loops, batch DB operations, use caches

### ox_inventory Item Exports

If you add new items, remember the FiveM export gotcha: ox_inventory prepends a `nil` that gets dropped by cross-resource marshaling. Export handlers use the signature `(event, item, inventory, slot)` — no `_` placeholder.

## Questions?

Open a [discussion](https://github.com/fruitmob/murderface-pets/issues) or reach out to the FruitMob team.
