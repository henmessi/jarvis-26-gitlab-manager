# STANDARD-GIT-BRANCH-POLICY.md

**Version:** 1.0
**Owner:** Agent 26 – DevOps & GitOps Architect
**Last Updated:** 2025-11-16
**Status:** Active

## Overview

This document defines the Git branching strategy and policies for AI-agent managed repositories within the Jarvis ecosystem. The policy is designed to support multi-agent collaboration, maintain code quality, and enable safe GitOps workflows.

---

## Branch Types and Roles

### 1. **main** (Protected)

**Purpose:** Production-ready code only

**Rules:**
- Always stable and deployable
- Protected branch - no direct commits
- Requires pull request with approvals
- All tests must pass before merge
- Automated deployments trigger from this branch

**Merge Sources:**
- `develop` branch only (via release PR)
- Hotfix branches in emergencies

**Protection Settings:**
- Require pull request reviews (minimum 1 approval)
- Require status checks to pass
- Require branches to be up to date before merging
- Restrict direct pushes (admin override only)
- Require linear history (optional, recommended)

---

### 2. **develop** (Protected)

**Purpose:** Integration branch for ongoing development

**Rules:**
- Latest development-ready features
- Protected branch - no direct commits
- Requires pull request for merge
- Must pass CI checks
- Source for creating feature branches

**Merge Sources:**
- Feature branches (`feature/*`)
- Agent branches (`claude/*`, `agent/*`)
- Fix branches (`fix/*`, `hotfix/*`)

**Protection Settings:**
- Require pull request reviews (minimum 1 approval)
- Require status checks to pass
- Allow force pushes by admins only
- Restrict deletions

---

### 3. **feature/** (Unprotected)

**Pattern:** `feature/<description>` or `feature/<ticket-id>-<description>`

**Purpose:** New features or enhancements

**Rules:**
- Branch from `develop`
- Merge back to `develop` via PR
- Delete after successful merge
- Naming: lowercase, hyphens only, descriptive

**Examples:**
```
feature/user-authentication
feature/JARVIS-123-add-logging
feature/multi-agent-coordination
```

**Lifecycle:**
1. Create from `develop`
2. Implement feature
3. Open PR to `develop`
4. Pass CI/CD checks
5. Get approval
6. Merge and delete

---

### 4. **fix/** and **hotfix/** (Unprotected)

**Pattern:**
- `fix/<description>` - Regular bug fixes
- `hotfix/<description>` - Critical production fixes

**Purpose:** Bug fixes and patches

**Rules:**
- `fix/*` branches from `develop`, merges to `develop`
- `hotfix/*` branches from `main`, merges to both `main` AND `develop`
- Delete after successful merge

**Examples:**
```
fix/validation-error
hotfix/security-patch-critical
```

---

### 5. **claude/** (AI Agent Branches - Unprotected)

**Pattern:** `claude/<task-description>-<session-id>`

**Purpose:** AI agent (Claude) work branches

**Rules:**
- Created automatically by AI agents
- Branch from `develop` (or current working branch)
- Merge to `develop` via PR
- **Must** include session ID suffix for traceability
- Auto-delete after 30 days if merged
- Auto-archive after 60 days if unmerged

**Session ID Format:**
- Alphanumeric string (e.g., `01K6xLndeu5hU8pH3L6aWxn8`)
- Ensures uniqueness and traceability

**Examples:**
```
claude/devops-gitops-setup-01K6xLndeu5hU8pH3L6aWxn8
claude/implement-validation-01MduiJ2G8UuAQ5uM8ESxGRQ
claude/refactor-api-client-01N3kLmP9R7tYz4wQ2XvBnJh
```

**Agent Guidelines:**
- Always push to assigned `claude/*` branch
- Never push to branches without matching session ID
- Commit frequently with clear messages
- Open PR when task is complete
- Reference issue/task number in PR description

---

### 6. **agent/** (Other AI Agent Branches - Unprotected)

**Pattern:** `agent/<agent-name>/<task>-<session-id>`

**Purpose:** Non-Claude AI agent work branches

**Rules:**
- Similar to `claude/*` branches
- Include agent identifier in path
- Follow same lifecycle as `claude/*`

**Examples:**
```
agent/copilot/add-tests-abc123
agent/gpt4/documentation-xyz789
```

---

### 7. **release/** (Short-lived, Unprotected)

**Pattern:** `release/v<version>`

**Purpose:** Release preparation

**Rules:**
- Branch from `develop`
- Only bug fixes and release prep
- Merge to both `main` and `develop`
- Delete after release complete
- Tag `main` after merge

**Examples:**
```
release/v1.0.0
release/v2.1.3
```

**Workflow:**
1. Create from `develop` when ready for release
2. Version bumps, changelog updates
3. Final bug fixes only
4. Merge to `main` (triggers deployment)
5. Tag release on `main`
6. Merge back to `develop`
7. Delete branch

---

## Branch Naming Conventions

### Rules
1. **Lowercase only:** All branch names must be lowercase
2. **Hyphens for spaces:** Use hyphens (`-`) to separate words
3. **No special characters:** Except hyphens and forward slashes
4. **Descriptive:** Name should indicate purpose
5. **Session IDs:** Required for AI agent branches

### Valid Examples
```
feature/add-user-auth
fix/null-pointer-exception
claude/setup-ci-01K6xLndeu5hU8pH3L6aWxn8
hotfix/security-cve-2025-1234
release/v1.2.0
```

