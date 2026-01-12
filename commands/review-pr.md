# Review Pull Request

Review pull request: $ARGUMENTS

## Setup

1. **Parse the PR reference** - could be:
   - Just a number (e.g., `123`)
   - A full URL (e.g., `https://dev.azure.com/org/project/_git/repo/pullrequest/123`)
   - GitHub format (e.g., `owner/repo#123`)

2. **Get PR details** using appropriate CLI:
   - Azure DevOps: `az repos pr show --id <number>`
   - GitHub: `gh pr view <number>`

3. **Checkout the PR branch**:
   ```bash
   git fetch origin
   git checkout <branch-name>
   ```

4. **View what changed from the base branch**:
   ```bash
   git log --oneline main..HEAD
   git diff main...HEAD --stat
   ```

## Review Checklist

### Code Quality
- [ ] Code is readable and well-structured
- [ ] No obvious bugs or logic errors
- [ ] No commented-out code left behind
- [ ] Consistent naming conventions
- [ ] No unnecessary complexity

### Security
- [ ] No secrets, API keys, or credentials committed
- [ ] No hardcoded passwords or tokens
- [ ] Input validation where needed
- [ ] No SQL injection or XSS vulnerabilities

### Documentation
- [ ] README updated if needed
- [ ] Code comments where logic is non-obvious
- [ ] API documentation updated if applicable
- [ ] CHANGELOG updated if project uses one

### Testing
- [ ] Tests included for new functionality
- [ ] Existing tests still pass
- [ ] Edge cases considered

### Project Standards
- [ ] Follows project coding style
- [ ] Consistent with existing patterns in codebase
- [ ] No unrelated changes bundled in
- [ ] Commit messages are clear and descriptive

### Sensitive Data Check
```bash
# Search for potential secrets
grep -rE "(password|secret|api.?key|token|credential)" --include="*.{json,yml,yaml,env,config}" .
```

## Review Process

1. **Read the PR description** - understand the intent
2. **Review the diff** - examine each changed file
3. **Run the build/tests** if applicable
4. **Check for any existing PR comments** that need addressing
5. **Compile findings** into categories:
   - **Blockers** - must fix before merge
   - **Suggestions** - recommended improvements
   - **Nits** - minor style/preference items
   - **Questions** - clarifications needed

## Post Review

Post your review comment to the PR via browser or CLI:
- Azure DevOps: Use browser (no direct CLI comment support)
- GitHub: `gh pr review <number> --comment --body "..."`
