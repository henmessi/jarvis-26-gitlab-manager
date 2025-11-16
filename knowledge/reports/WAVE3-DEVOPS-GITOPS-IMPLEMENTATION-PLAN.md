# WAVE3-DEVOPS-GITOPS-IMPLEMENTATION-PLAN.md

**Version:** 1.0
**Owner:** Agent 26 – DevOps & GitOps Architect
**Date:** 2025-11-16
**Status:** Active - Implementation Phase

## Executive Summary

This document outlines the implementation plan for establishing robust DevOps and GitOps practices across the Jarvis multi-agent ecosystem. The plan focuses on:

1. **Branch Policy Standardization** - Consistent Git workflows across all repositories
2. **Automated Branch Management** - Audit and cleanup tooling
3. **CI/CD Foundation** - Basic pipeline infrastructure
4. **AI Agent Enablement** - Safe branch management for autonomous agents

**Timeline:** 2-3 weeks
**Priority:** High (P0) - Foundational infrastructure

---

## Phase 1: Standards and Documentation (Week 1)

### 1.1 Git Branch Policy Standard ✅

**Status:** COMPLETED
**Document:** `knowledge/standards/STANDARD-GIT-BRANCH-POLICY.md`

**Deliverables:**
- ✅ Branch type definitions (main, develop, feature/*, claude/*)
- ✅ Naming conventions and validation rules
- ✅ Merge policies and PR requirements
- ✅ AI agent-specific guidelines
- ✅ Protection rules matrix
- ✅ Emergency procedures

**Next Steps:**
- Roll out to all Jarvis repositories
- Train agents on new policies
- Configure GitHub protection rules

---

### 1.2 Repository Assessment

**Status:** PENDING
**Owner:** Agent 26 (this agent)

**Objectives:**
1. Audit all Jarvis repositories
2. Identify non-compliant branches
3. Document current state
4. Prioritize cleanup targets

**Repositories to Audit:**
- `jarvis-00-central-nexus` (highest priority)
- `jarvis-01-*` through `jarvis-26-*` (all category repos)
- `jarvis-shared-*` (shared libraries)
- Any archived or legacy repos

**Assessment Criteria:**
- Total branch count
- Stale branch count (>30 days inactive)
- Naming convention violations
- Unmerged work-in-progress
- Missing protection rules

**Output:** `knowledge/reports/REPOSITORY-AUDIT-REPORT-{DATE}.md`

---

## Phase 2: Branch Management Automation (Week 1-2)

### 2.1 Branch Audit Script

**Script:** `scripts/git/branch-audit.sh`
**Status:** SPEC READY
**Owner:** Codex Agent (Category 15)

**Requirements:**

```bash
#!/bin/bash
# branch-audit.sh - Audit Git branches for compliance and cleanup needs

# Features:
# 1. List all local and remote branches
# 2. Check naming convention compliance
# 3. Identify stale branches (configurable threshold, default 30 days)
# 4. Detect unmerged branches
# 5. Calculate branch statistics
# 6. Generate cleanup recommendations

# Usage:
#   ./branch-audit.sh [options]
#
# Options:
#   --repo <path>           Repository path (default: current dir)
#   --stale-days <n>        Days to consider stale (default: 30)
#   --output <format>       Output format: text|json|markdown (default: text)
#   --check-remote          Include remote branches
#   --verbose               Detailed output

# Output sections:
# - Summary statistics
# - Protected branches status
# - Naming violations
# - Stale branches (merged and unmerged)
# - Orphaned agent branches
# - Recommendations
```

**Key Functions:**
1. `check_naming_convention()` - Validate branch names against policy
2. `get_branch_age()` - Calculate days since last commit
3. `is_merged()` - Check if branch is merged to develop/main
4. `get_branch_author()` - Identify who created branch
5. `generate_report()` - Format output (text/JSON/markdown)

**Validation Rules:**
- Branch name matches patterns: `main`, `develop`, `feature/*`, `fix/*`, `hotfix/*`, `claude/*`, `agent/*`, `release/*`
- Claude branches must have session ID suffix (format: `claude/*-[A-Za-z0-9]{24,32}`)
- No uppercase letters, special characters except `-` and `/`

**Exit Codes:**
- 0: Success, no violations
- 1: Naming violations found
- 2: Stale branches found
- 3: Script error

---

### 2.2 Branch Cleanup Script

**Script:** `scripts/git/branch-cleanup.sh`
**Status:** SPEC READY
**Owner:** Codex Agent (Category 15)

**Requirements:**

```bash
#!/bin/bash
# branch-cleanup.sh - Clean up stale and merged branches

# Features:
# 1. Safe deletion of merged branches
# 2. Archive unmerged work before deletion
# 3. Dry-run mode for safety
# 4. Confirmation prompts
# 5. Cleanup logging

# Usage:
#   ./branch-cleanup.sh [options]
#
# Options:
#   --repo <path>           Repository path (default: current dir)
#   --stale-days <n>        Days to consider stale (default: 30)
#   --dry-run               Show what would be deleted (no changes)
#   --auto                  Skip confirmations (use with caution!)
#   --keep-merged <days>    Keep merged branches for N days (default: 7)
#   --archive-unmerged      Create tags for unmerged branches before delete
#   --branches <pattern>    Only process branches matching pattern

# Safety features:
# - Never delete main or develop
# - Confirm before deleting unmerged branches
# - Create archive tags before deletion
# - Log all deletions
# - Dry-run mode by default for first use
```

**Key Functions:**
1. `delete_merged_branches()` - Remove branches merged to develop/main
2. `archive_branch()` - Create tag `archive/<branch-name>` before deletion
3. `delete_stale_branches()` - Remove inactive branches (with confirmation)
4. `log_cleanup()` - Record deletions in `.git/cleanup-log.txt`
5. `confirm_deletion()` - Interactive confirmation prompt

**Cleanup Strategy:**
1. **Auto-delete (no confirmation):**
   - Merged feature/fix branches older than 7 days
   - Merged claude/* branches older than 30 days

2. **Confirm before delete:**
   - Unmerged branches older than 60 days
   - Any branches with naming violations

3. **Never delete:**
   - `main`, `develop` (protected)
   - Branches younger than threshold
   - Branches with recent commits

**Logging:**
- Location: `.git/cleanup-log.txt` or `cleanup-{timestamp}.log`
- Format: `{timestamp} | {action} | {branch} | {reason} | {commit-sha}`

---

### 2.3 Agent Branch Preparation Script

**Script:** `scripts/git/prepare-agent-branch.sh`
**Status:** SPEC READY
**Owner:** Codex Agent (Category 15)

**Requirements:**

```bash
#!/bin/bash
# prepare-agent-branch.sh - Prepare branch for AI agent work

# Features:
# 1. Validate session ID format
# 2. Create properly named agent branch
# 3. Ensure branch is up-to-date with base
# 4. Verify push permissions
# 5. Configure branch metadata

# Usage:
#   ./prepare-agent-branch.sh <task-description> <session-id> [base-branch]
#
# Arguments:
#   task-description    Brief task description (lowercase, hyphens)
#   session-id          Agent session ID (24-32 alphanumeric chars)
#   base-branch         Base branch (default: develop)
#
# Examples:
#   ./prepare-agent-branch.sh "setup-ci" "01K6xLndeu5hU8pH3L6aWxn8"
#   ./prepare-agent-branch.sh "fix-auth" "01M9nP2Q3R4S5T6U7V8W9X0Y" "main"

# Outputs:
# - Creates branch: claude/<task>-<session-id>
# - Sets upstream tracking
# - Prints branch name for agent to use
# - Returns 0 on success, 1 on error
```

**Key Functions:**
1. `validate_session_id()` - Ensure session ID matches pattern
2. `sanitize_task_name()` - Convert task to valid branch name
3. `create_agent_branch()` - Create and checkout branch
4. `verify_push_access()` - Test push permissions
5. `set_branch_metadata()` - Configure branch description

**Validations:**
- Session ID: 24-32 alphanumeric characters
- Task name: lowercase, hyphens only, 3-50 chars
- Base branch exists and is up-to-date
- No existing branch with same name

**Error Handling:**
- Invalid session ID → exit 1, print error
- Invalid task name → sanitize and warn
- Base branch not found → exit 1, print error
- Branch already exists → exit 1, suggest new name

---

## Phase 3: CI/CD Pipeline Foundation (Week 2)

### 3.1 Repository Validation Workflow

**File:** `.github/workflows/validate-repo.yml`
**Status:** SPEC READY
**Owner:** Codex Agent (Category 15)

**Trigger Conditions:**
- Push to any branch
- Pull request to `develop` or `main`
- Manual workflow dispatch

**Jobs:**

#### Job 1: Validate Branch Name
```yaml
validate-branch:
  runs-on: ubuntu-latest
  steps:
    - name: Check branch naming convention
      run: |
        # Validate branch name against STANDARD-GIT-BRANCH-POLICY.md
        # Fail if branch name is invalid
        # Skip for main/develop
```

#### Job 2: Validate Knowledge Structure
```yaml
validate-knowledge:
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Run knowledge validation
      run: |
        # Call validation script from Category 22
        # ./scripts/validate-knowledge-structure.sh
        # Check for required directories and file formats
```

#### Job 3: Run Tests (if applicable)
```yaml
test:
  runs-on: ubuntu-latest
  steps:
    - name: Run tests
      run: |
        # If package.json exists: npm test
        # If pytest.ini exists: pytest
        # If Makefile has test target: make test
        # Otherwise: skip
```

#### Job 4: Lint and Format Check
```yaml
lint:
  runs-on: ubuntu-latest
  steps:
    - name: Run linters
      run: |
        # Markdown: markdownlint
        # Shell scripts: shellcheck
        # JSON: jsonlint
        # YAML: yamllint
```

**Success Criteria:**
- All jobs pass → Green check, can merge
- Any job fails → Red X, cannot merge

**Notification:**
- Post status to PR
- Comment with specific failures
- Link to workflow logs

---

### 3.2 Knowledge Update Workflow

**File:** `.github/workflows/knowledge-update.yml`
**Status:** SPEC READY
**Owner:** Codex Agent (Category 15)

**Trigger:** Push to `develop` or `main`

**Jobs:**

#### Job 1: Generate Index
```yaml
generate-index:
  runs-on: ubuntu-latest
  steps:
    - name: Create knowledge index
      run: |
        # Generate knowledge/INDEX.md
        # List all standards, reports, tasks
        # Update timestamps
```

#### Job 2: Update Metrics
```yaml
update-metrics:
  runs-on: ubuntu-latest
  steps:
    - name: Calculate repository metrics
      run: |
        # Branch count
        # Open PRs
        # Knowledge base size
        # Last update timestamp
```

#### Job 3: Notify Team
```yaml
notify:
  runs-on: ubuntu-latest
  steps:
    - name: Post update notification
      run: |
        # Send notification (Slack, email, etc.)
        # Include summary of changes
```

---

### 3.3 Branch Cleanup Workflow

**File:** `.github/workflows/branch-cleanup.yml`
**Status:** SPEC READY
**Owner:** Codex Agent (Category 15)

**Trigger:**
- Schedule: Weekly (Sunday 00:00 UTC)
- Manual workflow dispatch

**Jobs:**

#### Job 1: Audit Branches
```yaml
audit:
  runs-on: ubuntu-latest
  steps:
    - name: Run branch audit
      run: |
        ./scripts/git/branch-audit.sh --output markdown > audit-report.md

    - name: Upload audit report
      uses: actions/upload-artifact@v3
      with:
        name: branch-audit-report
        path: audit-report.md
```

#### Job 2: Cleanup Merged Branches
```yaml
cleanup:
  runs-on: ubuntu-latest
  steps:
    - name: Delete merged branches
      run: |
        ./scripts/git/branch-cleanup.sh --dry-run=false --auto --keep-merged 7
```

#### Job 3: Report Stale Branches
```yaml
report-stale:
  runs-on: ubuntu-latest
  steps:
    - name: Create issue for stale branches
      run: |
        # Create GitHub issue listing stale branches
        # Assign to repo admin
        # Request manual review
```

---

### 3.4 Repository Priority for CI/CD

**Phase 1 (Week 2) - Core Repositories:**
1. ✅ `jarvis-00-central-nexus` - Central coordination
2. `jarvis-22-knowledge-validator` - Knowledge validation
3. `jarvis-26-gitlab-manager` - DevOps (this repo)

**Phase 2 (Week 3) - Category Repositories:**
4. `jarvis-01-*` through `jarvis-26-*` - All category repos
5. Focus on repositories with:
   - Active development
   - Multiple agents
   - Knowledge bases

**Phase 3 (Week 4+) - Shared Libraries:**
6. `jarvis-shared-*` - Shared code libraries
7. Legacy/archived repos (lower priority)

**Rollout Strategy:**
1. Test workflows in `jarvis-26-gitlab-manager` (this repo)
2. Refine based on initial results
3. Deploy to `jarvis-00-central-nexus`
4. Gradual rollout to category repos
5. Monitor and iterate

---

## Phase 4: GitOps Integration (Week 3+)

### 4.1 ArgoCD Setup (Future)

**Status:** PLANNED (Post-Wave 3)
**Priority:** Medium (P1)

**Objectives:**
- Deploy ArgoCD to Kubernetes cluster
- Connect to Git repositories
- Automate deployments from `main` branch
- Implement GitOps workflows

**Prerequisites:**
- Kubernetes cluster available
- Repositories configured with proper structure
- CI/CD pipelines tested and stable

**Deliverables:**
- ArgoCD installation guide
- Application manifests
- Sync policies
- Rollback procedures

**Timeline:** 2 weeks after Wave 3 completion

---

### 4.2 Environment Management

**Status:** PLANNED
**Priority:** Medium (P1)

**Environments:**
1. **Development** - Auto-deploy from `develop` branch
2. **Staging** - Auto-deploy from `release/*` branches
3. **Production** - Auto-deploy from `main` branch (with approval)

**GitOps Workflow:**
```
feature/* → develop → [CI/CD] → Dev Environment
develop → release/* → [CI/CD] → Staging Environment
release/* → main → [Manual Approval] → [CI/CD] → Production
```

---

## Phase 5: Monitoring and Compliance (Ongoing)

### 5.1 Branch Health Metrics

**Metrics to Track:**
1. **Branch Count by Type**
   - Total branches
   - Active vs. stale
   - By type (feature, claude, etc.)

2. **Merge Velocity**
   - Average time from branch creation to merge
   - PR review time
   - Time in CI/CD

3. **Compliance Rate**
   - % branches following naming convention
   - % PRs with required approvals
   - % passing CI checks

4. **Cleanup Effectiveness**
   - Branches deleted per week
   - Stale branch reduction rate
   - Archive tag usage

**Dashboard:** Create Grafana dashboard or GitHub wiki page

---

### 5.2 Regular Audits

**Weekly Tasks:**
- [ ] Run branch audit script
- [ ] Review stale branches (manual approval for deletion)
- [ ] Check protection rules on all repos
- [ ] Verify CI/CD pipeline health

**Monthly Tasks:**
- [ ] Generate compliance report
- [ ] Review and update branch policy if needed
- [ ] Audit agent branch usage patterns
- [ ] Update documentation based on learnings

**Quarterly Tasks:**
- [ ] Comprehensive repository audit
- [ ] Policy effectiveness review
- [ ] Team training on Git best practices
- [ ] Tool and process improvements

---

## Success Criteria

### Week 1 (Standards)
- ✅ Branch policy document published
- [ ] All team members/agents trained
- [ ] Script specifications completed

### Week 2 (Automation)
- [ ] All three scripts implemented and tested
- [ ] CI/CD workflows deployed to 3 core repos
- [ ] Initial branch cleanup completed

### Week 3 (Rollout)
- [ ] CI/CD on all active category repos
- [ ] Branch protection rules applied everywhere
- [ ] Automated cleanup running weekly

### Ongoing
- [ ] >95% branch naming compliance
- [ ] <10 stale branches per repo
- [ ] <24h average PR merge time
- [ ] Zero unprotected main/develop branches

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Accidental deletion of important branches | High | Archive tags, dry-run mode, confirmation prompts |
| CI/CD pipeline failures blocking work | High | Allow admin override, fast rollback procedure |
| Agent confusion with new policies | Medium | Clear documentation, error messages, training |
| Protection rules too strict | Medium | Gradual rollout, admin override capability |
| Script bugs causing data loss | High | Extensive testing, dry-run default, logging |

---

## Dependencies

### Internal
- **Category 15 (Codex)** - Script implementation
- **Category 22 (Knowledge Validator)** - Validation script integration
- **Category 00 (Central Nexus)** - Coordination and rollout

### External
- GitHub/GitLab API access
- CI/CD runner availability
- Repository admin permissions

---

## Budget and Resources

### Time Investment
- Agent 26 (this): 40 hours (planning, oversight, documentation)
- Codex (Category 15): 60 hours (script development, CI/CD workflows)
- Perplexity: 10 hours (GitHub UI configuration)
- Testing & iteration: 30 hours

**Total:** ~140 hours over 3 weeks

### Infrastructure
- GitHub Actions minutes: ~500 min/week (within free tier for public repos)
- Storage: Negligible (<1 GB for logs and artifacts)

---

## Next Actions

### Immediate (This Week)
1. ✅ Publish STANDARD-GIT-BRANCH-POLICY.md
2. ✅ Complete this implementation plan
3. 🔲 Create pending task for Codex (script implementation)
4. 🔲 Create pending task for Perplexity (GitHub config)

### Short Term (Week 2)
5. 🔲 Review and approve script implementations
6. 🔲 Test scripts on this repository
7. 🔲 Deploy CI/CD workflows to core repos

### Medium Term (Week 3)
8. 🔲 Rollout to all category repos
9. 🔲 Train agents on new workflows
10. 🔲 Begin regular audit cadence

---

## Communication Plan

### Announcements
1. **Week 1:** Email to all agents about new branch policy
2. **Week 2:** Demo session for script usage
3. **Week 3:** Rollout notification with timeline

### Documentation
- Wiki page with quick start guide
- Video tutorial for common workflows
- FAQ document

### Support
- Create #devops-gitops Slack channel
- Office hours: Wednesdays 2-3 PM
- Agent 26 as primary contact

---

## Appendix

### A. Related Documents
- `knowledge/standards/STANDARD-GIT-BRANCH-POLICY.md`
- `knowledge/tasks/PENDING-TASK-26-GIT-SCRIPTS-AND-CI.md` (to be created)

### B. Script Locations
- `scripts/git/branch-audit.sh`
- `scripts/git/branch-cleanup.sh`
- `scripts/git/prepare-agent-branch.sh`

### C. Workflow Locations
- `.github/workflows/validate-repo.yml`
- `.github/workflows/knowledge-update.yml`
- `.github/workflows/branch-cleanup.yml`

---

**Document Owner:** Agent 26 – DevOps & GitOps Architect
**Review Cycle:** Bi-weekly
**Next Review:** 2025-11-30
**Status:** ACTIVE - Implementation in progress
