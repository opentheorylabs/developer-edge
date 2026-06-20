# Zuperior Developer Edge

A macOS menu bar app for the Zuperior trading platform. Monitor service health, CI pipeline status, and access quick links across Dev, Staging, and Production environments — all from your menu bar.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

## Setup

### 1. Clone the repo

```bash
git clone git@github.com:zuperior-platform/zuperior-developer-edge.git
cd zuperior-developer-edge
```

### 2. Build and install

```bash
./make-app.sh --install
```

This builds a release binary, packages it as a `.app`, copies it to `/Applications`, and launches it. The app appears in your menu bar.

### 3. Configure credentials

Open the app → gear icon (⚙) → **Settings**. Set these three things:

#### GitHub PAT
Used to show CI pipeline status on services.

1. Go to [github.com](https://github.com) → Profile → **Settings** → **Developer Settings** → **Personal access tokens** → **Fine-grained tokens**
2. Click **Generate new token** → give it a name → set expiry
3. Under *Repository access*, select the `zuperior-platform` org
4. Under *Permissions*, grant **Actions** and **Contents** → Read-only
5. Copy the generated token
6. In the app: Settings → GitHub → **Set** → paste → Enter

#### Jira API Token
Used to show your assigned tickets in the JIRA tab.

1. Go to [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Click **Create API token** → give it a label → **Create**
3. Copy the token
4. In the app: Settings → Jira → **API Token** → **Set** → paste → Enter

#### Jira Account ID
Used to filter tickets assigned to you.

1. Go to [zuperior-platform.atlassian.net](https://zuperior-platform.atlassian.net) → click your avatar (top right) → **Profile**
2. Copy the account ID from the URL — it's the string after `/people/` (e.g. `712020:abc123...`)
3. In the app: Settings → Jira → **Jira ID** → **Set** → paste → Enter

> **Paste not working?** Use the terminal instead (replace `<value>`):
> ```bash
> defaults write com.zuperior.developeredge githubToken "<github-pat>"
> defaults write com.zuperior.developeredge jiraApiToken "<jira-token>"
> defaults write com.zuperior.developeredge jiraAccountId "<jira-account-id>"
> ```
> Then restart the app.

### 4. Auto-start at login (optional)

**System Settings → General → Login Items → +** → select `/Applications/Zuperior Developer Edge.app`

Or let the app register itself — it attempts this automatically on first launch.

## Usage

| Tab | Description |
|-----|-------------|
| **Actions** | Quick links — Grafana, GitHub repos, Jira board |
| **Dev** | Service health + CI status for Dev environment |
| **Staging** | Service health + CI status for Staging |
| **Prod** | Service health + CI status for Production |

Click any service row to open it in the browser. CI badges show the latest pipeline run status.

## Closing the app

Right-click the menu bar icon → **Quit**, or:

```bash
pkill -f ZuperiorDeveloperEdge
```

## Updating

Pull the latest changes and rebuild:

```bash
./update.sh
```

Or manually:

```bash
git pull && ./make-app.sh --install
```

## Project structure

```
Sources/ZuperiorDeveloperEdge/
├── AppDelegate.swift       # Menu bar item, popover lifecycle
├── Store.swift             # State, health checks, GitHub API calls
├── Models.swift            # Service/env definitions
├── Views/
│   ├── PanelView.swift     # Main panel with tabs
│   ├── ServiceRow.swift    # Per-service table row
│   ├── QuickActionsPanel.swift
│   ├── KubernetesPanel.swift
│   ├── SettingsView.swift
│   └── Components.swift
├── make-app.sh             # Build + install script
└── update.sh               # Auto-update script
```
