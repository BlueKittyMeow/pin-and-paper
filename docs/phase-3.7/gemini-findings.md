# Gemini Findings - Phase 3.7 Package Research

**Phase:** 3.7 - Natural Language Date Parsing
**Plan Document:** [phase-3.7-plan-v2.md](./phase-3.7-plan-v2.md)
**Review Date:** 2026-01-20
**Reviewer:** Gemini
**Review Type:** Pre-Implementation Research (Package Evaluation)
**Status:** ⏳ Pending Research

---

## Instructions

This document is for **Gemini** to research and evaluate date parsing packages for Phase 3.7.

**🚫 NEVER SIMULATE OTHER AGENTS' RESPONSES 🚫**
**DO NOT write feedback on behalf of Codex, Claude, or anyone else!**
**ONLY document YOUR OWN findings in this document.**

---

## Research Focus Areas

### 1. Package Compatibility & Build Testing

**Goal:** Evaluate packages from a build and compatibility perspective.

**For each package, verify:**
1. **Build compatibility:**
   - Does it build successfully with our Flutter version?
   - Any compilation errors or warnings?
   - Dependencies compatible with our pubspec.yaml?

2. **Platform support:**
   - Android support
   - iOS support (if we test on iOS later)
   - Web support (future consideration)

3. **Dart/Flutter version requirements:**
   - Minimum Dart SDK version
   - Compatible with our Flutter 3.24+?
   - Any breaking changes we need to handle?

4. **Testing:**
   - How well tested is the package?
   - Can we run its tests locally?
   - Test coverage of natural language features?

---

## Methodology

**Testing approach:**

```bash
# For each package being evaluated:

cd pin_and_paper

# 1. Add package to pubspec.yaml (create test branch)
# In pubspec.yaml:
dependencies:
  [package_name]: ^[version]

# 2. Get dependencies
flutter pub get

# 3. Check for conflicts
# Look for version resolution issues

# 4. Try basic import
# Create test file:
import 'package:[package_name]/[package_name].dart';
# Verify it compiles

# 5. Run analyzer
flutter analyze

# 6. Try basic usage example
# Create simple test to parse "tomorrow"
# Verify it works

# 7. Check size impact
flutter build apk --analyze-size
# How much does it add to app size?
```

---

## Required Features (from phase-3.7-plan-v2.md)

**Must parse:**
1. Relative dates: today, tomorrow, yesterday, tonight
2. Days of week: Monday, Tuesday, next Monday, this Friday
3. Relative offsets: in 3 days, in 2 weeks, in 1 month
4. Absolute dates: Jan 15, March 3rd, 2026-01-20, 1/20/2026
5. Time of day: 3pm, 9:30am, morning, afternoon, evening, tonight
6. Combined: tomorrow at 3pm, next Tuesday morning, Jan 15 at 2pm

**Critical for testing:**
- We need to integrate "Today Window" logic (night owl mode)
- Must work offline (no API calls)
- Must work across timezones

---

## Findings

### Package 1: [Name]

**Package:** `[package_name]` version `^[version]`
**Pub.dev:** [URL]

**Build Testing:**
- [ ] `flutter pub get` successful
- [ ] `flutter analyze` clean
- [ ] No dependency conflicts
- [ ] Compiles on Android

**Compatibility:**
- **Dart SDK:** [minimum version required]
- **Flutter:** [compatibility info]
- **Platforms:** Android ✅ / iOS ✅ / Web ✅

**Size Impact:**
- Added to APK size: [X KB/MB]
- Dependency count: [N packages]

**Testing:**
- Package has tests: [Yes/No]
- Tests cover natural language: [Yes/No/Partial]
- All package tests pass: [Yes/No]

**Basic Usage Test:**
```dart
// Simple test: can it parse "tomorrow"?
[Code example]
// Result: [Success/Failure/Notes]
```

**Issues Found:**
- [List any build issues, warnings, errors]

