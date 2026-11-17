#!/usr/bin/env bash
# Copies docs/wiki/*.md into the repository's GitHub wiki.
# The wiki repository only exists after its first page is created in the GitHub web interface.
# Usage: scripts/sync-wiki.sh [wiki-git-url]
set -euo pipefail

cd "$(dirname "$0")/.."
wiki_url="${1:-git@github.com:sorens-co/topd.wiki.git}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if ! git clone -q "$wiki_url" "$work/wiki"; then
    echo "Could not clone $wiki_url." >&2
    echo "Create the first wiki page in the GitHub web interface (Wiki tab), then run this again." >&2
    exit 1
fi

cp docs/wiki/*.md "$work/wiki/"
cd "$work/wiki"
git add -A
if git diff --cached --quiet; then
    echo "Wiki already up to date."
    exit 0
fi
git -c user.name="topd wiki sync" -c user.email="noreply@users.noreply.github.com" commit -q -m "Sync wiki from docs/wiki"
git push -q origin HEAD
echo "Wiki synced."
