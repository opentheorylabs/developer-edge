#!/usr/bin/env bash
# Developer Edge — roadmap + next-up todo
# Usage: ./scripts/roadmap.sh [--short]

set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; BLU='\033[0;34m'
YLW='\033[0;33m'; GRY='\033[0;90m'; BLD='\033[1m'; RST='\033[0m'

short=false
[[ "${1:-}" == "--short" ]] && short=true

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
last=$(git log -1 --format="%h %s" 2>/dev/null || echo "no commits")

echo ""
echo -e "${BLD}Developer Edge${RST}  branch: ${BLU}${branch}${RST}"
echo -e "  last commit: ${GRY}${last}${RST}"
echo ""

# ── v0.2 progress ─────────────────────────────────────────────────────────────
echo -e "${BLD}v0.2 — Provider flexibility${RST}"
echo -e "  ${GRN}✓${RST} Cut celebrations & Slack channels"
echo -e "  ${GRN}✓${RST} Linear integration (GraphQL, assigned issues, filter tabs)"
echo -e "  ${YLW}○${RST} Per-repo CI filtering        ${GRY}← next${RST}"
echo -e "  ${YLW}○${RST} Onboarding wizard — generalize"
echo -e "  ${YLW}○${RST} Read-only OAuth scope audit"
echo ""

if $short; then exit 0; fi

# ── v0.3 ───────────────────────────────────────────────────────────────────────
echo -e "${BLD}v0.3 — Developer signal quality${RST}  ${GRY}(planned)${RST}"
echo -e "  ${GRY}·${RST} PR staleness flags (48 h amber, 72 h red)"
echo -e "  ${GRY}·${RST} Branch → ticket link (current git branch ↔ Linear/Jira)"
echo -e "  ${GRY}·${RST} Smart notification filtering (my PRs, my branches)"
echo -e "  ${GRY}·${RST} Recent deploys surface (Actions, Vercel, Railway)"
echo -e "  ${GRY}·${RST} Keyboard navigation (↑↓ rows, ↩ open, ⌘K palette)"
echo ""

# ── v0.4 ───────────────────────────────────────────────────────────────────────
echo -e "${BLD}v0.4 — Ops & team features${RST}  ${GRY}(planned)${RST}"
echo -e "  ${GRY}·${RST} PagerDuty / on-call surface"
echo -e "  ${GRY}·${RST} Vercel / Railway deploy status"
echo -e "  ${GRY}·${RST} Shareable team config template"
echo -e "  ${GRY}·${RST} Sprint summary (Linear / Jira)"
echo ""

# ── v0.5 ───────────────────────────────────────────────────────────────────────
echo -e "${BLD}v0.5 — Observability layer${RST}  ${GRY}(future)${RST}"
echo -e "  ${GRY}·${RST} Datadog monitor surface"
echo -e "  ${GRY}·${RST} ArgoCD sync status"
echo ""

# ── next steps ─────────────────────────────────────────────────────────────────
echo -e "${BLD}Next steps for v0.2${RST}"
echo -e "  1. ${BLD}Per-repo CI filtering${RST}"
echo -e "     Add ${BLU}pinnedRepos: Set<String>${RST} to DefaultsKeys"
echo -e "     In Settings → Services: toggle per-repo checkboxes"
echo -e "     In Store+Pipeline: filter ${BLU}services.map(\.repo)${RST} through pinned set"
echo ""
echo -e "  2. ${BLD}Onboarding wizard — generalize${RST}"
echo -e "     Remove 'trading platform' string from welcomeStep copy"
echo -e "     Add Linear key step (step 3) shown only when config has linear"
echo -e "     Shift workspace step to step 4 when Linear step injected"
echo ""
echo -e "  3. ${BLD}OAuth scope audit${RST}"
echo -e "     Grep all token usages, confirm no config-file writes"
echo -e "     Verify GitHub token URL in onboarding requests only repo+read:org"
echo ""