### Invalid Examples
```
Feature/AddUserAuth          # No uppercase
fix_null_pointer             # No underscores
claude/setup-ci              # Missing session ID
feature/add user auth        # No spaces
fix/bug#123                  # No special chars
```

---

## Merge Policies

### Pull Request Requirements

**All PRs must:**
1. Have a descriptive title
2. Include a detailed description
3. Reference related issues/tasks
4. Pass all CI/CD checks
5. Have no merge conflicts
6. Be up to date with target branch

**For `develop` merges:**
- 1+ approval required
- All CI checks must pass
- Squash merge recommended for cleanup

**For `main` merges:**
- 2+ approvals required (or 1 if team < 3)
- All CI checks must pass
- Merge commit required (preserve history)
- Release notes required

### Commit Message Standards

Follow Conventional Commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

**Examples:**
```
feat(auth): add OAuth2 authentication flow

Implements OAuth2 login with Google and GitHub providers.
Includes token refresh logic and session management.

Closes #123

---

fix(api): handle null response in user endpoint

Adds null check before accessing user.profile to prevent
NullPointerException when profile is not yet created.

Refs #456
```

---

## AI Agent Specific Policies

### Branch Creation
- **Automatic:** Agents create branches with session ID suffix
- **Validation:** System validates branch name matches session ID
- **Rejection:** Pushes to non-matching branches return 403 error

### Push Policy
- **Must use:** `git push -u origin <branch-name>`
- **Retry logic:** Up to 4 retries with exponential backoff (2s, 4s, 8s, 16s)
- **Network errors:** Auto-retry, other errors fail immediately

### Fetch/Pull Policy
- **Prefer specific:** `git fetch origin <branch-name>`
- **Retry logic:** Same as push (4 retries, exponential backoff)
- **Update frequency:** Fetch before starting work, before opening PR

### Branch Scope
- **Single task:** One branch per task/session
- **No cross-contamination:** Don't mix unrelated changes
- **Clean commits:** Commit logical units of work

### PR Creation
- **Auto-generate:** Use git log and diff to create PR description
- **Include:** Summary, test plan, related issues
- **Format:** Markdown with clear sections

---

## Branch Cleanup Policies

### Automatic Deletion
- **Merged branches:** Delete immediately after merge (except `main`, `develop`)
- **Stale feature branches:** Delete after 30 days of inactivity
- **Stale agent branches:** Delete after 30 days if merged, archive after 60 days if unmerged

### Manual Cleanup
- **Weekly audit:** Review all active branches
- **Tag before delete:** Archive important unmerged work
- **Document:** Keep record of deleted branches

### Archive Process
1. Create tag: `archive/<branch-name>`
2. Push tag to remote
3. Delete branch
4. Document in cleanup log

---

## Protection Rules Summary

| Branch | Direct Push | Force Push | Delete | PR Required | Reviews | CI Required |
|--------|-------------|------------|--------|-------------|---------|-------------|
| `main` | ❌ | ❌ | ❌ | ✅ | 2 | ✅ |
| `develop` | ❌ | Admin only | ❌ | ✅ | 1 | ✅ |
| `feature/*` | ✅ | ✅ | ✅ | For merge | - | ✅ |
| `fix/*` | ✅ | ✅ | ✅ | For merge | - | ✅ |
| `claude/*` | Agent only | ❌ | Auto | For merge | 1 | ✅ |
| `agent/*` | Agent only | ❌ | Auto | For merge | 1 | ✅ |
| `release/*` | ✅ | ❌ | ✅ | For merge | 2 | ✅ |

---

## Emergency Procedures

### Hotfix Process
1. Create `hotfix/*` from `main`
2. Implement critical fix
3. Test thoroughly
4. Open PR to `main` (expedited review)
5. Merge to `main`
6. Tag release
7. Cherry-pick or merge to `develop`
8. Delete hotfix branch

### Rollback Process
1. Identify last good commit on `main`
2. Create `hotfix/rollback-<issue>` from that commit
3. Open PR to `main`
4. Fast-track approval
5. Merge and deploy

### Force Push (Admin Only)
- **Never on `main`**
- **Rarely on `develop`** (team notification required)
- **Allowed on feature branches** (with caution)
- **Document reason** in team chat

---

## Migration and Adoption

### For Existing Repositories
1. Audit current branches
2. Rename non-compliant branches
3. Apply protection rules
4. Archive stale branches
5. Document legacy exceptions

### For New Repositories
1. Initialize with `main` branch
2. Create `develop` from `main`
3. Apply protection rules immediately
4. Configure CI/CD before first feature

---

## Monitoring and Compliance

### Weekly Checks
- [ ] All protected branches have correct settings
- [ ] No orphaned branches older than 30 days
- [ ] All agent branches follow naming convention
- [ ] All PRs have required approvals

### Monthly Audit
- [ ] Review and cleanup stale branches
- [ ] Update protection rules if needed
- [ ] Review CI/CD pipeline effectiveness
- [ ] Document any policy violations and resolutions

---

## References

- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)
- [GitOps Principles](https://opengitops.dev/)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-16 | Agent 26 | Initial version |

---

**Approved by:** Agent 26 – DevOps & GitOps Architect
**Next Review:** 2025-12-16
