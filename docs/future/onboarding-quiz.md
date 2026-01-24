# Onboarding Quiz: Time Perception & Preferences

**Phase:** 4 (or later - TBD)
**Status:** Future planning
**Goal:** Infer user's time perception through scenario-based questions instead of making them manually configure settings

---

## Concept

Instead of confronting users with abstract settings like "today cutoff hour" or "week start day," we ask them intuitive scenario-based questions about how they naturally think about time. Behind the scenes, we map their answers to the appropriate settings.

**User Benefits:**
- No technical jargon or confusing settings screens
- Fun, personality-test style experience
- More accurate settings (based on actual behavior vs guesses)
- Can skip and use defaults, or retake later

**Implementation:**
- Show on first launch (optional, dismissable)
- 9 questions, ~3-4 minutes
- Set user_settings based on responses
- "Retake quiz" option in settings
- "Explain my settings" feature that shows which quiz answers led to current config

---

## Sample Questions

**NOTE FOR FUTURE IMPLEMENTATION:** Consider adding an initial screener question specifically for shift workers (second shift, third shift, rotating shifts). Their time structure is fundamentally different enough that we may want to detect this upfront and adjust the entire quiz flow or offer preset configurations. Examples:
- "Do you work a non-traditional schedule?" (night shift, rotating shifts, etc.)
- If yes → Offer shift-worker preset OR adjust quiz questions to be shift-aware
- Rationale: Shift work context (especially third shift) is so distinct that it affects how ALL other time questions should be interpreted

### 1. Circadian Rhythm Detection

**Question:**
> "It's 2:30am on Saturday and you haven't fallen asleep yet. You remark to someone that you'll wash the dishes 'tomorrow.' Do you mean Saturday or Sunday?"

