---
name: Monthly Claude API Check
about: Verify Claude API compatibility (run 1st of each month)
title: 'Monthly API Check - [MONTH YEAR]'
labels: maintenance, api
assignees: ''
---

## Monthly Claude API Compatibility Check

**Date:** [YYYY-MM-DD]
**Reviewer:** [Your Name]

---

### 1. Check API Version

- [ ] Visit https://platform.claude.com/docs/en/api/versioning
- [ ] Current version in docs: `________________`
- [ ] Our version (`claude_service.dart` line 38): `anthropic-version: 2023-06-01`
- [ ] **Status:** ✅ Match / ❌ Needs Update

---

### 2. Check Model Names

- [ ] Visit https://platform.claude.com/docs/en/api/messages
- [ ] Sonnet 4.5 name in docs: `________________`
- [ ] Our model (`claude_service.dart` line 10): `claude-sonnet-4-5`
- [ ] **Status:** ✅ Match / ❌ Needs Update

---

### 3. Check for Deprecation Notices

- [ ] Visit https://platform.claude.com/docs/en/api/changelog
- [ ] Any deprecation warnings for our model? ⚠️ Yes / ✅ No
- [ ] If yes, migration deadline: `________________`
- [ ] Replacement model: `________________`

---

### 4. Functional Testing

- [ ] Run app, go to Settings
- [ ] Click "Test Connection"
- [ ] **Result:** ✅ Success / ❌ Failed (error: `________`)
- [ ] Go to Brain Dump
- [ ] Enter: "test api check and verify model works"
- [ ] Submit
- [ ] **Result:** ✅ Tasks extracted / ❌ Failed (error: `________`)

---

### 5. Actions Required

**If everything passed:**
- [ ] Update `docs/CLAUDE_API_TRACKING.md` - set "Last Verified" date
- [ ] Close this issue
- [ ] Create next month's issue

**If updates needed:**
- [ ] Create fix branch: `fix/claude-api-update-YYYY-MM`
- [ ] Update model/version in code
- [ ] Test thoroughly (Brain Dump + Test Connection)
- [ ] Update `docs/CLAUDE_API_TRACKING.md`
- [ ] Bump version in `pubspec.yaml`
- [ ] Commit with message: `fix: Update Claude API to [model/version]`
- [ ] Build and test APK
- [ ] Merge to main
- [ ] Close this issue

---

### 6. Documentation

**Files to update if changes made:**
- [ ] `docs/CLAUDE_API_TRACKING.md` (version history table)
- [ ] `CHANGELOG.md` (user-facing changes)
- [ ] `pubspec.yaml` (version bump)

---

## Notes

[Add any additional observations, warnings, or context here]

---

**Checklist Summary:**
- [ ] API version verified
- [ ] Model names verified
- [ ] No deprecations found
- [ ] Brain Dump works
- [ ] Test Connection works
- [ ] Documentation updated
- [ ] Next month's issue created
