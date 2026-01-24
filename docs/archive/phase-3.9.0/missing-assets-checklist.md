# Phase 3.9 Missing Assets Checklist

**Created:** 2026-01-23
**Status:** Awaiting asset creation
**Total Needed:** 7 images

---

## ✅ Already Complete

- **Badges (23 total):** All photorealistic embroidered badges created and organized
  - Location: `assets/images/badges/{1x,2x,3x}/`
  - Individual badges: 19
  - Rare combination badges: 4
  - Status: ✅ Done (commit a6e2a9c)

---

## ❌ Missing Assets

### Quiz Scenario Illustrations (4 images)

These are simple, illustrative graphics for quiz questions. Should match the Witchy Flatlay aesthetic (warm, muted tones, scholarly cottagecore vibe).

#### 1. clock_230am.png
**Purpose:** Question 1 - Circadian rhythm detection

**Question context:**
> "It's 2:30am on Saturday and you haven't fallen asleep yet. You remark to someone that you'll wash the dishes 'tomorrow.' Do you mean Saturday or Sunday?"

**Visual requirements:**
- Clock showing 2:30 AM
- Night/darkness context (moon, stars, dark sky)
- Maybe a tired person, or just the clock with a moon
- Warm, muted color palette
- Simple illustration style (not photorealistic like badges)

**Dimensions:** 400×300px or similar (rectangular, landscape)
**Format:** PNG with transparency preferred, or SVG

**Aesthetic inspiration:** Vintage alarm clock, crescent moon, soft midnight blue background with warm kraft paper tones

---

#### 2. calendar_week.png
**Purpose:** Question 3 - Week start preference

**Question context:**
> "When you think about 'this week,' what day does the week start on?"

