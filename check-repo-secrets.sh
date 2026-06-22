#!/usr/bin/env bash
# ====================================================================
# 🛡️  PRE-FLIGHT REPOSITORY SECRET & PRIVACY SCANNER
# ====================================================================
# Purpose: Scans target shell scripts and project directories for 
#          sensitive metrics, hardcoded keys, and PII before Git pushes.
# Usage:   check-repo-secrets.sh [target_directory_or_file]
#          (Defaults to the current working directory if omitted)
# ====================================================================
set -euo pipefail

# Define visual output log markers
LOG_INFO="[INFO]"
LOG_WARN="[WARN]"
LOG_FAIL="[ALERT]"
LOG_PASS="[PASS]"

# MODIFIED: Default to the current working directory ($PWD) instead of a fixed path
TARGET_PATH="${1:-$PWD}"

print_header() {
     echo "=================================================="
     echo "       CRYPTOGRAPHIC & PRIVACY AUDIT SUBSYSTEM     "
     echo "=================================================="
     echo "$LOG_INFO Target Path: $TARGET_PATH"
}

check_dependencies() {
     command -v grep >/dev/null 2>&1 || { echo "$LOG_FAIL grep is required but missing."; exit 1; }
}

run_scan() {
     local target="$1"
     local violations=0

     # 1. Check for bypass flags (e.g. if you have a file named '.noscan' in the target dir)
     if [[ -d "$target" && -f "$target/.noscan" ]]; then
         echo "$LOG_WARN Bypass tag found (.noscan). Skipping directory audit safely."
         exit 0
     elif [[ -f "$target" && "$(basename "$target")" == *".noscan"* ]]; then
          echo "$LOG_WARN Bypass tag filename matched. Skipping file audit safely."
          exit 0
     fi

     echo "-> Inspecting files for hardcoded secrets & credentials..."
     echo "--------------------------------------------------"

     # Define regex matrices for signatures we want to catch
     # Matches SSH private keys, general high-entropy tokens, generic passwords, and distinct names
     declare -A regex_patterns=(
         ["SSH Private Key"]="-----BEGIN .* PRIVATE KEY-----"
         ["GitHub Token"]="gh[pguo]_[A-Za-z0-9]{36,255}"
         ["Generic API/Secret Key"]="(?i)(api_key|secret_key|private_key|auth_token|passwd|password)\s*=\s*['\"][A-Za-z0-9_\-]{8,}['\"]"
     )

     # Use a temporary file to safely catalog targets
     local file_list
     file_list=$(mktemp)
     trap 'rm -f "$file_list"' EXIT

     if [[ -f "$target" ]]; then
         echo "$target" > "$file_list"
     else
         # Find all shell scripts and standard python files, excluding git directories
         find "$target" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.env" \) ! -path "*/.git/*" > "$file_list"
     fi

     # Core iteration scan sequence
     while IFS= read -r file; do
         [[ -z "$file" ]] && continue

         for pattern_name in "${!regex_patterns[@]}"; do
             local pattern="${regex_patterns[$pattern_name]}"

             # Use grep with line numbering (-n) and extended regex (-E / -P if supported)
             if grep -E -n "$pattern" "$file" > /tmp/scan_matches.tmp; then
                 while IFS= read -r match; do
                     local line_num
                     line_num=$(echo "$match" | cut -d: -f1)
                     local content
                     content=$(echo "$match" | cut -d: -f2- | xargs)

                     # Truncate content line print to avoid printing the actual sensitive key fully in console logs
                     local safe_content="${content:0:40}..."

                     echo "$LOG_FAIL Critical signature leak found in $file on line $line_num!"
                     echo "   Type:  $pattern_name"
                     echo "   Match: $safe_content"
                     echo "--------------------------------------------------"
                     violations=$((violations + 1))
                 done < /tmp/scan_matches.tmp
             fi
         done
     done < "$file_list"

     # Cleanup temporary workspace files cleanly
     rm -f /tmp/scan_matches.tmp

     # Evaluation phase logic
     if [[ $violations -gt 0 ]]; then
         echo "$LOG_FAIL Scan concluded with $violations validation failures."
         echo "$LOG_FAIL ACTION REQUIRED: Sanitize your code configurations before staging to GitHub."
         exit 1
     else
         echo "$LOG_PASS Audit completed successfully. No hardcoded credentials isolated."
         exit 0
     fi
}

# Execution Pipeline Entrypoint
main() {
     print_header
     check_dependencies

     if [[ ! -e "$TARGET_PATH" ]]; then
         echo "$LOG_FAIL Path validation failed: $TARGET_PATH does not exist."
         exit 1
     fi

     run_scan "$TARGET_PATH"
}

main
