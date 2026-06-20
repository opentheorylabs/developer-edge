#!/usr/bin/env bash
# Check for updates on the main branch, rebuild and relaunch if anything changed.
#
#   ./update.sh [repo-path]   # check and update if needed
#   ./update.sh --force       # rebuild and relaunch even if already up to date
#
set -euo pipefail

BRANCH="main"
FORCE=""
REPO=""

for arg in "$@"; do
    if [[ "$arg" == "--force" ]]; then FORCE="--force"
    elif [[ -d "$arg/.git" ]]; then REPO="$arg"
    fi
done

# Fall back to the directory containing this script (works when run from the repo)
if [[ -z "$REPO" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [[ -d "$SCRIPT_DIR/.git" ]]; then
        REPO="$SCRIPT_DIR"
    fi
fi

if [[ -z "$REPO" ]]; then
    echo "ERROR: Could not find the repo. Pass the repo path as an argument."
    exit 1
fi

cd "$REPO"
echo "Checking for updates in $REPO..."
git fetch origin "$BRANCH" --quiet

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "origin/$BRANCH")

if [[ "$LOCAL" == "$REMOTE" && "$FORCE" != "--force" ]]; then
    echo "Already up to date ($(git rev-parse --short HEAD)). Nothing to do."
    exit 0
fi

echo "Update found: $(git rev-parse --short HEAD) → $(git rev-parse --short origin/$BRANCH)"
git pull origin "$BRANCH" --quiet
echo "Pulled latest. Rebuilding..."
"$REPO/scripts/make-app.sh" --install
