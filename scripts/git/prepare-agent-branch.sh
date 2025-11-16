#!/bin/bash
#
# prepare-agent-branch.sh - Prepare branch for AI agent work
#
# Author: Agent 26 - DevOps & GitOps Architect
# Version: 1.0
# Date: 2025-11-16
#
# Description:
#   Creates properly named AI agent branches with validation.
#   Ensures branch naming follows STANDARD-GIT-BRANCH-POLICY.md
#
# Usage:
#   ./prepare-agent-branch.sh <task-description> <session-id> [base-branch] [agent-type]
#
# Arguments:
#   task-description    Brief task description (will be sanitized)
#   session-id          Agent session ID (24-32 alphanumeric chars)
#   base-branch         Base branch to branch from (default: develop)
#   agent-type          Agent type: claude|agent (default: claude)
#
# Exit Codes:
#   0 - Success, branch created and ready
#   1 - Invalid arguments
#   2 - Branch already exists
#   3 - Git operation failed
#
# Examples:
#   ./prepare-agent-branch.sh "setup-ci" "01K6xLndeu5hU8pH3L6aWxn8"
#   ./prepare-agent-branch.sh "fix-auth" "01M9nP2Q3R4S5T6U7V8W9X0Y" "main"
#   ./prepare-agent-branch.sh "add-tests" "abc123def456" "develop" "agent"
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

TASK_DESCRIPTION=""
SESSION_ID=""
BASE_BRANCH="develop"
AGENT_TYPE="claude"
BRANCH_NAME=""

# Validation patterns
SESSION_ID_PATTERN='^[A-Za-z0-9]{24,32}$'
TASK_NAME_PATTERN='^[a-z0-9-]{3,50}$'

# ============================================================================
# FUNCTIONS
# ============================================================================

