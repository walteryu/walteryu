#!/usr/bin/env bash
# ====================================================================
# 🚀 UNIVERSAL AUTOMATIC GIT SYNC SUBSYSTEM
# ====================================================================
# Description: Safely fetches, rebases updates, scans for keys, 
#              and pushes active modifications dynamically to the repo's
#              assigned upstream remote and branch without hardcoding.
# Usage:       Execute directly within any Git repository.
# ====================================================================
set -euo pipefail

# MODIFIED: Dynamically target the current working directory ($PWD)
TARGET_DIR="$PWD"
LOG_INFO="[INFO]"
LOG_WARN="[WARN]"
LOG_FAIL="[ALERT]"

# Verify current directory is an active git repo
if [ ! -d ".git" ]; then
     echo "$LOG_FAIL Target: $TARGET_DIR is not initialized as a Git repository."
     echo "       Please run this script inside a valid project repository folder."
     exit 1
fi

# ====================================================================
# DYNAMIC METADATA EXTRACTION (Replaces hardcoded origin/main)
# ====================================================================
# 1. Get current active branch name (e.g., main, master, dev)
CURRENT_BRANCH=$(git branch --show-current)

if [ -z "$CURRENT_BRANCH" ]; then
     echo "$LOG_FAIL Unable to detect a valid active local branch (detached HEAD?)."
     exit 1
fi

# 2. Get the assigned remote tracking branch name. If not linked explicitly, 
#    fallback to the first configured remote name in 'git remote'.
REMOTE_NAME=$(git config --get "branch.${CURRENT_BRANCH}.remote" || git remote | head -n 1)

if [ -z "$REMOTE_NAME" ]; then
     echo "$LOG_FAIL No Git remotes found configured in 'git remote -v'."
     exit 1
fi

echo "$LOG_INFO Active Repository    : $TARGET_DIR"
echo "$LOG_INFO Detected Upstream Remote : $REMOTE_NAME"
echo "$LOG_INFO Detected Active Branch   : $CURRENT_BRANCH"
echo "--------------------------------------------------"

# ====================================================================
# SYNC PIPELINE EXECUTIONS
# ====================================================================
echo "$LOG_INFO 1. Fetching absolute newest metadata from GitHub..."
git fetch "$REMOTE_NAME" "$CURRENT_BRANCH"

# Check if local changes exist (staged or unstaged)
if ! git diff-index --quiet HEAD --; then
     echo "$LOG_WARN Local modifications detected. Preparing secure stage pipeline..."

     # Run pre-flight secret check if it exists in the current directory or local path
     SCANNER_SCRIPT=""
     if [ -x "./check-repo-secrets" ]; then
         SCANNER_SCRIPT="./check-repo-secrets"
     elif [ -x "./check-repo-secrets.sh" ]; then
         SCANNER_SCRIPT="./check-repo-secrets.sh"
     elif command -v check-repo-secrets >/dev/null 2>&1; then
         # Fallback to checking if the scanner is globally available in your environment path
         SCANNER_SCRIPT="check-repo-secrets"
     fi

     if [ -n "$SCANNER_SCRIPT" ]; then
         echo "$LOG_INFO Running pre-flight security scan ($SCANNER_SCRIPT)..."
         "$SCANNER_SCRIPT" || {
             echo "$LOG_FAIL Security scan flagged an item. Fix hardcoded keys before syncing."
             exit 1
         }
     fi

     # Stage changes securely (respecting .gitignore rules)
     git add -A

     # Commit changes locally with a dynamic timestamp signature
     TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
     git commit -m "Automated update from node: $(hostname) ($TIMESTAMP)"
fi

echo "$LOG_INFO 2. Pulling and applying upstream updates via REBASE..."
# Pull remote modifications and replay local work cleanly on top
git pull --rebase "$REMOTE_NAME" "$CURRENT_BRANCH"

# Check if we need to push anything back up to GitHub
LOCAL_SHA=$(git rev-parse HEAD)
REMOTE_SHA=$(git rev-parse "${REMOTE_NAME}/${CURRENT_BRANCH}")

if [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
     echo "$LOG_INFO 3. New local commits detected. Streaming securely upstream to GitHub..."
     git push "$REMOTE_NAME" "$CURRENT_BRANCH"
     echo "$LOG_INFO Sync sequence complete. Repository successfully pushed."
else
     echo "$LOG_INFO Sync sequence complete. Node is perfectly level with ${REMOTE_NAME}/${CURRENT_BRANCH}."
fi