**Answers:**
- **A: Saturday** (I consider this still Friday night, Friday hasn't ended yet)
  - **Sets:** `today_cutoff_hour = 4` or `5` (late cutoff, night owl mode)
  - **Rationale:** User's "day" extends past midnight until they sleep

- **B: Sunday** (Friday is over at midnight, it's been Saturday for 2.5 hours)
  - **Sets:** `today_cutoff_hour = 0`, `today_cutoff_minute = 0` (midnight purist)
  - **Rationale:** User follows strict calendar day boundaries

**UI Note:** Include small illustration of clock showing 2:30am

---

### 2. Weekday Reference Logic

**Question:**
> "It's Saturday afternoon. A friend asks if you're free 'this Friday.' What do you think they mean?"

**Answers:**
- **A: Next Friday (6 days away)** - That's the next Friday coming up
  - **Sets:** Forward-looking weekday logic (our Option 1 implementation)
  - **Rationale:** Weekday references always point forward

- **B: That's confusing, Friday was yesterday** - I'd ask them to clarify
  - **Sets:** Calendar-week based logic (Option 2 - if we implement this variant)
  - **Rationale:** "This [day]" must be within the current week

- **C: It depends on context** - Could mean either
  - **Sets:** Default to Option 1, but flag for manual adjustment
  - **Rationale:** User is aware of ambiguity, might want to tweak settings

**UI Note:** Show calendar with Saturday highlighted

---

### 3. Week Start Preference

**Question:**
> "When you think about 'this week,' what day does the week start on?"

**Answers:**
- **A: Sunday** - Traditional US calendar style
  - **Sets:** `week_start_day = 0` (Sunday)

- **B: Monday** - International/work week style
  - **Sets:** `week_start_day = 1` (Monday)

- **C: Other** - Let me pick (show day picker)
  - **Sets:** `week_start_day = [user choice]` (0-6)

**UI Note:** Show two mini calendars side-by-side (Sun-start vs Mon-start)

---

### 4. Time Keyword Preferences - "Tonight"

**Question:**
> "You tell someone to meet you 'tonight.' What time range do you typically mean?"

**Answers:**
- **A: 6-8pm** - Early evening, dinner time
  - **Sets:** `tonight_hour = 18` (6pm)

- **B: 8-10pm** - Classic evening
  - **Sets:** `tonight_hour = 19` or `20` (7-8pm)

- **C: 10pm or later** - Late night
  - **Sets:** `tonight_hour = 22` (10pm)

**UI Note:** Clock face with highlighted ranges

---

### 5. Time Keyword Preferences - "Morning" (User-Driven)

**Question:**
> "You're planning your day and schedule a task for 'morning.' What time do YOU typically mean?"

**Answers:**
- **A: 7-8am** - Early morning works best for me
  - **Sets:** `morning_hour = 7`
  - **Also set:** `early_morning_hour = 5` (proportionally early)

- **B: 9-10am** - Mid-morning is my sweet spot
  - **Sets:** `morning_hour = 9` (default)

- **C: 11am-noon** - Late morning suits my rhythm
  - **Sets:** `morning_hour = 11`
  - **Also set:** `noon_hour = 13` (proportionally late)

**UI Note:** Sun position illustration (sunrise → midday) with emphasis on "YOUR morning"

---

### 6. Display Time Format

**Question:**
> "How do you prefer to see times displayed?"

**Answers:**
- **A: 3:00 PM** - 12-hour format with AM/PM
  - **Sets:** `use_24hour_time = 0`

- **B: 15:00** - 24-hour format (military time)
  - **Sets:** `use_24hour_time = 1`

**UI Note:** Side-by-side comparison of same time in both formats

---

### 7. Quick Add Field - Date Parsing Preference (New in Phase 3.4)

**Question:**
> "When you type 'Call dentist Jan 15' in the quick-add field, what should happen?"

**Answers:**
- **A: Automatically detect the date** - Highlight 'Jan 15' and set it as the due date
  - **Sets:** `enable_quick_add_date_parsing = 1` (default)
  - **Rationale:** User wants smart date parsing (Todoist-style)

- **B: Keep it simple** - Just create a task titled 'Call dentist Jan 15'
  - **Sets:** `enable_quick_add_date_parsing = 0`
  - **Rationale:** User prefers quick-add to stay simple and fast

**UI Note:** Split-screen preview showing both behaviors
- Left: Text field with "Jan 15" highlighted in blue
- Right: Plain text field without highlights

**Implementation Note:** This setting only affects the Quick Add Field at the top of the home screen. Brain Dump (with Claude) always uses smart date parsing regardless of this setting.

---

### 8. Task Completion Behavior (Bonus Question)

**Question:**
> "You complete a parent task that has 3 unfinished subtasks. What should happen to the subtasks?"

**Answers:**
- **A: Ask me every time** - I'll decide case-by-case
  - **Sets:** `auto_complete_children = 'prompt'` (default)

- **B: Always mark them complete too** - Parent done = all done
  - **Sets:** `auto_complete_children = 'always'`

- **C: Leave them incomplete** - I'll complete them separately
  - **Sets:** `auto_complete_children = 'never'`

**UI Note:** Animated illustration of parent task with nested children

---

### 9. Sleep Schedule - End of Day Detection

**Question:**
> "On a usual day, what time do you fall asleep?"

**Answers:**
- **A: Before midnight (9pm-11:59pm)** - Early to bed
  - **Sets:** Confirms/reinforces `today_cutoff_hour` inference from Question 1
  - **Rationale:** Early sleepers less likely to have extended "day" past midnight

- **B: 12am-2am** - Around midnight
  - **Sets:** Default `today_cutoff_hour = 4` (moderate night owl)
  - **Rationale:** Some post-midnight activity, but not extreme

- **C: 2am-4am** - Late night
  - **Sets:** `today_cutoff_hour = 5` or `6` (strong night owl)
  - **Rationale:** Regularly awake past 2am, day extends well past midnight

- **D: 4am or later / Varies wildly** - No consistent schedule
  - **Sets:** `today_cutoff_hour = 6` (very late, accommodates maximum variability)
  - **Rationale:** Extreme night owl or shift worker, needs flexible day boundary

**UI Note:** Moon phases illustration or sleep cycle graphic

**Note:** This question cross-validates with Question 1. If answers conflict (e.g., Q1 says "Friday is over at midnight" but Q8 says "I fall asleep at 3am"), system prioritizes Q1's explicit logical choice over sleep schedule.

---

## Badges & Personality Traits

**Concept:** Award fun, embroidered scout-badge style achievements based on quiz answers. These are displayed in user profile/settings and (in future team features) visible to collaborators to set expectations about different work styles and schedules.

**Visual Style:** Embroidered patch aesthetic, witchy scholarly cottagecore vibe
- Circular or shield-shaped badges
- Illustrated icons (moon, sun, clock, calendar)
- Ribbon/banner with badge name
- Soft, muted color palette matching app theme

### Badge Catalog

**Circadian Rhythm Badges:**
- 🌙 **"Midnight Purist"** - Friday is over at midnight, strict calendar boundaries (Q1-B)
- 🦉 **"Night Owl"** - Your Friday extends past midnight, late day cutoff (Q1-A)
- 🌅 **"Early Bird"** - Morning person, early sleep schedule (Q8-A + Q5-A)
- 🌌 **"Nocturnal Scholar"** - Awake past 2am regularly, extreme night owl (Q8-C or Q8-D)

**Week Structure Badges:**
- 📅 **"Monday Starter"** - Week begins Monday, international style (Q3-B)
- 🇺🇸 **"Sunday Traditionalist"** - Week begins Sunday, classic US calendar (Q3-A)
- 🌍 **"Calendar Rebel"** - Week starts on unconventional day like Wednesday (Q3-C with unusual choice)

**Time Perception Badges:**
- ⏰ **"Forward Thinker"** - "This Friday" always means next occurrence (Q2-A)
- 📆 **"Calendar Contextual"** - Week boundaries matter for day references (Q2-B)
- 🤷 **"Flexible Interpreter"** - Context-dependent time understanding (Q2-C)

**Daily Rhythm Badges:**
- ☀️ **"Dawn Greeter"** - Early morning person (Q5-A + Q4-A)
- 🌆 **"Twilight Worker"** - Evening/night productivity (Q4-C + late sleep) 
^IMAGE NOT MADE YET!!!

- 🕐 **"Classic Scheduler"** - Standard 9-5 aligned rhythm (Q5-B + Q4-B)
- 🌙 **"Late Morning Luxurist"** - Slow morning starts, late preferences (Q5-C)

**Display Preference Badges:**
- **"Exacting Enthusiast"** - 24-hour clock preference (Q6-B)
- 🕰️ **"AM/PM Classicist"** - 12-hour clock preference (Q6-A)

**Task Management Style Badges:**
- 🎯 **"Decisive Completer"** - Always auto-complete children (Q7-B)
- 🤔 **"Thoughtful Curator"** - Prompts for subtask completion (Q7-A)
- 🗂️ **"Granular Manager"** - Never auto-complete, handles each task separately (Q7-C)

### Badge Combinations & Special Titles

**Rare Combinations:**
- 🌙🦉 **"Vampire Scholar"** - Midnight Purist + Nocturnal Scholar (logically interesting: strict calendar boundaries but awake all night)
- ☀️🌅 **"Sunrise Achiever"** - Early Bird + Dawn Greeter + Monday Starter (ultimate morning person)
- 🌍🤷 **"Time Anarchist"** - Calendar Rebel + Flexible Interpreter (non-traditional everything)
- 🎖️🌌 **"Night Ops"** - Military Time Enthusiast + Nocturnal Scholar (late night precision)

### Badge Display & Sharing

**In-App Display:**
- Settings page: "Your Time Personality" section with earned badges
- Small badge icons next to settings that correspond to badge
- Tooltip on hover: "You earned this because you're a Night Owl!"

**Future Team Features (Phase 6+):**
- Team member profiles show their badges
- Helps set expectations: "Oh, Sarah's a Night Owl, I'll schedule our sync for afternoon"
- Team diversity view: "Your team spans 4 time zones and 3 circadian types!"
- Collaboration suggestions: "You're both Dawn Greeters - try morning pairing sessions"

**Gamification (Optional Future):**
- "Consistent Scheduler" badge: Use app 30 days in a row
- "Time Master" badge: Completed 100 tasks with parsed dates
- "Weekend Warrior" badge: Completed 50 weekend tasks
- "Early Adopter" badge: Participated in onboarding quiz

### UX Flow for Badge Reveal

1. **Quiz Completion:** Celebration animation
2. **Results Screen:** "Analyzing your time personality..."
3. **Badge Reveal:** One-by-one animation, scout-troop-ceremony style
   - Badge appears with embroidered effect (think embroidery hoop animation)
   - Title announced: "You've earned: Midnight Purist!"
   - Description: "You believe Friday ends at midnight, with strict calendar boundaries"
   - Fun fact: "Only 23% of users share this trait!" (build community, show diversity)
4. **Collection Screen:** All earned badges displayed together with badge combination title
   - Example: "Your Time Personality: Midnight Purist + Monday Starter + Classic Scheduler"
   - Special combo badge if applicable: "You're a Vampire Scholar!" (with explanation)
5. **Settings Applied:** "Your app is now configured to match your rhythm"
   - Show 2-3 key settings that were configured
   - Example: "Your 'day' ends at 12:00am (midnight), and 'morning' means 9am"
6. **CTA:** "Start capturing tasks" or "Explore your settings"

---

## Implementation Notes

### Quiz Flow
1. **Welcome screen:** "Let's learn how you think about time!" (skip button visible)
2. **Questions 1-9:** One per screen, with illustrations
3. **Results screen:** "Your personalized settings are ready!" with summary
4. **Settings preview:** "Here's what we configured for you" (option to tweak)

### User Settings Mapping

| Question | Setting(s) | Default (if skipped) |
|----------|-----------|---------------------|
| 1 (Circadian logic) | `today_cutoff_hour`, `today_cutoff_minute` | 4:59am |
| 2 (Weekday logic) | Internal parsing logic | Forward-looking (Option 1) |
| 3 (Week start) | `week_start_day` | Monday (1) |
| 4 (Tonight keyword) | `tonight_hour` | 7pm (19:00) |
| 5 (Morning keyword) | `morning_hour`, `early_morning_hour` | 9am, 5am |
| 6 (Time format) | `use_24hour_time` | 12-hour (0) |
| 7 (Quick Add date parsing) | `enable_quick_add_date_parsing` | ON (1) |
| 8 (Auto-complete) | `auto_complete_children` | 'prompt' |
| 9 (Sleep schedule) | Cross-validates Q1, refines `today_cutoff_hour` | 4:59am |

### Additional Settings (Not in Quiz)
These would still use smart defaults but be manually adjustable:
- `noon_hour` (12pm)
- `afternoon_hour` (3pm)
- `late_night_hour` (10pm)
- `default_notification_hour` (9am)
- `voice_smart_punctuation` (ON)

### Future Enhancements
- **A/B test questions:** Try different phrasings, see what resonates
- **Cultural presets:** "I live in [region]" → infer likely preferences
- **Machine learning:** Over time, learn user's actual behavior and suggest adjustments
- **"Why this setting?" explainer:** Click any setting → see which quiz answer led to it

---

## Design Inspiration

**Style:** Playful, illustrated, personality-quiz aesthetic
- Duolingo-style progress dots at top
- Smooth transitions between questions
- Illustrations that match the "witchy scholarly cottagecore" aesthetic
- Celebration animation on completion

**References:**
- Duolingo onboarding flow (language goals)
- Notion workspace setup wizard (templates selection)
- iOS setup assistant (personalization questions)

---

## Success Metrics

- **Completion rate:** % of users who finish quiz vs skip
- **Setting changes:** Do users manually adjust settings after quiz? (indicates accuracy)
- **User satisfaction:** Survey question: "Did the quiz help you configure the app?"

**Target:** 60%+ completion rate, <20% setting changes post-quiz

---

**Status:** Planning phase - ready for design mockups and implementation in Phase 4+

**Last Updated:** Phase 3 Planning (2025-10-29)
**Created By:** Claude + BlueKitty
