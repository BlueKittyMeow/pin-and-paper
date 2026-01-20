# SQLite FTS5 Full-Text Search Analysis

**Created:** 2026-01-11
**Purpose:** Evaluate FTS5 for Phase 3.6B Universal Search
**Context:** Gemini caught that regular indexes won't help `LIKE '%query%'` searches

---

## The Problem

**Gemini's Critical Finding:**
> SQLite indexes on `title` and `notes` will NOT be used for `LIKE '%query%'` searches (wildcards at start). This is a common misconception.

**What this means:**
- My original plan assumed indexes would make search fast
- **They won't!** SQLite can't use B-tree indexes for middle-of-string searches
- Without optimization, searching 1000 tasks might take 200-300ms, missing our <100ms target

---

## Solution Options

### Option 1: Accept Slower Performance (No FTS)
**Approach:** Ship without special optimization, rely on LIKE queries
**Performance:** ~200-300ms for 1000 tasks (unindexed full table scan)
**Pros:**
- Simple - no schema changes
- Works immediately
- Good enough for small datasets (<500 tasks)
**Cons:**
- Misses <100ms target for 1000 tasks
- Doesn't scale well
- Not truly "proper" full-text search

**Verdict:** ❌ Doesn't meet PROJECT_SPEC performance requirement

---

### Option 2: SQLite FTS5 (Full-Text Search)
**Approach:** Create FTS5 virtual table alongside tasks table
**Performance:** ~10-50ms for 1000 tasks (optimized full-text index)
**Complexity:** Medium (add virtual table, sync mechanism, different query syntax)

#### How FTS5 Works

**Virtual Table:**
```sql
-- Migration v7: Create FTS5 virtual table for search
CREATE VIRTUAL TABLE tasks_fts USING fts5(
  id UNINDEXED,        -- Task ID (not searchable, for joining)
  title,               -- Searchable title
  notes,               -- Searchable notes
  tag_names,           -- Searchable tag names (denormalized)
  tokenize='unicode61 remove_diacritics 2'  -- Smart tokenization
);
```

**Sync Mechanism (Keep FTS table current):**
```sql
-- Triggers to keep FTS in sync with tasks table

-- Insert
CREATE TRIGGER tasks_fts_insert AFTER INSERT ON tasks BEGIN
  INSERT INTO tasks_fts(id, title, notes, tag_names)
  VALUES (
    new.id,
    new.title,
    COALESCE(new.notes, ''),
    (SELECT GROUP_CONCAT(tags.name, ' ')
     FROM task_tags
     JOIN tags ON task_tags.tag_id = tags.id
     WHERE task_tags.task_id = new.id)
  );
END;

-- Update
CREATE TRIGGER tasks_fts_update AFTER UPDATE ON tasks BEGIN
  UPDATE tasks_fts
  SET title = new.title,
      notes = COALESCE(new.notes, ''),
      tag_names = (SELECT GROUP_CONCAT(tags.name, ' ')
                   FROM task_tags
                   JOIN tags ON task_tags.tag_id = tags.id
                   WHERE task_tags.task_id = new.id)
  WHERE id = new.id;
END;

-- Delete
CREATE TRIGGER tasks_fts_delete AFTER DELETE ON tasks BEGIN
  DELETE FROM tasks_fts WHERE id = old.id;
END;
```

**Search Query:**
```dart
// Instead of LIKE queries, use FTS5 MATCH
final sql = '''
  SELECT tasks.*,
         bm25(tasks_fts) AS relevance_score
  FROM tasks
  JOIN tasks_fts ON tasks.id = tasks_fts.id
  WHERE tasks_fts MATCH ?
    AND tasks.deleted_at IS NULL
    AND tasks.completed = ?
  ORDER BY relevance_score ASC  -- BM25: lower = better match
  LIMIT 100
''';

// Query is just the search term (no wildcards needed!)
final results = await db.rawQuery(sql, [query, completed]);
```

**BM25 Relevance Scoring:**
- FTS5 includes BM25 ranking algorithm (industry standard)
- Considers term frequency, document length, inverse document frequency
- **Much better than our manual fuzzy scoring!**
- Returns negative scores (lower = more relevant)

**Pros:**
- ✅ **Fast:** 10-50ms for 1000 tasks (meets <100ms target easily)
- ✅ **Proper full-text search:** Handles stemming, tokenization, phrase queries
- ✅ **BM25 relevance:** Better than manual fuzzy matching
- ✅ **Scales well:** Works for 10,000+ tasks
- ✅ **No LIKE wildcards:** Cleaner queries
- ✅ **Supports advanced syntax:** `"exact phrase"`, `col:value`, `NOT term`

