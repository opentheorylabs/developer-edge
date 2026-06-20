# Developer Edge

A configurable macOS menu-bar companion for fullstack teams. One click from the
menu bar gets you:

- **Pull requests** — your open PRs and review requests across a GitHub org
- **Jira** — your tickets in the current sprint, filterable by status
- **Environments** — per-service URLs and live health across dev/staging/prod
- **CI / pipelines** — latest GitHub Actions run status per service
- **Workspace** — one-click clone of every org repo into a tidy folder layout, plus fetch-all
- **Localhost** — health of your locally running services and a port scanner
- **Clusters** — refresh kube credentials with one click (gcloud / EKS / kubectl / Azure)
- **Quick links & Slack** — your team's dashboards and channels
- **Celebrations** — optional birthday / work-anniversary greetings

Everything team-specific lives in a single config file, so any team can use it
without touching code.

<!-- Add a screenshot here: docs/screenshot.png -->

## Install

### Homebrew (recommended)

```bash
brew install --cask developer-edge
```

### Build from source

Requires Xcode command-line tools (Swift 5.9+) and macOS 13+.

```bash
git clone https://github.com/your-org/developer-edge.git
cd developer-edge
./scripts/make-app.sh --install    # builds, copies to /Applications, launches
```

To start at login: System Settings → General → Login Items → add **Developer Edge**.

## Configure

Developer Edge reads one JSON config. Copy the example and edit it:

```bash
mkdir -p ~/.config/developer-edge
cp developer-edge.example.json ~/.config/developer-edge/config.json
$EDITOR ~/.config/developer-edge/config.json
```

The config is resolved from the first location found (then merged over built-in
defaults):

1. `$DEVELOPER_EDGE_CONFIG` — explicit path (handy for testing)
2. `<workspaceRoot>/developer-edge.json` — **commit this to your team's repo** so every dev shares one setup
3. `~/.config/developer-edge/config.json` — per-user
4. bundled defaults

Only `branding` and `github` are required. Every other section is optional and
its feature hides when omitted — no Jira host? the Jira tab shows a setup prompt.
No `services`? they're auto-discovered from your GitHub org.

**Secrets never go in the config file.** GitHub and Jira tokens are entered in the
app (first-run onboarding) and stored by macOS, not in JSON.

See [`developer-edge.example.json`](developer-edge.example.json) for every field,
and [`docs/OPEN-SOURCE-ROADMAP.md`](docs/OPEN-SOURCE-ROADMAP.md) for the design.

### Minimal config

```json
{
  "branding": { "appName": "Developer Edge", "accentColorHex": "#76B900" },
  "github": { "org": "your-org" }
}
```

That alone gives you PRs, review requests, repo cloning, fetch-all, and
auto-discovered services.

## Why not the Mac App Store?

Developer Edge shells out to `git`, `gcloud`/`kubectl`, `lsof`, and your editor —
all of which the App Store sandbox forbids. It ships instead as a Developer
ID-signed, notarized DMG and a Homebrew cask, which keeps every feature.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Issues and PRs welcome.

## License

MIT — see [LICENSE](LICENSE).
