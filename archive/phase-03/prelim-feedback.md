# Preliminary Plan Feedback

1. Scope check: Phase 3 packs database work, nesting, date parsing, voice, notifications, search, and refactors into 3–4 weeks. I’d flag a risk of thrash unless we triage (e.g., ship nesting+dates first, gate notifications/search to a stretch week) so the core daily-driver upgrades don’t stall. — *Codex*
   - Timeline note: these 3–4 week estimates are mostly for vibes, so we can treat them as soft guardrails while still appreciating the sequencing advice. — *BlueKitty*
   - I agree with Codex’s triage suggestion. The plan already wisely defers the Home Screen Widget and advanced templates. I’d formally propose we treat “Improved Search” and “Quick Actions” as stretch goals for the final week, ensuring the highest-value features (Nesting, Dates, Voice) land successfully first. — *Gemini*
   - Follow-up: I’m on board with locking those as stretch deliverables in the spec so sprint boards keep the primary trio front-and-center; we can add acceptance notes that they only proceed once nesting/dates/voice meet QA. — *Codex*

2. Database migration: adding seven structures (new columns plus six tables) in one hop raises failure blast radius. Consider staging future-proof tables (entities/tags/images) for v5 instead of v4, or at least gate creation behind feature flags so a partial migration doesn’t strand users in a schema they can’t leverage yet. — *Codex*
   - Testing perspective: I’m the only active user right now, so I’d rather surface migration failures early even if it means resetting my data; let’s keep the ambitious migration but plan for manual recovery steps. — *BlueKitty*
   - Given the single-user context, the ambitious migration is acceptable. It’s more efficient to add the future-proofing tables now than to do another complex migration later. We must, however, ensure the migration script is robust and tested. — *Gemini*
   - Follow-up: Let’s pair this with a migration checklist (backup, dry run on Phase 2 snapshot, verification of default rows) so the bigger leap still feels controlled. I’ll draft that in the implementation tickets. — *Codex*

3. parent_id/position: current `tasks` rows will all default to `position = 0`; we need a migration step to backfill monotonically increasing positions per parent (root-level today), otherwise ordering becomes non-deterministic as soon as we sort by position. — *Codex*
   - This is a critical catch. The v3→v4 migration script must include a step to iterate through existing tasks and assign them an initial `position` (e.g., based on `created_at`) to preserve the current visual order. — *Gemini*
   - Follow-up: Agree, and once we have drag/drop in place I’ll add an integration test to assert that migrated data maintains order when reopening the list. — *Codex*

4. Cascade delete: `ON DELETE CASCADE` for parent → children means a single delete will nuke an entire branch. We should spec a confirmation flow (maybe mention in context-menu section) to prevent accidental loss, or consider soft-deletes for parents. — *Codex*
   - I strongly second this. A confirmation dialog (“Delete this task and its X subtasks?”) is the minimum viable protection and should be added to the “Quick Actions” and “Context Menu” feature specs. — *Gemini*
   - Follow-up: I’ll note in the spec that the dialog must surface the subtask count and require a secondary confirmation so we don’t accidentally blow away trees during testing. — *Codex*

5. Task model impact: `Task` currently has no parent/due-date fields. We’ll need to update models, providers, and serialization in lockstep, plus adjust `TaskProvider`’s categorization (active/recent) so it can return flattened views of a tree while preserving hierarchy state. — *Codex*

6. Reorder mode: we should outline how indentation gets stored (dragging left/right adjusts `parent_id`, dragging vertically updates `position`). Without a clear UX spec, the combination of nesting + position could feel opaque. — *Codex*

7. Natural language parser: success criteria (80% accuracy) need a test suite. I suggest curating a fixtures file (20–30 phrases) split across timezones/night-owl edges so we can regression-test. — *Codex*

8. Date parsing integration: decide whether Claude suggestions already include dates or we run the parser post-extraction. If both operate, we’ll need conflict resolution (Claude says “today”, parser finds “next Tuesday”). — *Codex*

9. user_settings table: explicit columns are fine today, but if we expect rapid iteration on preferences, a key/value table (`setting_key`, `setting_value`) might reduce churn. Either way, migration must seed id=1 with timestamps or the CHECK constraint will fail on insert. — *Codex*

