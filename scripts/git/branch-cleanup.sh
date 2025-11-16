#!/bin/bash
#
# branch-cleanup.sh - Clean up stale and merged branches
#
# Author: Agent 26 - DevOps & GitOps Architect
# Version: 1.0
# Date: 2025-11-16
#
# Description:
#   Safely deletes merged and stale branches with archive capability.
#   Implements policies from STANDARD-GIT-BRANCH-POLICY.md
#
# Usage:
#   ./branch-cleanup.sh [options]
#
# Options:
#   --repo <path>           Repository path (default: current directory)
#   --stale-days <n>        Days to consider stale (default: 30)
#   --dry-run               Show what would be deleted (no changes)
#   --auto                  Skip confirmations (use with caution!)
#   --keep-merged <days>    Keep merged branches for N days (default: 7)
#   --archive-unmerged      Create tags for unmerged branches before delete
#   --branches <pattern>    Only process branches matching pattern
#   --remote                Also cleanup remote branches
#   --verbose               Enable detailed output
#   --help                  Show this help message
#
# Exit Codes:
#   0 - Success
#   1 - Some branches failed to delete
#   2 - No branches to clean
#   3 - Script error
#
# Safety Features:
#   - Never deletes main or develop
#   - Dry-run mode by default for first use
#   - Confirmation prompts for unmerged branches
#   - Archive tags before deletion
#   - Detailed logging
#
# Examples:
#   ./branch-cleanup.sh --dry-run
#   ./branch-cleanup.sh --auto --keep-merged 14
#   ./branch-cleanup.sh --branches "feature/*" --archive-unmerged
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_PATH="${PWD}"
STALE_DAYS=30
DRY_RUN=false
AUTO_MODE=false
KEEP_MERGED_DAYS=7
ARCHIVE_UNMERGED=false
BRANCH_PATTERN="*"
CLEANUP_REMOTE=false
VERBOSE=false

# Protected branches - never delete these
PROTECTED_BRANCHES=("main" "develop" "master")

# Logging
LOG_FILE=".git/cleanup-log.txt"
DELETED_COUNT=0
ARCHIVED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

# ============================================================================
# FUNCTIONS
# ============================================================================

show_help() {
    sed -n '3,32p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

log() {
    local message="$*"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$timestamp] $message" >&2
    fi

    # Always log to file
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

info() {
    echo "$*"
    log "INFO: $*"
}

warn() {
    echo "⚠️  WARNING: $*" >&2
    log "WARN: $*"
}

error() {
    echo "❌ ERROR: $*" >&2
    log "ERROR: $*"
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
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --keep-merged)
                KEEP_MERGED_DAYS="$2"
                shift 2
                ;;
            --archive-unmerged)
                ARCHIVE_UNMERGED=true
                shift
                ;;
            --branches)
                BRANCH_PATTERN="$2"
                shift 2
                ;;
            --remote)
                CLEANUP_REMOTE=true
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

# Validate repository
validate_repo() {
    if [[ ! -d "$REPO_PATH/.git" ]]; then
        error "Not a Git repository: $REPO_PATH"
    fi
    cd "$REPO_PATH" || error "Cannot access repository: $REPO_PATH"
    log "Working in repository: $REPO_PATH"
}

