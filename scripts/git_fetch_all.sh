#!/bin/bash

branch_name=${1}

ALWAYS_PULL_BRANCHES=("development" "production" "staging")

if [ -t 1 ] && [ -z "${NO_COLOR-}" ]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    MAGENTA=$'\033[35m'
    CYAN=$'\033[36m'
    RESET=$'\033[0m'
else
    BOLD="" DIM="" RED="" GREEN="" YELLOW="" MAGENTA="" CYAN="" RESET=""
fi

branch_exists_remote() {
    git ls-remote --exit-code --heads origin "$1" > /dev/null 2>&1
}

prune_merged_branches() {
    # --format avoids the '*' (current) and '+' (other-worktree) prefix markers
    # that `git branch` adds, which previously caused `git branch -d +` errors.
    # Skip the current branch and any branch checked out in another worktree.
    local merged current_branch worktree_branches
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    worktree_branches=$(git worktree list --porcelain 2>/dev/null | awk '/^branch /{sub("refs/heads/","",$2); print $2}')
    merged=$(git branch --merged --format='%(refname:short)' \
        | grep -Ev "^(development|production|staging)$" \
        | { [ -z "$current_branch" ] && cat || grep -Fxv "$current_branch"; } \
        | { [ -z "$worktree_branches" ] && cat || grep -Fxv -f <(echo "$worktree_branches"); })
    if [ -n "$merged" ]; then
        echo "$merged" | xargs git branch -d
        echo "${DIM}Pruned merged branches.${RESET}"
    fi
}

update_pinned_branch() {
    local branch="$1"
    if ! branch_exists_remote "$branch"; then
        echo "${DIM}(not on remote — skipped)${RESET}"
        return
    fi
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        local local_sha remote_sha
        local_sha=$(git rev-parse "$branch")
        remote_sha=$(git rev-parse "origin/$branch")
        if [ "$local_sha" = "$remote_sha" ]; then
            echo "${DIM}Already up to date.${RESET}"
        elif git merge-base --is-ancestor "$local_sha" "$remote_sha"; then
            git update-ref "refs/heads/$branch" "$remote_sha"
            echo "${GREEN}Fast-forwarded to ${remote_sha:0:7}${RESET}"
        else
            echo "${YELLOW}⚠  diverged from origin/$branch — leaving local as-is${RESET}"
        fi
    else
        git branch "$branch" "origin/$branch" > /dev/null 2>&1
        echo "${CYAN}Created local branch from origin/$branch${RESET}"
    fi
}

update_other_local_branches() {
    local current_branch="$1"
    local printed_header=0
    local local_br upstream track

    while IFS=$'\t' read -r local_br upstream track; do
        # Skip active branch and pinned branches — already handled
        if [ "$local_br" = "$current_branch" ]; then continue; fi
        local pb skip=0
        for pb in "${ALWAYS_PULL_BRANCHES[@]}"; do
            if [ "$local_br" = "$pb" ]; then skip=1; break; fi
        done
        [ "$skip" = "1" ] && continue

        # Skip branches with no upstream
        if [ -z "$upstream" ]; then continue; fi

        if [ "$printed_header" = "0" ]; then
            echo ""
            echo "${BOLD}Other local branches:${RESET}"
            printed_header=1
        fi

        # Upstream gone (deleted on remote, just pruned)
        if [ "$track" = "[gone]" ]; then
            echo "  ${CYAN}$local_br${RESET}  ${YELLOW}⚠  upstream gone${RESET}"
            continue
        fi

        local local_sha remote_sha
        local_sha=$(git rev-parse "$local_br" 2>/dev/null)
        remote_sha=$(git rev-parse "$upstream" 2>/dev/null)
        if [ -z "$remote_sha" ]; then
            echo "  ${CYAN}$local_br${RESET}  ${DIM}(upstream missing)${RESET}"
        elif [ "$local_sha" = "$remote_sha" ]; then
            echo "  ${CYAN}$local_br${RESET}  ${DIM}up to date${RESET}"
        elif git merge-base --is-ancestor "$local_sha" "$remote_sha"; then
            git update-ref "refs/heads/$local_br" "$remote_sha"
            echo "  ${CYAN}$local_br${RESET}  ${GREEN}→ ${remote_sha:0:7}${RESET}"
        else
            echo "  ${CYAN}$local_br${RESET}  ${YELLOW}⚠  diverged${RESET}"
        fi
    done < <(git for-each-ref --format='%(refname:short)%09%(upstream:short)%09%(upstream:track)' refs/heads/)
}

