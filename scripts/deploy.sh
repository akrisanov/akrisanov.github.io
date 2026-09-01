#!/usr/bin/env bash
set -euo pipefail

DEPLOY_BRANCH="gh-pages"
WORKTREE_DIR="$(mktemp -d)"
ROOT_DIR="$(git rev-parse --show-toplevel)"

cleanup() {
    git -C "$ROOT_DIR" worktree remove --force "$WORKTREE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

cd "$ROOT_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is not clean. Commit or stash your changes before deploying."
    exit 1
fi

for command in git zola magick; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required command not found: $command"
        exit 1
    fi
done

echo "==> Fetching $DEPLOY_BRANCH"
git fetch origin "$DEPLOY_BRANCH"

echo "==> Building site"
bash scripts/build-site.sh

echo "==> Preparing $DEPLOY_BRANCH"
git worktree add --detach "$WORKTREE_DIR" "origin/$DEPLOY_BRANCH"

find "$WORKTREE_DIR" -mindepth 1 -maxdepth 1 \
    ! -name .git \
    -exec rm -rf {} +

cp -R public/. "$WORKTREE_DIR/"

cd "$WORKTREE_DIR"

git add --all

if git diff --cached --quiet; then
    echo "Nothing to deploy."
    exit 0
fi

git commit -m "Deploy site"

echo "==> Deploying"
git push origin "HEAD:$DEPLOY_BRANCH"

echo "==> Deployment complete"
