#!/bin/bash
#
# branch-audit.sh - Audit Git branches for compliance and cleanup needs
#
# Author: Agent 26 - DevOps & GitOps Architect
# Version: 1.0
# Date: 2025-11-16
#
# Description:
#   Audits Git repository branches against STANDARD-GIT-BRANCH-POLICY.md
#   Identifies naming violations, stale branches, and cleanup candidates.
#
# Usage:
#   ./branch-audit.sh [options]
#
# Options:
#   --repo <path>           Repository path (default: current directory)
#   --stale-days <n>        Days to consider stale (default: 30)
#   --output <format>       Output format: text|json|markdown (default: text)
#   --check-remote          Include remote branches in audit
#   --verbose               Enable detailed output
#   --help                  Show this help message
#
# Exit Codes:
#   0 - Success, no violations found
#   1 - Naming convention violations found
#   2 - Stale branches found
#   3 - Script error
#
# Examples:
#   ./branch-audit.sh
#   ./branch-audit.sh --stale-days 60 --output markdown
#   ./branch-audit.sh --repo /path/to/repo --check-remote
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_PATH="${PWD}"
STALE_DAYS=30
OUTPUT_FORMAT="text"
CHECK_REMOTE=false
VERBOSE=false
EXIT_CODE=0

# Valid branch patterns from STANDARD-GIT-BRANCH-POLICY.md
VALID_PATTERNS=(
    "^main$"
    "^develop$"
    "^feature/[a-z0-9-]+$"
    "^fix/[a-z0-9-]+$"
    "^hotfix/[a-z0-9-]+$"
    "^claude/[a-z0-9-]+-[A-Za-z0-9]{24,32}$"
    "^agent/[a-z0-9-]+/[a-z0-9-]+-[A-Za-z0-9]{24,32}$"
    "^release/v[0-9]+\.[0-9]+\.[0-9]+$"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

show_help() {
    sed -n '3,27p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
    fi
}

error() {
    echo "ERROR: $*" >&2
    exit 3
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                REPO_PATH="$2"
                shift 2
                ;;
            --stale-days)
                STALE_DAYS="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --check-remote)
                CHECK_REMOTE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

# Validate repository path
validate_repo() {
    if [[ ! -d "$REPO_PATH/.git" ]]; then
        error "Not a Git repository: $REPO_PATH"
    fi
    cd "$REPO_PATH" || error "Cannot access repository: $REPO_PATH"
    log "Validating repository: $REPO_PATH"
}

# Check if branch name matches any valid pattern
check_naming_convention() {
    local branch="$1"
    for pattern in "${VALID_PATTERNS[@]}"; do
        if [[ "$branch" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Get age of branch in days
get_branch_age() {
    local branch="$1"
    local last_commit_date
    last_commit_date=$(git log -1 --format=%ct "$branch" 2>/dev/null || echo "0")
    local current_date
    current_date=$(date +%s)
    local age_seconds=$((current_date - last_commit_date))
    local age_days=$((age_seconds / 86400))
    echo "$age_days"
}

# Check if branch is merged to develop or main
is_merged() {
    local branch="$1"
    local base="${2:-develop}"

    # Check if branch is merged to base
    if git merge-base --is-ancestor "$branch" "$base" 2>/dev/null; then
        return 0
    fi

    # Also check main if base is develop
    if [[ "$base" == "develop" ]] && git rev-parse main >/dev/null 2>&1; then
        if git merge-base --is-ancestor "$branch" "main" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Get branch author/creator
get_branch_author() {
    local branch="$1"
    git log --format=%an "$branch" | tail -1
}

# Collect branch data
collect_branch_data() {
    log "Collecting branch data..."

    declare -g -A branch_data
    declare -g -a all_branches
    declare -g -a naming_violations
    declare -g -a stale_merged
    declare -g -a stale_unmerged
    declare -g -a orphaned_agent

    # Get list of branches
    if [[ "$CHECK_REMOTE" == "true" ]]; then
        mapfile -t all_branches < <(git branch -r | sed 's/origin\///' | grep -v 'HEAD' | sort -u)
    else
        mapfile -t all_branches < <(git branch | sed 's/^[* ]*//' | sort)
    fi

    log "Found ${#all_branches[@]} branches to analyze"

    for branch in "${all_branches[@]}"; do
        local age
        age=$(get_branch_age "$branch")
        local merged="no"

        if is_merged "$branch"; then
            merged="yes"
        fi

        local author
        author=$(get_branch_author "$branch")

        # Check naming convention
        if ! check_naming_convention "$branch"; then
            naming_violations+=("$branch")
            EXIT_CODE=1
        fi

        # Check if stale
        if [[ $age -gt $STALE_DAYS ]]; then
            if [[ "$merged" == "yes" ]]; then
                stale_merged+=("$branch:$age")
            else
                stale_unmerged+=("$branch:$age")
            fi
            if [[ $EXIT_CODE -eq 0 ]]; then
                EXIT_CODE=2
            fi
        fi

        # Check for orphaned agent branches
        if [[ "$branch" =~ ^claude/ ]] || [[ "$branch" =~ ^agent/ ]]; then
            if [[ $age -gt 60 ]] && [[ "$merged" == "no" ]]; then
                orphaned_agent+=("$branch:$age")
            fi
        fi

        # Store branch data
        branch_data["$branch"]="age=$age merged=$merged author=$author"
    done

    log "Analysis complete"
}

# Generate text report
generate_text_report() {
    echo "=========================================="
    echo "  Git Branch Audit Report"
    echo "=========================================="
    echo ""
    echo "Repository: $REPO_PATH"
    echo "Date: $(date +'%Y-%m-%d %H:%M:%S')"
    echo "Stale threshold: $STALE_DAYS days"
    echo ""

    echo "SUMMARY"
    echo "-------"
    echo "Total branches: ${#all_branches[@]}"
    echo "Naming violations: ${#naming_violations[@]}"
    echo "Stale merged branches: ${#stale_merged[@]}"
    echo "Stale unmerged branches: ${#stale_unmerged[@]}"
    echo "Orphaned agent branches: ${#orphaned_agent[@]}"
    echo ""

    if [[ ${#naming_violations[@]} -gt 0 ]]; then
        echo "NAMING CONVENTION VIOLATIONS"
        echo "----------------------------"
        for branch in "${naming_violations[@]}"; do
            echo "  ❌ $branch"
        done
        echo ""
    fi

    if [[ ${#stale_merged[@]} -gt 0 ]]; then
        echo "STALE MERGED BRANCHES (safe to delete)"
        echo "---------------------------------------"
        for item in "${stale_merged[@]}"; do
            IFS=':' read -r branch age <<< "$item"
            echo "  🗑️  $branch (${age} days old)"
        done
        echo ""
    fi

    if [[ ${#stale_unmerged[@]} -gt 0 ]]; then
        echo "STALE UNMERGED BRANCHES (review before delete)"
        echo "-----------------------------------------------"
        for item in "${stale_unmerged[@]}"; do
            IFS=':' read -r branch age <<< "$item"
            echo "  ⚠️  $branch (${age} days old)"
        done
        echo ""
    fi

    if [[ ${#orphaned_agent[@]} -gt 0 ]]; then
        echo "ORPHANED AGENT BRANCHES (>60 days, unmerged)"
        echo "---------------------------------------------"
        for item in "${orphaned_agent[@]}"; do
            IFS=':' read -r branch age <<< "$item"
            echo "  🤖 $branch (${age} days old)"
        done
        echo ""
    fi

    echo "RECOMMENDATIONS"
    echo "---------------"
    if [[ ${#stale_merged[@]} -gt 0 ]]; then
        echo "✓ Run cleanup script to delete ${#stale_merged[@]} merged branches"
    fi
    if [[ ${#naming_violations[@]} -gt 0 ]]; then
        echo "✓ Rename ${#naming_violations[@]} branches to follow naming convention"
    fi
    if [[ ${#stale_unmerged[@]} -gt 0 ]]; then
        echo "✓ Review ${#stale_unmerged[@]} unmerged branches - archive or complete work"
    fi
    if [[ ${#orphaned_agent[@]} -gt 0 ]]; then
        echo "✓ Archive ${#orphaned_agent[@]} orphaned agent branches"
    fi

    if [[ ${#naming_violations[@]} -eq 0 ]] && [[ ${#stale_merged[@]} -eq 0 ]] && \
       [[ ${#stale_unmerged[@]} -eq 0 ]] && [[ ${#orphaned_agent[@]} -eq 0 ]]; then
        echo "✓ No issues found - repository is clean! 🎉"
    fi
    echo ""
}

# Generate JSON report
generate_json_report() {
    echo "{"
    echo "  \"repository\": \"$REPO_PATH\","
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"stale_threshold_days\": $STALE_DAYS,"
    echo "  \"summary\": {"
    echo "    \"total_branches\": ${#all_branches[@]},"
    echo "    \"naming_violations\": ${#naming_violations[@]},"
    echo "    \"stale_merged\": ${#stale_merged[@]},"
    echo "    \"stale_unmerged\": ${#stale_unmerged[@]},"
    echo "    \"orphaned_agent\": ${#orphaned_agent[@]}"
    echo "  },"
    echo "  \"violations\": ["
    local first=true
    for branch in "${naming_violations[@]}"; do
        [[ "$first" == "true" ]] && first=false || echo ","
        echo -n "    \"$branch\""
    done
    echo ""
    echo "  ],"
    echo "  \"stale_merged\": ["
    first=true
    for item in "${stale_merged[@]}"; do
        IFS=':' read -r branch age <<< "$item"
        [[ "$first" == "true" ]] && first=false || echo ","
        echo -n "    {\"branch\": \"$branch\", \"age_days\": $age}"
    done
    echo ""
    echo "  ],"
    echo "  \"stale_unmerged\": ["
    first=true
    for item in "${stale_unmerged[@]}"; do
        IFS=':' read -r branch age <<< "$item"
        [[ "$first" == "true" ]] && first=false || echo ","
        echo -n "    {\"branch\": \"$branch\", \"age_days\": $age}"
    done
    echo ""
    echo "  ]"
    echo "}"
}

# Generate Markdown report
generate_markdown_report() {
    echo "# Git Branch Audit Report"
    echo ""
    echo "**Repository:** \`$REPO_PATH\`  "
    echo "**Date:** $(date +'%Y-%m-%d %H:%M:%S')  "
    echo "**Stale Threshold:** $STALE_DAYS days  "
    echo ""

    echo "## Summary"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Total branches | ${#all_branches[@]} |"
    echo "| Naming violations | ${#naming_violations[@]} |"
    echo "| Stale merged branches | ${#stale_merged[@]} |"
    echo "| Stale unmerged branches | ${#stale_unmerged[@]} |"
    echo "| Orphaned agent branches | ${#orphaned_agent[@]} |"
    echo ""

    if [[ ${#naming_violations[@]} -gt 0 ]]; then
        echo "## Naming Convention Violations"
        echo ""
        for branch in "${naming_violations[@]}"; do
            echo "- ❌ \`$branch\`"
        done
        echo ""
    fi

    if [[ ${#stale_merged[@]} -gt 0 ]]; then
        echo "## Stale Merged Branches (Safe to Delete)"
        echo ""
        echo "| Branch | Age (days) |"
        echo "|--------|------------|"
        for item in "${stale_merged[@]}"; do
            IFS=':' read -r branch age <<< "$item"
            echo "| \`$branch\` | $age |"
        done
        echo ""
    fi

    if [[ ${#stale_unmerged[@]} -gt 0 ]]; then
        echo "## Stale Unmerged Branches (Review Before Delete)"
        echo ""
        echo "| Branch | Age (days) |"
        echo "|--------|------------|"
        for item in "${stale_unmerged[@]}"; do
            IFS=':' read -r branch age <<< "$item"
            echo "| ⚠️ \`$branch\` | $age |"
        done
        echo ""
    fi

    echo "## Recommendations"
    echo ""
    if [[ ${#stale_merged[@]} -gt 0 ]]; then
        echo "- ✓ Run cleanup script to delete ${#stale_merged[@]} merged branches"
    fi
    if [[ ${#naming_violations[@]} -gt 0 ]]; then
        echo "- ✓ Rename ${#naming_violations[@]} branches to follow naming convention"
    fi
    if [[ ${#stale_unmerged[@]} -gt 0 ]]; then
        echo "- ✓ Review ${#stale_unmerged[@]} unmerged branches"
    fi

    if [[ ${#naming_violations[@]} -eq 0 ]] && [[ ${#stale_merged[@]} -eq 0 ]] && \
       [[ ${#stale_unmerged[@]} -eq 0 ]] && [[ ${#orphaned_agent[@]} -eq 0 ]]; then
        echo "- ✓ No issues found - repository is clean! 🎉"
    fi
    echo ""
}

# Generate report based on format
generate_report() {
    case "$OUTPUT_FORMAT" in
        text)
            generate_text_report
            ;;
        json)
            generate_json_report
            ;;
        markdown|md)
            generate_markdown_report
            ;;
        *)
            error "Unknown output format: $OUTPUT_FORMAT"
            ;;
    esac
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"
    validate_repo
    collect_branch_data
    generate_report
    exit $EXIT_CODE
}

# Run main function
main "$@"
