# Pin and Paper - Visual Design & Interaction Specification

## Overview
This document defines the visual aesthetic, lighting system, interaction patterns, and UX principles for Pin and Paper. It incorporates lessons learned from Defter Notes and other spatial note-taking apps, while creating a uniquely aesthetic and ADHD-friendly experience.

---

## Core Visual Philosophy

**The Aesthetic:** Witchy scholarly cottagecore - a gentle witch's study desk where magic and learning intersect. Natural, collected-over-time, deeply personal, warm and intimate. Both mystical and grounded, ancient and alive.

**Key Principles:**
- **Skeuomorphic but refined** - Real-world textures without feeling kitschy
- **Tactile and tangible** - Should feel like touching physical objects
- **Spatially meaningful** - Position, rotation, and layering carry organizational meaning
- **Beautiful by default** - Aesthetic quality reduces stress and increases engagement
- **Customizable deeply** - Users define their own visual language

---

## Color System

### Base Color Palettes

**Witchy Flatlay Theme (Default):**
```
Main Colors (Foundation):
- Warm Wood:     #8B7355  (desk surface)
- Kraft Paper:   #D4B896  (cards, torn strips)
- Cream Paper:   #F5F1E8  (clean cards, backgrounds)
- Deep Shadow:   #4A3F35  (depth, structure)

Accent Colors (Personality):
- Rich Black:    #1C1C1C  (journals, important items)
- Muted Lavender:#9B8FA5  (dried flowers, soft accents)
- Soft Sage:     #8FA596  (botanical elements)
- Warm Beige:    #E8DDD3  (vintage papers)

Highlight Colors (Magic):
- Sunlight Glow: #FFF8E7  (bright light hits)
- Pure Light:    #FFFFFF  (direct sunlight)
- Golden Amber:  #FFE4B5  (warm afternoon light)

Shadow Colors:
- Warm Dark:     #3D3428  (shadows with 30-60% opacity)
```

**Teenage Corkboard Theme:**
```
Main Colors:
- Cork Board:    #C19A6B
- Ribbon Pink:   #E8B4C8
- Ribbon Blue:   #A7C7E7
- White Board:   #F8F6F0

Accent Colors:
- Pushpin Red:   #D32F2F
- Pushpin Blue:  #1976D2
- Photo Border:  #FFFFFF
- String:        #8B7355

Lighting: Cooler, more diffused (bedroom window light)
```

**Tweed Professorial Theme:**
```
Main Colors:
- Tweed Brown:   #6B5D4F
- Leather:       #8B4513
- Aged Paper:    #E8DCC4
- Mahogany:      #4A2C2A

Accent Colors:
- Brass:         #B5A642
- Deep Green:    #2F4F2F
- Burgundy:      #800020
- Ink:           #1A1A1A

Lighting: Warm lamp glow, more evening/study feel
```

### User Customization

**Multiple Color Palettes:**
- Users can create custom color palettes per workspace
- Save favorite palettes for reuse
- Quick-switch between palettes
- Import/export palette configs
- Palette picker shows swatches with names

**Implementation:**
```dart
class ColorPalette {
  String name;
  String id;
  List<ColorSwatch> swatches;
  ThemeStyle associatedTheme;
}

class ColorSwatch {
  Color color;
  String name; // "Dried Lavender", "Afternoon Light"
  SwatchType type; // main, accent, highlight, shadow
}
```

---

## Dynamic Lighting System

### The Secret Sauce

The lighting is what makes the workspace feel ALIVE. It creates depth, warmth, and temporal awareness.

### Lighting Characteristics

**Physical Properties:**
- **Directional:** Light comes from a specific angle
- **Warm temperature:** Golden/amber, feels like natural window light
- **Soft edges:** Diffused, not harsh
- **Creates depth:** Long shadows make everything 3D
- **Graduated intensity:** Brighter where it hits, natural falloff

### Time-Based Lighting States