do_repo_sync() {
    local current_branch
    if ! current_branch=$(git symbolic-ref --short HEAD 2>/dev/null); then
        echo "${YELLOW}⚠  detached HEAD — checking out development...${RESET}"
        local fallback
        for fallback in development production staging; do
            if git fetch origin "$fallback" 2>/dev/null && git checkout "$fallback" 2>/dev/null; then
                current_branch="$fallback"
                echo "${GREEN}→  switched to $fallback${RESET}"
                break
            fi
        done
        if ! current_branch=$(git symbolic-ref --short HEAD 2>/dev/null); then
            echo "${RED}✗  could not find development/production/staging on remote — skipping${RESET}"
            return 1
        fi
    fi

    if [ -n "$branch_name" ]; then
        local target="$branch_name"
        if ! branch_exists_remote "$branch_name"; then
            echo "${YELLOW}Branch $branch_name not found on remote, defaulting to development...${RESET}"
            target="development"
        fi
        git fetch origin "$target" > /dev/null 2>&1
        git checkout "$target" > /dev/null 2>&1 || return 1
        current_branch="$target"
    fi

    # Single fetch with --prune: updates every remote-tracking ref
    # AND removes refs/remotes/origin/* whose branches were deleted upstream.
    git fetch --prune origin || return 1

    echo ""
    echo "${BOLD}Active branch:${RESET} ${GREEN}$current_branch${RESET}"
    local head_sha upstream_sha
    head_sha=$(git rev-parse HEAD)
    upstream_sha=$(git rev-parse "origin/$current_branch" 2>/dev/null)
    if [ -z "$upstream_sha" ]; then
        echo "${YELLOW}⚠  no origin/$current_branch — skipping merge${RESET}"
    elif [ "$head_sha" = "$upstream_sha" ]; then
        echo "${DIM}Already up to date.${RESET}"
    elif ! git merge --ff-only "origin/$current_branch"; then
        echo "${YELLOW}⚠  could not fast-forward $current_branch (diverged or dirty working tree?)${RESET}"
        return 1
    fi

    local branch
    for branch in "${ALWAYS_PULL_BRANCHES[@]}"; do
        if [ "$branch" = "$current_branch" ]; then
            continue
        fi
        echo ""
        echo "${BOLD}Fetching Branch:${RESET} ${CYAN}$branch${RESET}"
        update_pinned_branch "$branch"
    done

    update_other_local_branches "$current_branch"

    prune_merged_branches
}

process_repo() {
    local repo_dir="$1"
    cd "$repo_dir" || return 1

    # Report the size of the git repo itself (.git), not the entire folder.
    # The folder size is dominated by gitignored build caches (node_modules,
    # .next, .terraform) which aren't meaningful for tracking the repo.
    local size
    if [ -d "$repo_dir/.git" ]; then
        size=$(du -sh "$repo_dir/.git" 2>/dev/null | awk '{print $1}')
    else
        size=$(du -sh "$repo_dir" 2>/dev/null | awk '{print $1}')
    fi

    if ! git remote | grep -q .; then
        echo "${DIM}(no remote — skipped)  ·  Size: ${size:-?}${RESET}"
        return 0
    fi

    local start_time
    start_time=$(date +%s)

    local stashed=0
    if [ -n "$(git status --porcelain)" ]; then
        if git stash push -u -m "git_fetch_all auto-stash" > /dev/null 2>&1; then
            stashed=1
            echo "${MAGENTA}↪  stashed local changes${RESET}"
        else
            echo "${RED}⚠  could not stash local changes — skipping repo${RESET}"
            return 1
        fi
    fi

    do_repo_sync
    local rc=$?

    if [ "$stashed" = "1" ]; then
        if git stash pop > /dev/null 2>&1; then
            echo "${MAGENTA}↩  restored stashed changes${RESET}"
        else
            echo "${YELLOW}⚠  stash pop had conflicts — your changes remain in 'git stash list'${RESET}"
        fi
    fi

    local elapsed=$(( $(date +%s) - start_time ))
    echo "${DIM}Size: ${size:-?}  ·  Time: ${elapsed}s${RESET}"

    return $rc
}

failures=()
BASEDIR=$(pwd)

while IFS= read -r git_dir; do
    repo_dir=$(dirname "$git_dir")
    repo_name=$(basename "$repo_dir")

    echo ""
    echo "${BOLD}${CYAN}━━━━ $repo_name ━━━━${RESET}"

    if ! ( process_repo "$repo_dir" ); then
        echo "${RED}✗  failed${RESET}"
        failures+=("$repo_name")
    fi
done < <(find "$BASEDIR" -type d -name ".git")

echo ""
echo "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [ ${#failures[@]} -ne 0 ]; then
    echo "${RED}${BOLD}Failed repositories:${RESET}"
    for f in "${failures[@]}"; do
        echo "  ${RED}✗${RESET} $f"
    done
else
    echo "${GREEN}${BOLD}All repositories processed successfully.${RESET}"
fi

echo ""
echo "${BOLD}Done.${RESET}"
