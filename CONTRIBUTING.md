# Contributing to Developer Edge

Thanks for helping out! This is a SwiftUI + AppKit menu-bar app built with Swift
Package Manager.

## Project layout

```
Sources/DeveloperEdge/
  App/        App entry point + AppDelegate
  Config/     AppConfig — the single source of truth for all team-specific data
  Store/      Store (ObservableObject) + Store+*.swift feature extensions, Models
  Features/   FooterMessage, Celebrations
  Views/      SwiftUI views (PanelView is the root)
  Theme.swift Colors + font sizes
assets/         icon.png, logo.png, celebrations.json (ships empty)
scripts/        make-app.sh, make-dmg.sh, notarize.sh, update.sh, git_fetch_all.sh
developer-edge.example.json   documented config reference
```

## Build & run

```bash
swift build -c release          # compile
./scripts/make-app.sh --install # package + install + launch
```

For local testing without real team data, point at a throwaway config:

```bash
DEVELOPER_EDGE_CONFIG=/path/to/test.json open -a "Developer Edge"
```

## Guidelines

- **No hardcoded org data.** Anything team-specific (orgs, hosts, repos, URLs,
  clusters, links) must come from `AppConfig`. If you need a new knob, add it to
  `AppConfig` + `developer-edge.example.json`, not to source.
- **Secrets stay out of config files** — tokens live in `Defaults`/Keychain only.
- **Optional features degrade.** A missing config section should hide its UI, not
  crash or show errors.
- **Match the surrounding style** — `Theme.FontSize` tokens (not raw sizes),
  `Theme` colors, `Rectangle().fill(Theme.divider)` over `Divider()`,
  `ProcessEnv` for subprocess environments.
- Keep PRs to one logical change. Run `swift build -c release` before pushing.

## Commit messages

Short imperative subject lines. Reference an issue when relevant.