**Visual requirements:**
- Two mini calendars side-by-side showing:
  - Left: Sunday-start calendar (Sun, Mon, Tue, Wed, Thu, Fri, Sat)
  - Right: Monday-start calendar (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
- Highlight "current week" in both views to show the difference
- Witchy Flatlay colors (kraft paper background, deep shadow text)
- Clear labels or visual distinction

**Dimensions:** 500×250px or similar (wide rectangular)
**Format:** PNG or SVG

**Aesthetic inspiration:** Vintage calendar grid, paper texture, warm tones, maybe subtle decoration like a small pressed flower or coffee stain

---

#### 3. time_ranges.png
**Purpose:** Question 4 - "Tonight" time keyword preference

**Question context:**
> "You tell someone to meet you 'tonight.' What time range do you typically mean?"

**Visual requirements:**
- Clock face (12-hour format preferred for accessibility)
- Highlighted time ranges showing different "tonight" interpretations:
  - 6-8pm (early evening)
  - 8-10pm (classic evening)
  - 10pm+ (late night)
- Use different colors or shading for each range
- Moon/evening imagery

**Dimensions:** 400×400px (square)
**Format:** PNG or SVG

**Aesthetic inspiration:** Vintage clock face, warm colors for time ranges (kraft paper, warm wood, muted lavender), subtle moon phases decoration

---

#### 4. sleep_moon.png
**Purpose:** Question 9 - Sleep schedule / end of day detection

**Question context:**
> "On a usual day, what time do you fall asleep?"

**Visual requirements:**
- Moon phases or moon position illustration
- Could show moon position at different sleep times:
  - Early: Moon just risen (9pm-midnight)
  - Moderate: Moon high in sky (midnight-2am)
  - Late: Moon setting (2am-4am+)
- Sleep/rest imagery (bed, closed eyes, stars)
- Calm, soothing colors (midnight blues, warm shadows)

**Dimensions:** 400×300px (rectangular)
**Format:** PNG with transparency preferred

**Aesthetic inspiration:** Celestial theme, moon phases embroidered on night sky, vintage astronomy illustration style, warm muted tones

---

### Onboarding/Celebration Images (3 images)

These frame the quiz experience with welcoming and celebratory visuals.

#### 5. welcome.png
**Purpose:** Quiz welcome screen (first screen user sees)

**Context:**
- "Let's learn how you think about time!" introduction
- Sets tone for the quiz (fun, personality-test style, not intimidating)
- User can skip or proceed

**Visual requirements:**
- Welcoming, friendly illustration
- Time-related imagery (clocks, calendars, hourglasses, sun/moon)
- Scholarly cottagecore vibe (books, journals, pressed flowers, vintage stationery)
- Witchy Flatlay palette
- Should feel inviting and low-pressure

**Dimensions:** 600×400px or similar (landscape)
**Format:** PNG with transparency or solid warm background

**Aesthetic inspiration:** Flatlay of vintage time-keeping items (pocket watch, calendar, journal, quill pen, dried flowers) on kraft paper background

---

#### 6. celebration.png
**Purpose:** Quiz completion screen (after all 9 questions answered)

**Context:**
- "Analyzing your time personality..." → celebration
- Shown before badge reveal
- Brief moment of accomplishment

**Visual requirements:**
- Celebratory but understated (not confetti explosion, more like "success!")
- Could be:
  - Completed journal with checkmark
  - Finished scroll with wax seal
  - Stack of organized index cards
  - Vintage ribbon/medal
- Warm, affirming colors (sage green, kraft paper, warm wood)

**Dimensions:** 400×400px (square or portrait)
**Format:** PNG with transparency preferred

**Aesthetic inspiration:** Vintage achievement badge (simpler than the embroidered ones), wax seal on parchment, or organized flatlay showing "completed" status

---

#### 7. sash_background.png
**Purpose:** Badge reveal ceremony background

**Context:**
- After quiz completion, badges appear one-by-one on a scout sash
- Sash is diagonal across the screen
- Badges fade in + bounce onto the sash with staggered timing
- This is THE key visual moment of Phase 3.9

**Visual requirements:**
- **CRITICAL:** Scout merit badge sash (diagonal fabric band)
- Diagonal orientation (top-left to bottom-right or vice versa)
- Fabric texture (canvas, felt, or sturdy cloth)
- Color: Kraft paper or warm beige (matches Witchy Flatlay palette)
- Should have visual "placement spots" where badges will appear
  - Could be subtle circles/hexagons embroidered on fabric
  - Or just the fabric texture with space for ~5-8 badges
- Realistic fabric texture (wrinkles, weave, stitching at edges)

**Dimensions:**
- Tall/portrait orientation recommended (e.g., 800×1200px)
- Or wide enough to show diagonal sash across typical phone screen
- Should work on mobile (most common use case)

**Format:** PNG with transparency (transparent background, just the sash)

**Aesthetic inspiration:**
- Scout merit badge sash (diagonal band with badges)
- Vintage canvas/felt fabric texture
- Warm, muted beige/kraft color
- Could have subtle embroidered border or stitching details
- Reference images: Boy Scout/Girl Scout merit badge sashes

**Note:** This is the most important visual asset for Phase 3.9.2. The badge reveal ceremony is the emotional payoff of the entire quiz experience.

---

## Asset Creation Priority

**High Priority (needed for Phase 3.9.1 - Quiz Framework):**
1. ⭐ welcome.png (first thing users see)
2. ⭐ celebration.png (quiz completion)
3. Quiz illustrations 1-4 (needed for questions to make sense)

**Critical Priority (needed for Phase 3.9.2 - Badge Reveal):**
4. ⭐⭐⭐ sash_background.png (THE centerpiece of the badge system)

---

## Technical Specifications

### File Naming
- Use lowercase with underscores: `clock_230am.png`, `sash_background.png`
- No spaces or special characters

### Color Palette Reference
Use colors from the Witchy Flatlay palette (see `lib/utils/theme.dart`):
- Warm Wood: #8B7355
- Kraft Paper: #D4B896
- Cream Paper: #F5F1E8
- Deep Shadow: #4A3F35
- Rich Black: #1C1C1C
- Muted Lavender: #9B8FA5
- Soft Sage: #8FA596
- Warm Beige: #E8DDD3

Semantic colors (for emphasis):
- Success/affirmation: #7A9B7A (muted sage green)
- Info/neutral: #7A8FA5 (muted slate blue)

### Directory Structure
```
assets/images/
├── quiz/
│   ├── clock_230am.png          ← NEW
│   ├── calendar_week.png        ← NEW
│   ├── time_ranges.png          ← NEW
│   └── sleep_moon.png           ← NEW
└── onboarding/
    ├── welcome.png              ← NEW
    ├── celebration.png          ← NEW
    └── sash_background.png      ← NEW (CRITICAL)
```

---

## Asset Creation Tools/Options

**Recommended approaches:**
1. **AI Generation** (Midjourney, DALL-E, Stable Diffusion)
   - Use prompts with "vintage illustration", "scholarly aesthetic", "warm muted tones"
   - Specify Witchy Flatlay color palette hex codes
   - Iterate to match the existing badge aesthetic

2. **Canva/Figma**
   - Good for simple illustrations (calendars, clock faces)
   - Can use vintage textures and maintain color palette
   - Export as PNG with transparency

3. **Stock Photo + Editing**
   - Find vintage clock/calendar photos
   - Adjust colors to match palette
   - Add warm filters, textures

**For sash_background.png specifically:**
- May need photo of actual fabric + editing
- Or AI generation with very specific prompt: "diagonal scout merit badge sash, beige canvas fabric texture, empty, photorealistic, warm lighting"

---

## Next Steps

1. Create assets 1-7 above
2. Place in appropriate directories (create directories first):
   ```bash
   mkdir -p assets/images/quiz
   mkdir -p assets/images/onboarding
   ```
3. Update `pubspec.yaml` to include new asset directories (already planned in Phase 3.9 plan)
4. Test asset loading in quiz implementation

---

## Questions for Designer

- **Style preference:** Should quiz illustrations be minimalist/line-art, or more detailed like the badges?
- **Sash style:** Traditional scout sash (wide diagonal band), or something more decorative?
- **Welcome screen:** Should it show example badges, or just time-related imagery?
- **Celebration:** Subtle success moment, or more enthusiastic?

---

**Status:** 📋 Checklist ready
**Blocking:** Phase 3.9.1 (Quiz Framework) can start with placeholder images
**Critical for:** Phase 3.9.2 (Badge Reveal) needs sash_background.png
