#!/usr/bin/env bash
# ====================================================================
# 🚀 MULTI-NODE AUTOMATIC GIT SYNC SUBSYSTEM
# ====================================================================
# Description: Safely fetches, rebases updates, scans for keys, 
#              and pushes active modifications without conflicts.
# Target Folder: ~/.local/bin
# ====================================================================
set -euo pipefail

TARGET_DIR="$HOME/.local/bin"
LOG_INFO="[INFO]"
LOG_WARN="[WARN]"
LOG_FAIL="[ALERT]"

# Navigate to target directory
cd "$TARGET_DIR"

# Verify directory is an active git repo
if [ ! -d ".git" ]; then
    echo "$LOG_FAIL $TARGET_DIR is not initialized as a Git repository."
    exit 1
fi

echo "$LOG_INFO 1. Fetching absolute newest metadata from GitHub..."
git fetch origin main

# Check if local changes exist (staged or unstaged)
if ! git diff-index --quiet HEAD --; then
    echo "$LOG_WARN Local modifications detected. Preparing secure stage pipeline..."
    
    # Run pre-flight secret check if it exists in the bin directory
    if [ -x "./check-repo-secrets.sh" ]; then
        echo "$LOG_INFO Running pre-flight security scan..."
        ./check-repo-secrets.sh || {
            echo "$LOG_FAIL Security scan flagged an item. Fix hardcoded keys before syncing."
            exit 1
        }
    fi

    # Stage changes securely (respecting .gitignore rules)
    git add .
    
    # Commit changes locally with a dynamic timestamp signature
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    git commit -m "Automated update from node: $(hostname) ($TIMESTAMP)"
fi

echo "$LOG_INFO 2. Pulling and applying upstream updates via REBASE (Bypasses Conflict Loops)..."
# Pull remote modifications and replay local work cleanly on top
git pull --rebase origin main

# Check if we need to push anything back up to GitHub
LOCAL_SHA=$(git rev-parse HEAD)
REMOTE_SHA=$(git rev-parse origin/main)

if [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
    echo "$LOG_INFO 3. New local commits detected. Streaming securely upstream to GitHub..."
    git push origin main
    echo "$LOG_INFO Sync sequence complete. Repository successfully pushed."
else
    echo "$LOG_INFO Sync sequence complete. Node is perfectly level with origin/main."
fi
