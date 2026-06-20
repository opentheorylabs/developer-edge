# Developer Edge · Open-Source Roadmap

Developer Edge is a macOS menu-bar companion for fullstack teams: PRs, Jira,
CI/pipeline status, one-click workspace clone + fetch-all, localhost health,
cluster credential refresh, quick links, and team celebrations — all from the
menu bar.

This document tracks the work to turn the Zuperior-internal build into a tool
**any fullstack dev can configure and use**.

## Decisions

- **Distribution:** Developer ID-signed + **notarized DMG** and a **Homebrew cask**
  (`brew install --cask developer-edge`). **Not** the Mac App Store — the sandbox
  forbids spawning `git`/`gcloud`/`kubectl`/`lsof` and free filesystem access,
  which would gut the local-ops half of the app.
- **Configuration:** hybrid. GitHub **auto-discovery** gets a dev running with
  near-zero config; a **`developer-edge.json`** (with `.example` + first-run
  wizard) holds the rich stuff (Jira host, clusters, quick links, Slack,
  branding, per-env URLs). Secrets (GitHub/Jira tokens) live in the system
  keychain/Defaults and **never** in the config file. A team can commit one
  shared config to their repo.
- **Scope:** full de-brand and all features generalized.

## Configuration model

Resolution order (first hit wins, then merged over bundled defaults):

1. `$DEVELOPER_EDGE_CONFIG` (explicit path, for testing)
2. `<workspaceRoot>/developer-edge.json` (team-committed)
3. `~/.config/developer-edge/config.json` (per-user)
4. Bundled `developer-edge.example.json` defaults

Optional sections degrade gracefully: no `clusters` → Kubernetes panel hides;
no `jira` → Jira tab shows a "configure" empty state; no `services` → services
are auto-discovered from the GitHub org.

## Phases

- **Phase 0 — Repo foundation:** git init, MIT LICENSE, this roadmap, gitignore.
- **Phase 1 — AppConfig spine:** `Codable AppConfig` + loader + `developer-edge.example.json`.
- **Phase 2 — De-brand:** rename module/folder `ZuperiorDeveloperEdge` → `DeveloperEdge`,
  bundle id `com.zuperior.developeredge` → `com.developeredge.app`, app name,
  `Package.swift`, `Info.plist`, `make-app.sh`. Brand color + logo become config.
- **Phase 3 — Wire config:** replace globals (`allServices`, `clusters`,
  `allQuickLinks`, `allSlackChannels`, `Env` URLs, org/prefix constants, Jira
  host, default workspace) with `config.*`. Hide panels for absent sections.
- **Phase 4 — Generalize leaky features:** clusters become
  `{ label, credentialCommand }` so gcloud/EKS/`kubectl`/Azure all work;
  AI-instructions linking optional (keyed on a configured repo); celebrations
  optional + locale-aware holidays.
- **Phase 5 — Auto-discovery:** infer services from the org repo listing when
  `services` is empty (kind by name/topics).
- **Phase 6 — Release + OSS hygiene:** README (build-from-source + brew),
  CONTRIBUTING, notarization script, Homebrew cask formula, GitHub Actions
  release workflow.

## Features and their sandbox/cost notes (kept, since we're notarizing)

| Feature | Mechanism | Generalization needed |
|---|---|---|
| GitHub PRs / reviews | REST API | org name from config |
| Jira tickets | REST API | host + JQL from config |
| Pipeline status | REST API | org/repo from config |
| Workspace clone / fetch-all | `git` subprocess | org + clone URL + layout from config |
| Review Graph | `code-review-graph` subprocess | optional; off if tool absent |
| Kubernetes creds | `gcloud` subprocess | generalize to arbitrary command |
| Localhost health / port scan | HTTP + `lsof` | none (generic) |
| Open in editor / terminal | `open -a` | none (generic) |
| Quick links / Slack | URL open | fully from config |
| Celebrations / footer | local data | optional + locale |