**Recommendation:**
- [Recommend / Don't recommend / Need more investigation]

---

### Package 2: [Name]

[Repeat format above]

---

## Compatibility Matrix

| Package | Flutter 3.24+ | Android | Build Clean | Size Impact | Recommendation |
|---------|---------------|---------|-------------|-------------|----------------|
| [Name]  | ✅            | ✅      | ✅          | +X KB       | [Yes/No/Maybe] |

---

## Performance Testing (CRITICAL for Real-Time Parsing)

**Goal:** Verify parsing is fast enough for real-time UI (<1ms per parse)

### Test 1: Single Parse Speed

```dart
// Measure: Parse a single date phrase
final stopwatch = Stopwatch()..start();
final result = parser.parse("tomorrow at 3pm");
stopwatch.stop();

// Expected: <1ms (ideally <0.5ms)
// Result: [X ms/μs]
```

**Test phrases:**
- "tomorrow" (simple relative)
- "next Tuesday" (day of week)
- "tomorrow at 3pm" (combined date + time)
- "in 3 days" (relative offset)
- "Jan 15" (absolute date)
- "May need to call dentist" (false positive test - should be fast to reject)

### Test 2: Rapid Sequential Parsing (Typing Simulation)

```dart
// Simulate user typing rapidly
final phrases = [
  "t",
  "to",
  "tom",
  "tomo",
  "tomor",
  "tomorr",
  "tomorro",
  "tomorrow",
];

final stopwatch = Stopwatch()..start();
for (final phrase in phrases) {
  parser.parse(phrase);
}
stopwatch.stop();

// Expected: <10ms total (8 parses)
// Result: [X ms]
```

### Test 3: Debounced Parsing (Real-World)

```dart
// Test with 300ms debouncing (real implementation)
// Type "tomorrow at 3pm" character by character
// Measure actual parse calls (should be 1, not 18)

// Expected: Only 1 parse call after typing stops
// Result: [N parse calls]
```

### Test 4: UI Responsiveness

**Manual testing required:**
1. Open edit task dialog
2. Type rapidly: "Call dentist tomorrow at 3pm"
3. Observe:
   - [ ] No UI jank or stuttering
   - [ ] Highlighting appears smoothly
   - [ ] TextField remains responsive
   - [ ] No dropped keystrokes

**Performance targets:**
- Parse time: <1ms per parse
- UI frame rate: 60 FPS maintained
- No dropped keystrokes
- Debouncing working (only parse after 300ms idle)

---

## Real-Time Parsing Verification

**Test real-time parsing with various scenarios:**

### Scenario 1: Incremental Parsing
```
Type: "C" → No match (too short)
Type: "Ca" → No match
Type: "Cal" → No match
Type: "Call" → No match
Type: "Call " → No match
Type: "Call d" → No match
...
Type: "Call dentist t" → No match yet
Type: "Call dentist to" → No match yet
Type: "Call dentist tom" → Partial match? (check implementation)
Type: "Call dentist tomorrow" → ✅ Match! Highlight appears

Expected: Highlight appears smoothly, no false triggers
```

### Scenario 2: False Positive Check
```
Type: "May need to call"
Expected: No highlight (context-aware parsing working)
```

### Scenario 3: Dismiss and Re-trigger
```
Type: "tomorrow" → Highlight appears
Click "Remove due date" → Highlight removed
Continue typing: "tomorrow at 3pm"
Expected: Re-triggers for "at 3pm" addition
```

---

## Build Impact Analysis

### APK Size Impact

**Measure before/after adding date parsing package:**

```bash
# Before adding package
flutter build apk --analyze-size

# After adding package
flutter build apk --analyze-size

# Compare: How many MB/KB added?
```

**Acceptable:** <500 KB for date parsing library
**Concern if:** >1 MB added

### Dependency Analysis

```bash
# Check dependency tree
flutter pub deps

# Count: How many dependencies does this package pull in?
# Concern if: >5 transitive dependencies
```

---

## Final Recommendation

**Best option from build perspective:** [Package name OR "Custom implementation"]

**Rationale:**
- [Explain compatibility and build considerations]
- [Address any concerns about dependencies or size]
- [Note any platform-specific issues]

**Performance Results:**
- Single parse time: [X ms/μs]
- Rapid parsing (8 calls): [X ms]
- UI responsiveness: [✅ Smooth / ❌ Janky]
- APK size impact: [+X KB]

**Concerns:**
- [List any red flags or blockers]
- [Performance issues?]
- [Build warnings?]

**Cross-check with Codex:**
- [Reference codex-findings.md for API quality assessment]
- [Reference codex-findings.md for context-aware parsing research]
- [Note if our findings agree or differ]

---

## Next Steps

1. [ ] Complete build testing for all candidate packages
2. [ ] Run performance benchmarks (targeting <1ms parse time)
3. [ ] Test real-time parsing with debouncing
4. [ ] Verify UI responsiveness (no jank)
5. [ ] Measure APK size impact
6. [ ] Discuss findings with Codex and Claude
7. [ ] Make final decision on package vs custom vs hybrid
8. [ ] Document any build quirks or gotchas

---

**Notes:**
- Gemini's focus: Build quality, compatibility, performance, size impact, real-time UX
- **CRITICAL:** Must achieve <1ms parse time for real-time typing
- Cross-check with Codex's findings for package selection and context-aware parsing
- Document any warnings or issues for future reference
- Performance is non-negotiable for this phase (Todoist-style real-time parsing)
