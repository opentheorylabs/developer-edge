# Developer Edge — Backlog

## Standup Helper

Show a quick summary of yesterday's activity to help with daily standups. Surfaces inside the Development tab or as a dedicated section.

**Data sources:**
- GitHub API (already wired): PRs opened/merged, commits pushed yesterday
- Jira API (already wired): tickets moved to In Progress or Done yesterday

**Layout:**
- PRs merged yesterday
- PRs still open / in review
- Tickets moved to Done
- Tickets moved to In Progress

**Requires:** GitHub PAT + Jira credentials (already in Settings).

---

## HTTPS + PAT git fallback (teammate onboarding)

Git operations (Setup clone, Git Fetch All, in-app Update) currently use **SSH** (`git@github.com`). Teammates without an SSH key registered / SSO-authorized for the org hit clone/fetch failures.

**Fix:** since the app already stores everyone's GitHub PAT, fall back to HTTPS auth when SSH isn't available. Cleanest with the existing git-CLI approach, no heavy dependency:
```
git -c http.https://github.com/.extraheader="AUTHORIZATION: Bearer <PAT>" clone https://github.com/zuperior-platform/<repo>.git
```
Token passed transiently (not written into `.git/config` or remotes). Leave clean HTTPS remotes, or detect SSH availability (`ssh -T git@github.com`) and prefer SSH when present.

**Also (errors hidden below the fold):** the failure message scrolled off-screen so the teammate never saw why it failed. Surface errors as a **toast from the top** using [sanzaru/SimpleToast](https://github.com/sanzaru/SimpleToast) (lightweight, SwiftUI, custom content so it matches `Theme`). Short message in the toast (e.g. "Setup failed — token needs SSO"), full detail still in the console. Auto-dismiss after a few seconds.

---

## No-network states

Empty and error views should distinguish "offline" from "no data" / "request failed". Detect no-network (e.g. `NWPathMonitor` or URLError `.notConnectedToInternet`) and show a dedicated "You're offline" state with a retry, across GitHub / Jira / Services / Setup. Right now a dropped connection looks like a generic error or empty list.

---

## Streak

Track a daily-use (or daily-standup / daily-fetch) streak to add a light habit loop.

**Idea:**
- Increment a streak counter the first time the app is opened each day (consecutive days; resets if a day is missed).
- Show it subtly in the header or footer (e.g. "🔥 7-day streak").
- Optionally tie it to an action rather than just opening — e.g. Join Standup tapped, or Git Fetch All run.
- Persist `streakCount` + `streakLastDay` via Defaults.

**Milestones (optional):** small celebratory footer message at 7 / 30 / 100 days.

---

## Mascot Easter Egg

Clicking the header logo reveals the Zuperior mascot sliding up from the bottom (auto-hides after a few seconds). Needs a transparent `mascot.png` bundled in the app (background removed). Animation wired in `PanelView`.

---

## ⚠️ Under Consideration

### DB Shortcuts
One-click to open a database connection in TablePlus or another DB client for dev/staging environments.

**Not sure if worth it** — connection strings contain credentials, needs careful handling. Evaluate whether the team actually context-switches to a DB client often enough to justify this.