show_help() {
    sed -n '3,24p' "$0" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

error() {
    echo "ERROR: $*" >&2
    exit "${2:-3}"
}

info() {
    echo "$*"
}

# Validate session ID format
validate_session_id() {
    local session_id="$1"

    if [[ ! "$session_id" =~ $SESSION_ID_PATTERN ]]; then
        error "Invalid session ID format. Must be 24-32 alphanumeric characters." 1
    fi

    info "✓ Session ID validated: $session_id"
}

# Sanitize task name to follow naming convention
sanitize_task_name() {
    local task="$1"

    # Convert to lowercase
    task="${task,,}"

    # Replace spaces and underscores with hyphens
    task="${task// /-}"
    task="${task//_/-}"

    # Remove special characters except hyphens
    task="$(echo "$task" | sed 's/[^a-z0-9-]//g')"

    # Remove consecutive hyphens
    task="$(echo "$task" | sed 's/--*/-/g')"

    # Remove leading/trailing hyphens
    task="$(echo "$task" | sed 's/^-*//' | sed 's/-*$//')"

    # Truncate to 50 characters
    task="${task:0:50}"

    # Validate final format
    if [[ ! "$task" =~ $TASK_NAME_PATTERN ]]; then
        error "Task name '$task' is invalid after sanitization. Must be 3-50 chars, lowercase, hyphens only." 1
    fi

    echo "$task"
}

# Construct branch name
construct_branch_name() {
    local task="$1"
    local session="$2"
    local agent="$3"

    if [[ "$agent" == "claude" ]]; then
        echo "claude/${task}-${session}"
    else
        echo "agent/${agent}/${task}-${session}"
    fi
}

# Check if base branch exists
validate_base_branch() {
    local base="$1"

    if ! git rev-parse --verify "$base" >/dev/null 2>&1; then
        error "Base branch '$base' does not exist" 1
    fi

    info "✓ Base branch exists: $base"
}

# Check if branch already exists
check_branch_exists() {
    local branch="$1"

    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
        error "Branch '$branch' already exists. Use a different task name or session ID." 2
    fi

    # Check remote as well
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        error "Branch '$branch' already exists on remote. Use a different task name or session ID." 2
    fi

    info "✓ Branch name is available: $branch"
}

# Update base branch
update_base_branch() {
    local base="$1"

    info "Updating base branch: $base"

    # Fetch latest from remote
    if ! git fetch origin "$base" 2>/dev/null; then
        error "Failed to fetch base branch from remote" 3
    fi

    # Check if local branch is behind remote
    local local_sha
    local remote_sha
    local_sha=$(git rev-parse "$base" 2>/dev/null || echo "")
    remote_sha=$(git rev-parse "origin/$base" 2>/dev/null || echo "")

    if [[ -n "$local_sha" ]] && [[ -n "$remote_sha" ]] && [[ "$local_sha" != "$remote_sha" ]]; then
        # Stash any changes if on base branch
        local current_branch
        current_branch=$(git rev-parse --abbrev-ref HEAD)

        if [[ "$current_branch" == "$base" ]]; then
            git stash push -m "Auto-stash before branch preparation" 2>/dev/null || true
        fi

        # Update base branch
        git checkout "$base" 2>/dev/null || true
        git pull origin "$base" || error "Failed to update base branch" 3

        info "✓ Base branch updated to latest"
    else
        info "✓ Base branch is up to date"
    fi
}

# Create agent branch
create_agent_branch() {
    local branch="$1"
    local base="$2"

    info "Creating branch: $branch from $base"

    # Checkout base branch
    if ! git checkout "$base" 2>/dev/null; then
        error "Failed to checkout base branch: $base" 3
    fi

    # Create new branch
    if ! git checkout -b "$branch" 2>/dev/null; then
        error "Failed to create branch: $branch" 3
    fi

    info "✓ Branch created and checked out: $branch"
}

# Set upstream tracking
set_upstream_tracking() {
    local branch="$1"

    info "Setting upstream tracking for: $branch"

    # Set upstream (this will be used for first push)
    if git branch --set-upstream-to="origin/$branch" "$branch" 2>/dev/null; then
        info "✓ Upstream tracking set"
    else
        # It's okay if this fails - branch doesn't exist on remote yet
        info "Note: Upstream will be set on first push"
    fi
}

# Set branch metadata
set_branch_metadata() {
    local branch="$1"
    local task="$2"
    local session="$3"

    # Set branch description (Git config)
    git config "branch.${branch}.description" "AI Agent Task: $task (Session: $session)" 2>/dev/null || true

    info "✓ Branch metadata configured"
}

# Verify push access (test)
verify_push_access() {
    local branch="$1"

    info "Verifying push access..."

    # Try to push (with --dry-run)
    if git push --dry-run origin "$branch" 2>/dev/null; then
        info "✓ Push access verified"
        return 0
    else
        # This might fail if branch doesn't exist on remote yet, which is fine
        info "Note: Push will be tested on first actual push"
        return 0
    fi
}

# Print success message with instructions
print_success() {
    local branch="$1"

    echo ""
    echo "=========================================="
    echo "  ✓ Agent Branch Ready"
    echo "=========================================="
    echo ""
    echo "Branch: $branch"
    echo ""
    echo "Next steps:"
    echo "  1. Make your changes"
    echo "  2. Commit: git commit -m 'Your message'"
    echo "  3. Push: git push -u origin $branch"
    echo ""
    echo "Push command (copy-paste ready):"
    echo "  git push -u origin $branch"
    echo ""
    echo "Note: The session ID in your branch name"
    echo "      must match your agent session ID, or"
    echo "      pushes will be rejected with 403."
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        echo "ERROR: Missing required arguments"
        echo ""
        show_help
    fi

    TASK_DESCRIPTION="$1"
    SESSION_ID="$2"
    BASE_BRANCH="${3:-develop}"
    AGENT_TYPE="${4:-claude}"

    # Validate we're in a Git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not a Git repository" 1
    fi

    info "Preparing AI agent branch..."
    echo ""

    # Validate session ID
    validate_session_id "$SESSION_ID"

    # Sanitize task name
    local sanitized_task
    sanitized_task=$(sanitize_task_name "$TASK_DESCRIPTION")

    if [[ "$sanitized_task" != "$TASK_DESCRIPTION" ]]; then
        info "Task name sanitized: '$TASK_DESCRIPTION' → '$sanitized_task'"
    fi

    info "✓ Task name validated: $sanitized_task"

    # Construct branch name
    BRANCH_NAME=$(construct_branch_name "$sanitized_task" "$SESSION_ID" "$AGENT_TYPE")
    info "✓ Branch name: $BRANCH_NAME"
    echo ""

    # Validate base branch exists
    validate_base_branch "$BASE_BRANCH"

    # Check if branch already exists
    check_branch_exists "$BRANCH_NAME"

    # Update base branch to latest
    update_base_branch "$BASE_BRANCH"
    echo ""

    # Create agent branch
    create_agent_branch "$BRANCH_NAME" "$BASE_BRANCH"

    # Set upstream tracking
    set_upstream_tracking "$BRANCH_NAME"

    # Set branch metadata
    set_branch_metadata "$BRANCH_NAME" "$sanitized_task" "$SESSION_ID"

    # Verify push access
    verify_push_access "$BRANCH_NAME"
    echo ""

    # Print success message
    print_success "$BRANCH_NAME"

    exit 0
}

# Handle --help flag
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_help
fi

# Run main function
main "$@"