**Morning (6am-10am):**
- Direction: East (upper left in UI)
- Color temperature: Cool golden (#FFF9E6)
- Intensity: Gentle, waking up
- Shadow length: Long
- Mood: Fresh, new beginning

**Midday (10am-2pm):**
- Direction: Overhead (subtle)
- Color temperature: Bright white (#FFFEF7)
- Intensity: Strong, clear
- Shadow length: Short
- Mood: Alert, focused

**Afternoon (2pm-6pm):**
- Direction: West (upper right in UI) - THE PEAK AESTHETIC
- Color temperature: Warm amber (#FFE4B5)
- Intensity: Rich, glowing
- Shadow length: Long, dramatic
- Mood: Productive, golden hour magic

**Evening (6pm-10pm):**
- Direction: Lamp from corner (warm glow from side)
- Color temperature: Amber orange (#FFD4A3)
- Intensity: Cozy, contained
- Shadow length: Medium, softer
- Mood: Reflective, winding down

**Night (10pm-6am):**
- Direction: Desk lamp (focused from corner)
- Color temperature: Warm yellow (#FFF4D6)
- Intensity: Intimate, focused pool
- Shadow length: Dramatic but soft
- Mood: Late-night work, cozy solitude
- Optional: Moonlight through window (cool blue accent)

### Seasonal Variations (Stretch Goal)

**Spring:**
- Lighter, brighter
- Slightly cooler tones
- More diffused

**Summer:**
- Brightest, longest days
- Golden warmth
- Sharp shadows

**Fall:**
- Rich, warm tones (our default aesthetic!)
- Amber and orange
- Cozy depth

**Winter:**
- Cooler light
- Shorter day cycle
- More lamp-heavy in evening

### Weather Effects (Stretch Goal)

**Rainy Day:**
- Diffused, soft light
- Cooler color temperature
- No harsh shadows
- More even lighting

**Snowy Day:**
- Bright, reflected light
- Cool blue tones
- High contrast

**Cloudy:**
- Very diffused
- Gray-blue tones
- Flat lighting

---

## Technical Implementation

### Phase 1: Static Lighting (MVP)

**Approach:** Pre-rendered lighting overlays

```dart
class LightingOverlay extends StatelessWidget {
  final LightingState state;
  
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Workspace content
        workspaceContent,
        // Light beam gradient
        Positioned.fill(
          child: CustomPaint(
            painter: LightBeamPainter(
              angle: state.angle,
              intensity: state.intensity,
              color: state.color,
            ),
          ),
        ),
      ],
    );
  }
}
```

**Performance:** Negligible - just overlay compositing

### Phase 2: Time-Based Dynamic Lighting

**Approach:** Update lighting every 15 minutes based on real time

```dart
class LightingController {
  Timer? _updateTimer;
  
  void startLightingUpdates() {
    _updateTimer = Timer.periodic(
      Duration(minutes: 15),
      (_) => updateLightingForCurrentTime(),
    );
  }
  
  LightingState getLightingForTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    
    // Calculate interpolation between lighting states
    if (hour >= 6 && hour < 10) {
      return _interpolate(morningLight, middayLight, ...);
    }
    // ... more states
  }
}
```

**Performance:** Recalculates every 15 min when app active, minimal CPU

### Phase 3: Animated Transitions

**Approach:** Smooth tween between lighting states

```dart
class AnimatedLighting extends StatefulWidget {
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<LightingState>(
      duration: Duration(seconds: 3),
      tween: LightingStateTween(
        begin: currentLighting,
        end: targetLighting,
      ),
      builder: (context, lighting, child) {
        return LightingOverlay(state: lighting);
      },
    );
  }
}
```

**Performance:** Smooth 60fps animations, runs only during transition

### Phase 4: Per-Object Shadows

**Approach:** Each card/object calculates its shadow based on elevation and light direction

```dart
class TaskCard extends StatelessWidget {
  final double elevation; // 0-10, how "tall" the card is
  final Vector2 position;
  
  BoxDecoration _getDecoration(LightingState lighting) {
    final shadowOffset = _calculateShadowOffset(
      lightAngle: lighting.angle,
      elevation: elevation,
    );
    
    return BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: lighting.shadowColor.withOpacity(0.3),
          offset: shadowOffset,
          blurRadius: elevation * 2,
          spreadRadius: elevation * 0.5,
        ),
      ],
    );
  }
}
```

**Performance:** More expensive, but cache shadow calculations

### User Controls

**Settings:**
- [ ] Dynamic Lighting: ON/OFF
- [ ] Lighting Mode: Static / Time-Based / Live
- [ ] Manual Time Override: Set specific time for lighting
- [ ] Pause Time: Keep current lighting frozen
- [ ] Transition Speed: Fast / Normal / Slow

**Performance Options:**
- [ ] Simplified Shadows: Less detailed, better performance
- [ ] Reduce Effects: Lower quality on older devices
- [ ] Battery Saver: Static lighting only

### Battery Optimization

**Smart Behavior:**
- Pause updates when app in background
- Reduce update frequency on low battery
- Disable on battery saver mode
- User can manually disable anytime

**Performance Budget:**
- Static lighting: <1% battery impact
- Time-based updates: <2% battery impact
- Live dynamic: <5% battery impact

---

## Interaction Patterns & Gestures

### Core Philosophy

**Spatial Intelligence:** Position, rotation, and layering are primary organizational tools, not just aesthetic choices.

**Flexible Hierarchy:** Elements can be loose or structured, flat or deeply nested, as the user needs.

**Tactile Manipulation:** Direct manipulation feels like moving physical objects on a desk.

### Primary Gestures

**Single Card/Strip:**
- **Tap:** Select
- **Long Press:** Pick up, can now drag
- **Drag:** Move anywhere on canvas
- **Pinch:** Resize (cards can be different sizes!)
- **Two-finger Rotate:** Rotate card to any angle ⭐ **#1 PRIORITY FEATURE**
- **Double Tap:** Open card detail view
- **Swipe Left/Right:** Quick actions (complete, delete, etc.)

**Multiple Selection:**
- **Tap + Shift (desktop):** Add to selection
- **Circle Gesture (iPad):** Lasso select multiple items
- **Tap Background → Drag:** Box select

**Canvas:**
- **Single Finger Drag:** Pan canvas
- **Pinch:** Zoom in/out
- **Two-finger Rotate (iPad):** Rotate entire workspace view
- **Double Tap:** Reset zoom/rotation
- **Three-finger Swipe:** Undo/redo

### Object Manipulation

#### Rotation (CRITICAL FEATURE!)

**Individual Object Rotation:**
```dart
class RotatableCard extends StatefulWidget {
  double rotation = 0.0; // in radians
  
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        if (details.pointerCount == 2) {
          setState(() {
            rotation += details.rotation;
          });
        }
      },
      child: Transform.rotate(
        angle: rotation,
        child: cardContent,
      ),
    );
  }
}
```

**Why rotation matters:**
- **Signifier:** Angled cards feel "in progress" vs straight = "organized"
- **Visual interest:** Varied angles prevent monotony
- **Spatial organization:** Group cards by rotation similarity
- **Mimics physical desk:** Real papers aren't perfectly aligned!

**Rotation UI:**
- Show rotation handle on selected items
- Snap to 0°, 45°, 90° angles (optional, toggleable)
- Display rotation degree during rotation
- "Straighten" button to reset to 0°

#### Stacking & Layering

**Z-Depth System:**
```
0: Canvas background
1-10: Torn paper strips (lowest)
11-50: Index cards (main workspace)
51-90: Decorative objects
91-95: Temporary overlays (selections, etc.)
96-99: UI elements (always on top)
```

**Stack Behaviors:**
- Newer items appear on top by default
- User can "Send to Back" / "Bring to Front"
- Items touching/overlapping can be "Linked" (Defter-inspired)
- Linked items move together as a unit
- "Explode Stack" view spreads items out temporarily (Defter-inspired!)

#### Linking & Locking

**Link Multiple Cards:**
- Select multiple cards
- Tap "Link" button
- Cards now move as a unit
- Individual items still editable
- "Unlink" to separate again

**Use Cases:**
- Storyboarding: Link sequence of cards together
- Concept map: Link related ideas
- Project cluster: Keep related tasks grouped

**Visual Indicator:**
- Subtle dotted outline around linked group
- Small link icon on each linked card

**Implementation:**
```dart
class LinkedGroup {
  String id;
  List<String> cardIds;
  Vector2 anchorPoint; // center of group
  
  void moveGroup(Vector2 delta) {
    // Move all cards maintaining relative positions
    for (var cardId in cardIds) {
      cards[cardId].position += delta;
    }
  }
}
```

#### Explode Stack View

**Concept:** Temporarily spread out overlapping/stacked cards to see everything without destroying alignment.

**Behavior:**
- Tap "Explode" button on selected stack
- Cards animate outward in a radial or grid pattern
- Each card shows but maintains reference to original position
- "Collapse" button returns everything to original layout
- User can edit cards while exploded
- Changes persist when collapsed

**Visual:**
- Ghosted original position shown
- Connecting lines from exploded position to original
- "Return" animation is smooth and satisfying

**Use Cases:**
- Heavily layered research notes
- Multiple drafts of same concept
- Historical versions of a task card

---

## Card & Strip Rendering

### Torn Paper Strips

**Visual Characteristics:**
- Irregular torn edge (not perfectly straight)
- Slight texture/grain
- Can be different colors (from kraft to white)
- Shadow underneath
- Slightly curled edge? (subtle)

**Sizes:**
- Default: ~200x60 pixels
- Can expand slightly if text is long
- Maximum: ~300x80 pixels

**Rotation:**
- Can be rotated like any object
- Slightly angled by default? (random -5° to +5°)

### Index Cards

**Visual Characteristics:**
- Edge style options:
  - Clean cut (default)
  - Torn/distressed edges
  - Rounded corners
  - Perforated edge
- Thicker appearance than strips
- Can be kraft, white, colored
- Visible lines (ruled, grid, blank options)
- Corner wear/aging optional
- Pushpin or clip at top

**Customization:**
- **Sketch on cards:** Draw directly with stylus
- **Highlight sections:** Color overlay tool
- **Change pushpin style:** Thumbtack, binder clip, washi tape, etc.
- **Add stickers/stamps:** From permanent collection
- **Color the entire card:** Background tint
- **Texture overlay:** See texture/pattern/effect system below
- **Edge treatment:** Clean, torn, rounded, perforated

**Sizes:**
- Small: 3x5 ratio (~240x144px)
- Medium: 4x6 ratio (~320x192px)  
- Large: 5x7 ratio (~400x280px)
- Custom: User can resize freely

### Card Appearance Customization

Cards have three independent customization dimensions that can be combined:

**1. TEXTURE (Surface Feel):**
- **Smooth:** Default, clean paper surface
- **Linen:** Woven fabric texture
- **Rough/Kraft:** Brown kraft paper with visible fibers
- **Watercolor:** Slightly textured art paper
- **Recycled:** Speckled, eco paper look

**2. PATTERN (Grid/Lines):**
- **Blank:** No lines or grid
- **Ruled:** Horizontal lines for writing
- **Graph:** Grid pattern (square)
- **Dot Grid:** Bullet journal style dots
- **Isometric:** For technical drawings
- **Music Staff:** For musical notation

**3. EFFECTS/HUE (Aging/Staining):**
- **Clean:** No effects, pristine
- **Aged/Yellowed:** Vintage paper tone
- **Coffee Stain:** Brown ring marks
- **Water Damage:** Rippled/warped edges
- **Ink Blot:** Small ink splatter marks
- **Sun Faded:** One edge lighter than other
- **Sepia Tone:** Overall warm brown tint
- **Tea Stained:** Light brown, slightly mottled

**Combining Dimensions:**
Example: "Rough kraft texture + dot grid pattern + coffee stain effect"
Example: "Linen texture + ruled pattern + aged yellowing"
Example: "Smooth texture + blank + sepia tone"

**UI for Customization:**
```
Card Settings
├─ Texture: [Smooth] [Linen] [Rough] [Watercolor] [Recycled]
├─ Pattern: [Blank] [Ruled] [Graph] [Dot] [Isometric] [Music]
└─ Effects:  [Clean] [Aged] [Coffee] [Water] [Ink] [Faded] [Sepia] [Tea]
```

Users can mix and match to create their perfect aesthetic!

### Manila Folder (Card Detail View)

**Opening Animation:**
- Card scales up and moves toward viewer
- Hinged at left edge
- Swings open like a real folder
- Smooth 3D transform over ~500ms
- Background dims/blurs slightly

**When opened:**
- Full-screen manila folder aesthetic
- Tab at top with card title
- Interior shows:
  - Main task list (with nesting)
  - Fold-over note section (tall slip of paper)
  - **Other cards can be inside!** (nested sub-projects)
  - Tags displayed
  - Any sketches/images on card
  
**Cards within folders:**
- Smaller cards visible inside
- Can be moved, rotated, edited
- Can themselves be opened (folder within folder!)
- Visual: Looks like papers organized in a file folder

**Interaction:**
- Swipe down to close (or back button)
- Closing animation: folder swings closed, shrinks back to position
- Edit inline
- Rearrange subtasks
- Add new items or cards

---

## Conspiracy Strings (Connections)

### Visual Design

**String Types (user selectable):**
- Red thread (classic conspiracy!)
- Natural twine
- Colored yarn
- Ribbon
- String lights (festive!)

**Visual Properties:**
- Bezier curve between cards (not straight line)
- Slightly loose/organic feel
- Can cross over/under other elements
- Shadow underneath string
- Animated on creation (draws from point A to B)

### Connection Types

**Dependency (blocking):**
- Thicker string
- Red or orange color
- Arrow pointing to dependent item
- "Can't do X until Y done"

**Thematic Link:**
- Regular string
- Any color
- No directionality
- "These are related"

**Free Association:**
- Thinnest string  
- Subtle color
- Dashed line
- "Brain says connect"

### Kraft Paper Tags

**On the string itself:**
- Small kraft paper tag hanging on string
- Can write note on tag
- Explains the connection
- Click to edit

**Visual:**
```
Card A ----🏷️"depends on"---- Card B
```

### Interaction

**Creating Connection:**
1. Select card A
2. Tap "Connect" button
3. Tap card B
4. Choose connection type
5. Optional: Add note

**Editing Connection:**
- Click string to select
- Change style/color
- Add/edit tag note
- Delete connection

---

## Decorative Objects System

### Purpose

**Functional:**
- Memory aids (crystal = meditation task)
- Visual bookmarks (flower marks important card)
- Organizational signifiers

**Aesthetic:**
- Make workspace beautiful
- Personal expression
- Reduce sterility

### Object Types

**Natural Elements:**
- Crystals (various types)
- Dried flowers/botanicals
- Feathers
- Stones/pebbles
- Leaves

**Desk Items:**
- Coffee/tea cup
- Candle
- Pen/pencil
- Scissors
- Wax seal
- Vintage stamps

**Mystical:**
- Tarot cards
- Runes
- Small bottles/vials
- Keys

### Object Behavior

**Placement:**
- Drag from palette onto canvas
- Can be rotated (everything can rotate!)
- Can be resized
- Can overlap cards or sit alone
- Have their own shadows

**Customization:**
- Users can upload their own PNG objects
- Create collections of favorite objects
- Share object packs (future)

**Permanent Palette:**
- Dedicated drawer/panel for objects
- Organized by collection
- Search/filter
- Recently used section

---

## Canvas Drawing

### Direct Drawing on Canvas

**Draw freely directly on the workspace!**

**Tool Options:**
- Pen (various thicknesses)
- Pencil (sketchy feel)
- Highlighter (semi-transparent)
- Eraser

**Use Cases:**
- Circle related cards
- Draw arrows between items
- Sketch quick diagrams
- Add flourishes
- Make it personal!

**Z-Ordering (Layer Control):**
- **Default placement:** Below cards, above canvas background
- **Not layer-locked!** Can adjust drawing position in Z-order:
  - "Send to Back" (above canvas, below everything)
  - "Bring to Front" (above all cards)
  - "Bring Forward" / "Send Backward" (fine adjustments)
- Each drawing stroke is an independent object
- Can select drawing and change its layer position
- Useful for:
  - Highlighting: Draw above cards
  - Background sketches: Draw below cards
  - Connecting diagrams: Adjust as needed

**Implementation:**
- Drawing objects exist in same Z-space as cards
- Each stroke has a `zIndex` property
- Can be reordered just like cards
- Selection shows current layer position

**Interaction:**
- Apple Pencil / stylus support (pressure sensitive!)
- Palm rejection
- Undo/redo for drawings
- Select drawing stroke(s) to:
  - Delete
  - Change color
  - Change layer position
  - Move
  - Group with other strokes

---

## Undo/Redo System

### Comprehensive Undo

**Undo should undo EVERYTHING:**
- Creating a card ✓
- Creating a strip ✓
- Pasting ✓
- Moving objects ✓
- Rotating objects ✓
- Drawing ✓
- Changing colors ✓
- Deleting ✓
- Linking/unlinking ✓

### Visual Feedback

**Toast Notification on Undo:**
```
┌─────────────────────┐
│  ↶ Undid: Create Card │
└─────────────────────┘
```

**History Panel:**
- Panel showing last 50 actions with timestamps
- Two undo modes:
  
  **Mode 1: Undo to Point (Sequential)**
  - Click any action in history
  - Undoes that action AND everything after it
  - "Undo back to here"
  - Use when: Want to revert to earlier state
  
  **Mode 2: Selective Undo (Non-Sequential)**  
  - Right-click/long-press specific action
  - Undoes ONLY that action
  - Leaves earlier and later actions intact
  - Use when: Want to remove one mistake without losing subsequent work
  - Example: "I moved that card wrong 10 steps ago, but I want to keep the 9 things I did after"

**Visual Indicators:**
- Grayed out actions = already undone
- Highlighted action = current state
- Warning if selective undo might cause conflicts

**Minimap Indicator:**
- When undo affects area outside current view
- Minimap highlights affected region
- Brief flash/glow shows location
- Pan to location button

**Implementation:**
```dart
class ActionHistory {
  final List<Action> actions = [];
  final Set<String> selectivelyUndone = {};
  
  // Sequential undo to point
  void undoToPoint(int index) {
    for (int i = actions.length - 1; i >= index; i--) {
      if (!selectivelyUndone.contains(actions[i].id)) {
        actions[i].undo();
      }
    }
    actions.removeRange(index, actions.length);
  }
  
  // Selective undo of single action
  void undoSelective(String actionId) {
    final action = actions.firstWhere((a) => a.id == actionId);
    
    // Check for dependency conflicts
    if (hasConflicts(action)) {
      showWarning("Undoing this may affect later actions");
    }
    
    action.undo();
    selectivelyUndone.add(actionId);
  }
  
  void recordAction(Action action) {
    actions.add(action);
    if (actions.length > 100) {
      actions.removeAt(0);
    }
  }
  
  void standardUndo() {
    // Regular undo button - sequential
    if (actions.isEmpty) return;
    
    final action = actions.removeLast();
    action.undo();
    
    showUndoFeedback(action.description);
    
    if (!isInViewport(action.affectedArea)) {
      highlightOnMinimap(action.affectedArea);
    }
  }
}
```

**Conflict Detection:**
When selective undo might cause issues:
- Undoing card creation when it has later connections added
- Undoing card move when it was later linked to others
- Show warning but allow user to proceed
- Smart resolution: "Also undo dependent actions?"

---

## Paper Textures

### Texture Options

**For Cards:**
- Smooth (default)
- Linen
- Aged/vintage
- Recycled
- Graph paper
- Dot grid
- Ruled lines

**For Canvas:**
- Wood grain (theme dependent)
- Cork board
- Linen fabric
- Marble
- Solid colors

### User Upload

- Upload custom texture images
- Tile or scale to fit
- Adjustable opacity
- Save as preset

---

## Advanced Features

### Change Selected Object Color

**Select object(s) → Pick new color → Updates immediately**

No need to recreate or edit settings!

**What can be recolored:**
- Card background
- Strip color
- Text color
- Drawing color
- Connection string color
- Object tints (if applicable)

### Light Mode for Drawers

**Problem Solved:** Dark drawers make dark icons invisible

**Solution:**
- Drawer adapts to theme
- Light themes → light drawer
- Dark themes → dark drawer
- Icons have contrasting borders/backgrounds
- Preview thumbnails always visible

### Custom Folder/Container Shapes

**Different "containers" for card groups:**
- Standard rectangle
- Circle
- Cloud shape
- Hexagon
- Hand-drawn irregular shape

**Use:**
- Visual grouping without rigid structure
- Thematic organization
- Fun personalization

---

## Multi-Device Strategy

### Phone (Primary - Galaxy)

**Optimizations:**
- Text-only view toggle (strip all aesthetic for speed!)
- Quick capture widget
- Simplified lighting (optional)
- Touch-optimized: larger tap targets
- Voice input for rapid entry

**What Works:**
- Creating strips/cards
- Checking off tasks
- Viewing workspace (pan/zoom)
- Basic editing

**What's Limited:**
- Drawing (screen too small for detail)
- Complex spatial reorganization
- Aesthetic customization

### iPad (Secondary - Organization & Beauty)

**Optimizations:**
- Full aesthetic experience
- Drawing with Apple Pencil
- Spatial reorganization
- Theming and customization
- Explosion/stacking views

**Ideal For:**
- Weekly organization sessions
- Making workspace beautiful
- Deep work with nested tasks
- Connecting cards with strings

### Desktop (Tertiary - Linux)

**Optimizations:**
- Keyboard shortcuts (robust!)
- Precision with mouse
- Larger canvas view
- Multiple windows/tabs?
- Export/backup tools

---

## Flippable Pages & Documents (Stretch Goal)

**The Ultimate Dream:**

### Single Card Flipping

**Concept:** Make cards "flippable" like physical index cards.

**Front:** Task list, title, visual
**Back:** Notes, sketches, additional info

**Interaction:**
- Click flip icon on card
- Smooth 3D flip animation
- Back has different content
- Indicators show "there's more on back"

**Use Cases:**
- Quick reference on front, details on back
- Visual on front, text on back
- Current state on front, archive on back
- Question on front, answer on back (flashcards!)

### Multi-Page Document Viewing

**The Priority: PDF and Multi-Page Documents**

When a card contains a multi-page PDF or document:

**Spread View:**
- Two pages displayed side-by-side (like an open book)
- Left page and right page visible simultaneously
- Realistic book-reading experience

**Page Turning Animation:**
- Smooth page curl animation
- Pages turn from right to left (or left to right if going back)
- 3D effect with realistic page physics
- Sound effect optional (subtle paper rustle)

**Navigation:**
- Swipe/drag to turn page
- Page number indicator (Page 3-4 of 24)
- Jump to page option
- Thumbnails view (see all pages as grid)
- Bookmarks for important pages

**Interaction:**
- Zoom into current spread
- Highlight and annotate on pages
- Search within document
- Extract page as separate card

**Visual Details:**
- Page curl reveals next page underneath
- Shadow cast by curling page
- Realistic page thickness
- Book spine visible between pages

### Technical Implementation

**Single Card Flip:**
```dart
class FlippableCard extends StatefulWidget {
  bool showingFront = true;
  
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          showingFront = !showingFront;
        });
      },
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 600),
        transitionBuilder: (child, animation) {
          return FlipTransition(
            animation: animation,
            child: child,
          );
        },
        child: showingFront ? cardFront : cardBack,
      ),
    );
  }
}
```

**Multi-Page Document:**
```dart
class DocumentSpreadView extends StatefulWidget {
  List<Page> pages;
  int currentSpreadIndex = 0; // 0 = pages 0-1, 1 = pages 2-3, etc.
  
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dx > 0) {
          // Swipe right - previous page
          turnPageBackward();
        } else {
          // Swipe left - next page
          turnPageForward();
        }
      },
      child: PageCurlAnimation(
        leftPage: pages[currentSpreadIndex * 2],
        rightPage: pages[currentSpreadIndex * 2 + 1],
        onTurnComplete: () {
          // Update spread index
        },
      ),
    );
  }
}
```

### Use Cases

**For PDFs:**
- Research papers
- Instruction manuals
- Book chapters
- Photo albums
- Comic books/graphic novels

**For Multi-Card Documents:**
- Meeting notes with multiple pages
- Project documentation
- Sketchbooks
- Journals with entries

**Visual Realism:**
- Paper texture on pages
- Natural page curl physics
- Depth and shadow
- Binding visible
- Page thickness accumulates (thicker stack on turned side)

### Technical Challenge

**Performance Considerations:**
- Pre-render adjacent pages
- Use texture atlases for pages
- Limit 3D calculations to visible spread
- Cache turned pages
- Optimize for iPad (primary use case for reading)

**Memory Management:**
- Load spread + 1 page before/after
- Unload pages far from current view
- Compress non-visible pages
- Stream large PDFs

---

## Accessibility Considerations

### Visual

- High contrast mode option
- Adjustable text sizes
- Screen reader support for all elements
- Keyboard navigation (desktop)
- Voice control support

### Motor

- Adjustable gesture sensitivity
- Tap target size settings
- Undo safety (hard to accidentally delete)
- Confirm dialogs for destructive actions

### Cognitive

- Simple mode: Hide advanced features
- Tutorial/onboarding
- Contextual help
- Consistent patterns throughout app

---

## Performance Optimization Strategy

### Rendering

**Viewport Culling:**
- Only render cards in current view + margin
- Unload off-screen complex elements
- Keep data in memory but not rendered

**LOD (Level of Detail):**
- Far away: Simple rectangles
- Medium distance: Basic card with text
- Close up: Full detail, shadows, textures

**Caching:**
- Cache rendered card states
- Cache shadow calculations
- Reuse texture instances

### Memory Management

**Lazy Loading:**
- Load workspace sections on demand
- Unload unused decorative objects
- Stream in images as needed

**Asset Optimization:**
- Compress textures
- Use SVG where possible
- Multiple resolution assets (1x, 2x, 3x)

### Battery Optimization

**Smart Updates:**
- Reduce animation frame rate when idle
- Pause lighting updates in background
- Batch state changes
- Debounce rapid actions

---

## Summary: Key Differentiators

**What makes Pin and Paper special:**

1. **Rotation as primary organizational tool** - Individual objects can be rotated freely
2. **Dynamic, time-based lighting** creates living workspace
3. **Deep customization** without overwhelming
4. **Spatial intelligence** - position means something
5. **Aesthetic as function** - reduces ADHD stress
6. **Zero friction capture** on phone, beautiful organization on tablet
7. **Linking/stacking/exploding** for complex relationships
8. **Draw on canvas** freely with flexible Z-ordering
9. **Selective undo** - undo specific actions without losing later work
10. **Consciousness supporting consciousness** - AI help when needed

**Critical Problems Solved:**
✓ Individual object rotation (not just workspace rotation)
✓ Comprehensive undo with visual feedback and selective mode
✓ Drawer visibility with proper contrast
✓ Linking objects together for group movement
✓ Explode view for examining stacked items
✓ Direct canvas drawing with layer control
✓ Flexible color palette management
✓ Full range image resizing
✓ Cards can have torn/distressed edges
✓ Three-dimensional card customization (texture + pattern + effects)

**Our Unique Innovations:**
✓ Time-based aesthetic that evolves throughout the day
✓ ADHD-optimized with zero-friction phone capture
✓ API-first for seamless AI integration
✓ Multi-page document viewing with realistic page turns
✓ Multiple devices working in harmony
✓ Manila folder opening animation
✓ Cards within cards within folders  

---

## Next Steps for Code Claude

**Phase 1 Visual Priorities:**
1. Implement rotation for all objects
2. Basic lighting overlay system
3. Card customization (colors, sizes)
4. Torn strip rendering
5. Shadow system

**Phase 2 Interaction Priorities:**
1. Linking/unlocking card groups
2. Canvas drawing layer
3. Connection strings with tags
4. Decorative objects system
5. Comprehensive undo with feedback

**Phase 3 Polish:**
1. Time-based dynamic lighting
2. Explode stack view
3. Flippable cards
4. Advanced textures
5. Performance optimization

---

*From chaos to clarity, one beautifully rotated index card at a time.* 🍂✨📌