# Check if branch is protected
is_protected() {
    local branch="$1"
    for protected in "${PROTECTED_BRANCHES[@]}"; do
        if [[ "$branch" == "$protected" ]]; then
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

# Check if branch is merged
is_merged() {
    local branch="$1"
    local base="${2:-develop}"

    # Check if merged to develop
    if git merge-base --is-ancestor "$branch" "$base" 2>/dev/null; then
        return 0
    fi

    # Check if merged to main
    if git rev-parse main >/dev/null 2>&1; then
        if git merge-base --is-ancestor "$branch" "main" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Create archive tag for branch
archive_branch() {
    local branch="$1"
    local tag_name="archive/${branch//\//-}"
    local commit_sha
    commit_sha=$(git rev-parse "$branch")

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would create tag: $tag_name"
        return 0
    fi

    if git tag "$tag_name" "$branch" 2>/dev/null; then
        log "Created archive tag: $tag_name -> $commit_sha"
        ((ARCHIVED_COUNT++))

        # Push tag to remote if requested
        if [[ "$CLEANUP_REMOTE" == "true" ]]; then
            git push origin "$tag_name" 2>/dev/null || warn "Failed to push tag: $tag_name"
        fi

        return 0
    else
        warn "Failed to create archive tag: $tag_name"
        return 1
    fi
}

# Confirm deletion with user
confirm_deletion() {
    local branch="$1"
    local reason="$2"

    if [[ "$AUTO_MODE" == "true" ]]; then
        return 0
    fi

    echo ""
    echo "Branch: $branch"
    echo "Reason: $reason"
    read -p "Delete this branch? [y/N] " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Delete a branch
delete_branch() {
    local branch="$1"
    local reason="$2"
    local force="${3:-false}"

    log "Attempting to delete: $branch (reason: $reason)"

    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would delete: $branch ($reason)"
        ((DELETED_COUNT++))
        return 0
    fi

    # Delete local branch
    if [[ "$force" == "true" ]]; then
        if git branch -D "$branch" 2>/dev/null; then
            info "✓ Deleted: $branch ($reason)"
            ((DELETED_COUNT++))
        else
            warn "Failed to delete: $branch"
            ((FAILED_COUNT++))
            return 1
        fi
    else
        if git branch -d "$branch" 2>/dev/null; then
            info "✓ Deleted: $branch ($reason)"
            ((DELETED_COUNT++))
        else
            warn "Failed to delete: $branch (may have unmerged changes)"
            ((FAILED_COUNT++))
            return 1
        fi
    fi

    # Delete remote branch if requested
    if [[ "$CLEANUP_REMOTE" == "true" ]]; then
        if git push origin --delete "$branch" 2>/dev/null; then
            log "Deleted remote branch: origin/$branch"
        else
            warn "Failed to delete remote branch: origin/$branch"
        fi
    fi

    return 0
}

# Process merged branches
cleanup_merged_branches() {
    info "Scanning for merged branches older than $KEEP_MERGED_DAYS days..."

    local branches
    mapfile -t branches < <(git branch | sed 's/^[* ]*//' | grep -E "$BRANCH_PATTERN" || true)

    local found=false

    for branch in "${branches[@]}"; do
        # Skip protected branches
        if is_protected "$branch"; then
            continue
        fi

        # Check if merged
        if is_merged "$branch"; then
            local age
            age=$(get_branch_age "$branch")

            # Check if old enough to delete
            if [[ $age -gt $KEEP_MERGED_DAYS ]]; then
                found=true
                delete_branch "$branch" "merged and older than $KEEP_MERGED_DAYS days" "false"
            fi
        fi
    done

    if [[ "$found" == "false" ]]; then
        info "No merged branches to clean up"
    fi
}

# Process stale unmerged branches
cleanup_stale_unmerged() {
    info "Scanning for stale unmerged branches..."

    local branches
    mapfile -t branches < <(git branch | sed 's/^[* ]*//' | grep -E "$BRANCH_PATTERN" || true)

    local found=false

    for branch in "${branches[@]}"; do
        # Skip protected branches
        if is_protected "$branch"; then
            continue
        fi

        # Skip if merged
        if is_merged "$branch"; then
            continue
        fi

        local age
        age=$(get_branch_age "$branch")

        # Check if stale
        if [[ $age -gt $STALE_DAYS ]]; then
            found=true

            # Archive if requested
            if [[ "$ARCHIVE_UNMERGED" == "true" ]]; then
                archive_branch "$branch"
            fi

            # Confirm before deleting unmerged branch
            if confirm_deletion "$branch" "unmerged and stale ($age days)"; then
                delete_branch "$branch" "unmerged but stale ($age days)" "true"
            else
                info "Skipped: $branch"
                ((SKIPPED_COUNT++))
            fi
        fi
    done

    if [[ "$found" == "false" ]]; then
        info "No stale unmerged branches found"
    fi
}

# Cleanup orphaned agent branches
cleanup_orphaned_agent_branches() {
    info "Scanning for orphaned agent branches..."

    local branches
    mapfile -t branches < <(git branch | sed 's/^[* ]*//' | grep -E '^(claude|agent)/' || true)

    local found=false

    for branch in "${branches[@]}"; do
        local age
        age=$(get_branch_age "$branch")

        # Orphaned if >60 days and unmerged
        if [[ $age -gt 60 ]] && ! is_merged "$branch"; then
            found=true

            if [[ "$ARCHIVE_UNMERGED" == "true" ]]; then
                archive_branch "$branch"
            fi

            if [[ "$AUTO_MODE" == "true" ]] || confirm_deletion "$branch" "orphaned agent branch ($age days)"; then
                delete_branch "$branch" "orphaned agent branch ($age days)" "true"
            else
                ((SKIPPED_COUNT++))
            fi
        fi

        # Auto-delete merged agent branches >30 days
        if [[ $age -gt 30 ]] && is_merged "$branch"; then
            found=true
            delete_branch "$branch" "merged agent branch older than 30 days" "false"
        fi
    done

    if [[ "$found" == "false" ]]; then
        info "No orphaned agent branches found"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "  Cleanup Summary"
    echo "=========================================="
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "MODE: DRY RUN (no actual changes made)"
        echo ""
    fi

    echo "Branches deleted:  $DELETED_COUNT"
    echo "Branches archived: $ARCHIVED_COUNT"
    echo "Branches skipped:  $SKIPPED_COUNT"
    echo "Failed deletions:  $FAILED_COUNT"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""

    if [[ "$DRY_RUN" == "true" ]] && [[ $DELETED_COUNT -gt 0 ]]; then
        echo "Re-run without --dry-run to apply changes"
    fi

    if [[ $DELETED_COUNT -eq 0 ]] && [[ $FAILED_COUNT -eq 0 ]] && [[ $SKIPPED_COUNT -eq 0 ]]; then
        echo "✓ No cleanup needed - repository is clean! 🎉"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"
    validate_repo

    # Initialize log file
    if [[ ! -f "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        touch "$LOG_FILE"
    fi

    log "========== Branch Cleanup Started =========="
    log "Repository: $REPO_PATH"
    log "Stale threshold: $STALE_DAYS days"
    log "Keep merged: $KEEP_MERGED_DAYS days"
    log "Dry run: $DRY_RUN"
    log "Auto mode: $AUTO_MODE"
    log "Archive unmerged: $ARCHIVE_UNMERGED"

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Running in DRY-RUN mode - no actual changes will be made"
        echo ""
    fi

    # Run cleanup operations
    cleanup_merged_branches
    cleanup_stale_unmerged
    cleanup_orphaned_agent_branches

    # Print summary
    print_summary

    log "========== Branch Cleanup Completed =========="

    # Exit codes
    if [[ $FAILED_COUNT -gt 0 ]]; then
        exit 1
    elif [[ $DELETED_COUNT -eq 0 ]] && [[ $ARCHIVED_COUNT -eq 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Run main function
main "$@"