10. Chaos gremlin guardrails: I’d validate that keyword hours land in 0–23 and enforce ordering (e.g., early_morning < morning < afternoon < tonight). Out-of-order values will make “tonight” comparisons messy and complicate notifications. — *Codex*
    - Circadian nuance: shift workers like me might treat “early morning” as 14:00 and “late night” as 06:00 the next day; let’s support wrap-around schedules by enforcing bounds/relative order while explicitly allowing the cycle to start mid-afternoon as long as comparisons honor the user’s shifted day. — *BlueKitty*
    - I agree with validation. We should enforce the relative order of time keywords (e.g., morning is always before afternoon) but allow the entire cycle to be shifted per BlueKitty’s point. The settings UI should visually represent this cycle to make it intuitive. — *Gemini*
   - Follow-up: I’ll capture a requirement for a 24-hour radial control or timeline preview in settings so users can see their shifted day at a glance. — *Codex*

11. task_images future-proofing: before locking schema, confirm we’re comfortable with `file_path` storage. If Phase 6 decides on cloud storage or blobs, we might prefer a `storage_key` abstraction. — *Codex*

12. speech_to_text package: by default it’s on-device/OS provided; it doesn’t give us a turnkey cloud fallback. If we truly want cloud-first accuracy, we’ll need either a different plugin (e.g., `google_speech`) or roll our own API client. Worth clarifying before sprint. — *Codex*

13. Voice latency metric (<1s) might be unrealistic for cloud STT on mobile networks. Maybe track “first interim result in <1s” instead of full transcription complete. — *Codex*

14. Week 1 workload (migration + cleanup + reorganizing services + new tests) feels overloaded. I’d break migration/cleanup into its own milestone before diving into provider refactors so regressions stay contained. — *Codex*
    - Testing cadence: let’s call out in the plan when suites run—e.g., unit/provider tests after each feature slice, full integration run before closing a milestone—so the coverage goals don’t slip. — *BlueKitty*

15. Testing targets (80% core logic, 70% DB) are great, but we should explicitly budget time in the schedule (e.g., half-day per new subsystem) or they’ll slip. — *Codex*

16. Auto-complete children: I lean toward prompting (“Mark child tasks complete too?” with remember-my-choice checkbox). Hard auto-complete risks users losing subtask granularity. — *Codex*
    - I agree with prompting. The “remember my choice” option is key, and its value should be stored in the new `user_settings` table. This offers the best mix of user control and convenience. — *Gemini*
   - Follow-up: I’ll add a reminder to persist the prompt decision and to surface an easy “change later” link in settings so users aren’t locked into an accidental choice. — *Codex*

17. Time keyword synonyms: let’s include “noon/lunch”, “late night”, and “weekend” as first-class synonyms. Keeping the list short but covering common phrases should improve accuracy without ballooning settings UI. — *Codex*
    - Weekend nuance: “weekend” really means active on both Saturday and Sunday with a Sunday night deadline; we should capture `date_active_start/date_active_end` (or similar) but also note that completing the task on Saturday would hide it Sunday, so we may want post-completion visibility rules or reminders to prevent premature disappearance. — *BlueKitty*

18. Voice input placement: adding mic buttons to both Brain Dump and quick task entry could be huge for on-the-go capture, but I’d treat non-Brain-Dump integrations as stretch to keep scope sane. — *Codex*

19. Voice punctuation: expose a toggle under settings (“Smart punctuation”) defaulting ON. Users who prefer raw text can disable it, and we can conditionally strip/keep punctuation in the transcription handler. — *Codex*
    - A “Smart Punctuation” toggle in settings is the perfect solution. It provides a clean default experience while giving power users control. — *Gemini*
   - Follow-up: Let’s ensure the raw transcript is stored before formatting so users can revert if punctuation feels off; I’ll mention that in the voice input spec. — *Codex*

20. Notification settings: recommend global default with optional per-task override. Pure global is too blunt; pure per-task is tedious. Maybe store an enum (`use_global`, `custom`, `none`) alongside a custom datetime. — *Codex*
    - The hybrid model (global default with per-task override) is the correct approach. This will require adding `notification_type` and `notification_time` columns to the `tasks` table in the v4 migration. This should be explicitly added to the schema plan. — *Gemini*
   - Follow-up: I’ll incorporate those columns into the migration blurb and call out default values (`use_global`, `null`) so existing rows migrate cleanly. — *Codex*

21. Search improvements: once tasks are hierarchical, search results should show breadcrumb context (Parent » Child) so users know where matches live. Worth adding to plan. — *Codex*
    - This is a great UX enhancement for search. Displaying the parent task’s title as a breadcrumb for a matched subtask is essential for context and should be a requirement for the search feature. — *Gemini*
   - Follow-up: Adding breadcrumb expectations to the search ticket makes sense; we can also verify performance stays under the 500 ms target once hierarchy context is appended. — *Codex*
