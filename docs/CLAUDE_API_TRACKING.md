# Claude API Model & Version Tracking

**Purpose:** Track Claude API compatibility to prevent "works on my machine" bugs

**Last Updated:** 2025-12-22
**Last Verified:** 2025-12-22

---

## Current Configuration (VERIFIED WORKING)

### API Version
```
anthropic-version: 2023-06-01
```
- **Status:** ✅ Stable
- **Source:** https://platform.claude.com/docs/en/api/versioning
- **Last Verified:** 2025-12-22

### Model Names

#### Brain Dump (ClaudeService)
```dart
_model = 'claude-sonnet-4-5';
```
- **Status:** ✅ Working
- **Purpose:** Task extraction from brain dumps
- **Cost:** ~$0.01 per brain dump (estimate)

#### Test Connection (SettingsService)
```dart
'model': 'claude-sonnet-4-5'
```
- **Status:** ✅ Working
- **Purpose:** API key validation

---

## Available Models (as of 2025-12-22)

### Claude Sonnet 4.5
- **Name:** `claude-sonnet-4-5`
- **Dated Version:** `claude-sonnet-4-5-20250929`
- **Best For:** Real-world agents, coding, task extraction
- **Status:** ✅ Current production model

### Claude Opus 4.5
- **Name:** `claude-opus-4-5`
- **Dated Version:** `claude-opus-4-5-20251101`
- **Best For:** Maximum intelligence + performance
- **Cost:** Higher than Sonnet
- **Status:** Available (not currently used)

### Deprecated Models ❌
- `claude-3-5-sonnet-20241022` - Replaced by Sonnet 4.5
- `claude-sonnet-4-5` (undated) - Use dated version for stability

---

## Monitoring Workflow

### Monthly Check (1st of each month)
1. **Visit:** https://platform.claude.com/docs/en/api/messages
2. **Check:**
   - Latest `anthropic-version` header value
   - Current model names for Sonnet/Opus
   - Deprecation notices
3. **Update:** This document + code if needed
4. **Test:** Run Brain Dump after any changes

### When to Update Code

**Update IMMEDIATELY if:**
- Current model returns 400/404 errors
- Deprecation notice posted for our model
- New API version required for security

**Consider updating if:**
- New model offers better performance
- Cost reduction available
- New features needed

**DO NOT update if:**
- "Latest" model is experimental/beta
- No clear benefit over current stable model
- Breaking changes without migration guide

---

## Testing Checklist

After any API configuration change:

- [ ] Test Connection works (Settings screen)
- [ ] Brain Dump extracts tasks correctly
- [ ] No 400/401/404 errors
- [ ] Cost tracking still works (API Usage screen)
- [ ] Update version in pubspec.yaml
- [ ] Document change in CHANGELOG.md

---

## Common Issues & Fixes

### 400 Bad Request
**Causes:**
- Invalid model name
- Wrong API version header
- Malformed request body

**Fix:**
1. Check model name against docs
2. Verify `anthropic-version` header
3. Test with minimal request

### 404 Not Found
**Cause:** Model deprecated/removed

**Fix:**
1. Check docs for replacement model
2. Update `_model` constant
3. Test thoroughly

### 429 Rate Limited
**Cause:** Too many requests (proves key is valid!)

**Fix:**
- Add exponential backoff
- Show user-friendly message
- Key is valid, just throttled

---

## Code Locations

### Model Configuration
- **File:** `lib/services/claude_service.dart`
- **Line:** ~10 (`_model` constant)
- **Test File:** `lib/services/settings_service.dart` (~26)

### API Version
- **Brain Dump:** `lib/services/claude_service.dart` (~38)
- **Test Connection:** `lib/services/settings_service.dart` (~23)

---

## Documentation Links

- **API Docs:** https://platform.claude.com/docs/en/api/messages
- **Versioning:** https://platform.claude.com/docs/en/api/versioning
- **Model Names:** https://platform.claude.com/docs/en/api/messages (Models section)
- **Changelog:** https://platform.claude.com/docs/en/api/changelog (check for deprecations)

---

## Version History

| Date | Change | Reason |
|------|--------|--------|
| 2025-12-22 | Set `claude-sonnet-4-5` | Fixed 400 error (was using old 3.5) |
| 2025-12-22 | Set API version `2023-06-01` | Fixed 400 error (was using invalid 2024-10-22) |

---

**Next Review:** 2026-01-22 (monthly check)
**Assigned:** Development team