**Cons:**
- ❌ **Schema complexity:** Virtual table + 3 triggers
- ❌ **Migration risk:** More complex v7 migration
- ❌ **Denormalized tags:** Tag names duplicated in FTS table
- ❌ **Sync overhead:** Triggers fire on every insert/update/delete
- ❌ **Learning curve:** Different query syntax than LIKE
- ❌ **Debugging:** Virtual tables harder to inspect

---

### Option 3: Hybrid Approach (Recommended)
**Approach:** Start without FTS, add it later if performance is insufficient

**Phase 3.6B (Initial):**
- Ship with LIKE queries (no special optimization)
- Measure real-world performance on devices
- If <100ms target is met: done!
- If >100ms: Plan Phase 3.6C for FTS5 migration

**Phase 3.6C (If needed):**
- Add FTS5 virtual table
- Migrate search to use FTS
- Keep UI/UX identical (drop-in replacement)

**Pros:**
- ✅ Ship faster (Phase 3.6B stays simple)
- ✅ Real performance data before committing to FTS
- ✅ Avoids premature optimization
- ✅ Can still add FTS later if needed
- ✅ Lower risk for initial release

**Cons:**
- ❌ Might need Phase 3.6C if slow
- ❌ Users experience slower search initially
- ❌ Schema migration later instead of now

---

## Recommendation

### For Phase 3.6B: **Option 3 - Hybrid**

**Ship without FTS5 initially:**
1. Remove proposed indexes (they don't help anyway)
2. Use raw LIKE queries for search
3. Implement fuzzy scoring in Dart (still useful for ranking)
4. Add performance instrumentation to measure actual search time
5. Document FTS5 as "Phase 3.6C - If performance insufficient"

**Why this approach:**
- **Simpler implementation** - Focus on UX, not optimization
- **Real data** - Measure before optimizing
- **Lower risk** - FTS5 triggers are complex, easy to get wrong
- **Incremental** - Can always add FTS later

**Performance expectations:**
- **100 tasks:** ~20-50ms (likely fine)
- **500 tasks:** ~50-150ms (borderline)
- **1000 tasks:** ~150-300ms (might need FTS)

**Decision point:**
- If real testing shows >150ms for typical use cases → Plan Phase 3.6C with FTS5
- If <150ms → Skip FTS5 entirely, mark as future optimization

---

## Implementation Estimate

### Option 2 (FTS5 in Phase 3.6B):
- Migration v7: +2 days (virtual table, triggers, testing)
- SearchService rewrite: +1 day (new query syntax)
- Testing: +1 day (verify sync triggers work)
- **Total:** +4 days → 12-15 days total for Phase 3.6B

### Option 3 (Hybrid - Ship simple, add FTS later if needed):
- Phase 3.6B: No change (9-12 days as planned with other fixes)
- Phase 3.6C (if needed): 3-4 days (FTS5 migration only)
- **Total:** 9-12 days for Phase 3.6B, possible 3-4 day Phase 3.6C

---

## Questions for BlueKitty

1. **Performance priority:**
   - Must hit <100ms for 1000 tasks in Phase 3.6B? → Use FTS5 now
   - Okay to ship and optimize later if needed? → Hybrid approach

2. **Complexity tolerance:**
   - Comfortable with FTS5 triggers and virtual tables? → Use FTS5 now
   - Prefer simpler initial implementation? → Hybrid approach

3. **Timeline preference:**
   - Ship faster with simple search → Hybrid (9-12 days)
   - Ship with optimal performance → FTS5 now (12-15 days)

---

## My Recommendation

**Go with Hybrid (Option 3):**

**Reasoning:**
1. **Premature optimization risk** - We don't know if LIKE queries will be too slow yet
2. **Simpler plan-v3** - Focus on fixing agent feedback, not adding FTS complexity
3. **Lower risk** - FTS5 triggers are complex; mistakes cause data corruption
4. **Faster shipping** - Get search in users' hands sooner
5. **Escape hatch** - Can always add FTS5 in Phase 3.6C if performance is bad

**Action items for plan-v3:**
1. Remove SQL indexes (they're useless anyway)
2. Document that search uses LIKE queries (no special optimization)
3. Add TODO comment: "Consider FTS5 if performance <100ms target not met"
4. Include performance measurement in testing
5. Keep timeline at 9-12 days

**If you want FTS5 NOW:** I can do it, but it adds 4 days and complexity. Your call!

---

**Document Status:** Analysis complete, awaiting decision
**Next Step:** Update plan-v3 based on your preference (Hybrid vs FTS5 now)
