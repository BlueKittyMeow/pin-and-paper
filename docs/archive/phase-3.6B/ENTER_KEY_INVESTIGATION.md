# Enter Key Investigation - Search Dialog Tag Filter

## Problem Statement

**Goal**: When the user is in the search dialog's tag filter view (NOT typing in the search field), pressing Enter should trigger the "Apply active tags" button.

**Current Status**: ❌ NOT WORKING despite multiple approaches

**What DOES Work**: Escape key closes the dialog perfectly (built-in Dialog behavior)

## User Workflow

1. User opens search dialog (has tag filters at bottom)
2. User clicks "Apply active tags" button OR selects tags
3. User clicks somewhere in the dialog (empty space, tag chips, etc.) - NOT in search field
4. User presses Enter
5. **Expected**: "Apply active tags" should be triggered
6. **Actual**: Nothing happens

## Key Constraints

- **MUST NOT** interfere with search field Enter behavior (search field Enter = perform search)
- **MUST** only trigger when search field is NOT focused
- **MUST** work when clicking anywhere in dialog except search field

## What Works: Escape Key

The Escape key works perfectly and closes the dialog. This is Flutter's built-in Dialog behavior using:
- `Shortcuts` widget
- `Actions` widget
- `DismissIntent`

The Escape mechanism is our reference point since it works reliably.

## Attempts Made

### Attempt 1: Focus Widget with onKeyEvent

**Approach**: Wrap Dialog with Focus widget and use onKeyEvent callback.

**Code**:
```dart
return Focus(
  onKeyEvent: (node, event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !_searchFocusNode.hasFocus) {
      _applyActiveTagFilters();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  },
  child: Dialog(...),
);
```

**Result**: ❌ Did not work

**Hypothesis**: Focus widget didn't have focus, so onKeyEvent never fired.

---

### Attempt 2: CallbackShortcuts

**Approach**: Use CallbackShortcuts widget to define keyboard shortcuts.

**Code**:
```dart
return CallbackShortcuts(
  bindings: {
    const SingleActivator(LogicalKeyboardKey.enter): () {
      if (!_searchFocusNode.hasFocus) {
        _applyActiveTagFilters();
      }
    },
  },
  child: Focus(
    autofocus: true,
    child: Dialog(...),
  ),
);
```

**Result**: ❌ Did not work

**Hypothesis**: CallbackShortcuts requires something in focus tree to activate, similar to Shortcuts widget.

---

### Attempt 3: KeyboardListener

**Approach**: Use KeyboardListener widget with its own FocusNode and autofocus.

**Code**:
```dart
final _keyboardListenerFocusNode = FocusNode();

return KeyboardListener(
  focusNode: _keyboardListenerFocusNode,
  autofocus: true,
  onKeyEvent: (KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !_searchFocusNode.hasFocus) {
      _applyActiveTagFilters();
    }
  },
  child: Dialog(...),
);
```

**Result**: ❌ Did not work

**Hypothesis**: KeyboardListener's focus node competed with TextField focus, or Dialog intercepted events first.

---

### Attempt 4: Shortcuts + Actions (Outside Dialog)

**Approach**: Use Shortcuts + Actions pattern (same as Escape) wrapping the Dialog.

**Code**:
```dart
class ApplyTagsIntent extends Intent {
  const ApplyTagsIntent();
}

return Shortcuts(
  shortcuts: <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.enter): const ApplyTagsIntent(),
  },
  child: Actions(
    actions: <Type, Action<Intent>>{
      ApplyTagsIntent: CallbackAction<ApplyTagsIntent>(
        onInvoke: (ApplyTagsIntent intent) {
          if (!_searchFocusNode.hasFocus) {
            _applyActiveTagFilters();
          }
          return null;
        },
      ),
    },
    child: Dialog(...),
  ),
);
```

**Result**: ❌ Did not work

**Hypothesis**: Shortcuts widget outside Dialog didn't have focus scope to capture events.

---

### Attempt 5: Shortcuts + Actions + Focus (Inside Dialog) - CURRENT

**Approach**: Move Shortcuts/Actions INSIDE Dialog and add explicit Focus widget with autofocus.

**Code**:
```dart
class ApplyTagsIntent extends Intent {
  const ApplyTagsIntent();
}

return Dialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  clipBehavior: Clip.antiAlias,
  child: Shortcuts(
    shortcuts: <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.enter): const ApplyTagsIntent(),
    },
    child: Actions(
      actions: <Type, Action<Intent>>{
        ApplyTagsIntent: CallbackAction<ApplyTagsIntent>(
          onInvoke: (ApplyTagsIntent intent) {
            if (!_searchFocusNode.hasFocus) {
              _applyActiveTagFilters();
            }
            return null;
          },
        ),
      },
      child: Focus(
        autofocus: true,  // Ensure shortcuts are active
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchField(),
              _buildScopeFilters(),
              _buildTagFilters(),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    ),
  ),
);
```

**Widget Hierarchy**:
```
Dialog
└─ Shortcuts (Enter → ApplyTagsIntent)
   └─ Actions (handles ApplyTagsIntent)
      └─ Focus (autofocus: true)
         └─ Container (dialog content)
            ├─ AppBar
            ├─ TextField (_searchFocusNode)
            ├─ Scope filters
            ├─ Tag filters (Apply active tags button)
            └─ Results
```

**Result**: ❌ Still does not work

**Hypothesis**: ???

---

### Attempt 6: FocusScope + GestureDetector (Gemini Solution 1 + Codex) - CURRENT

**Approach**: Use FocusScope with onKeyEvent (Gemini's recommended approach) combined with GestureDetector to explicitly move focus (Codex's suggestion). Applied to **tag_filter_dialog.dart** (the CORRECT dialog - opened from filter icon in AppBar).

**Code** (`lib/widgets/tag_filter_dialog.dart`):
```dart
class _TagFilterDialogState extends State<TagFilterDialog> {
  final FocusNode _searchFocusNode = FocusNode(); // Track search field focus

  // Method to apply filter (extracted for reuse)
  void _applyFilter() {
    HapticFeedback.mediumImpact();
    final filter = FilterState(
      selectedTagIds: _selectedTagIds.toList(),
      logic: _logic,
      presenceFilter: _presenceFilter,
    );
    Navigator.pop(context, filter);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Tags'),
      content: GestureDetector(
        // Codex: Explicitly move focus when tapping outside TextField
        onTap: () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: FocusScope(
          // Gemini: FocusScope with onKeyEvent intercepts events at dialog scope level
          onKeyEvent: (node, event) {
            // Handle both Enter and numpad Enter (Codex suggestion)
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                 event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
              // Gemini: Use primaryFocus for reliable focus checking
              if (FocusManager.instance.primaryFocus != _searchFocusNode) {
                debugPrint('Enter pressed outside search field. Applying filter.');
                _applyFilter();
                return KeyEventResult.handled; // Stop propagation
              }
            }
            return KeyEventResult.ignored;
          },
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode, // Attach focus node
                  // ... search field content
                ),
                // ... rest of dialog content
              ],
            ),
          ),
        ),
      ),
      actions: [
        // ...
        FilledButton(
          onPressed: _applyFilter, // Same method called by Enter key
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
```

**Widget Hierarchy**:
```
AlertDialog
└─ content: GestureDetector (onTap unfocuses search, opaque behavior)
   └─ FocusScope (onKeyEvent intercepts Enter keys)
      └─ SizedBox
         └─ Column
            ├─ TextField (with _searchFocusNode)
            ├─ SegmentedButtons (tag presence filters)
            ├─ SegmentedButtons (AND/OR logic)
            └─ ListView (tag checkboxes)
```

**Why this should work** (according to Gemini & Codex):
- **FocusScope.onKeyEvent**: Intercepts keyboard events for entire dialog scope before they reach specific widgets
- **GestureDetector**: Explicitly removes focus from TextField when clicking elsewhere, ensuring Enter isn't consumed by TextField
- **primaryFocus check**: More reliable than `hasFocus` - checks what actually has focus system-wide
- **Both Enter keys**: Handles regular Enter AND numpad Enter
- **KeyEventResult.handled**: Stops event propagation so TextField can't consume it

**Result**: ❌ Still does not work

**Hypothesis**:
- AlertDialog might handle keyboard events differently than custom Dialog
- TextField's internal focus handling might be even more aggressive than expected
- Linux-specific issue with GTK event handling?
- FocusScope onKeyEvent might not fire if AlertDialog has its own focus management

**Additional observations**:
- Escape key works perfectly (built-in AlertDialog behavior)
- Same code pattern works for Dialog in search_dialog.dart (though that was wrong dialog for this feature)
- No error messages in console
- Debug print statement never fires, suggesting onKeyEvent never receives the event

---

## Key Questions for Investigation

1. **Why does Escape work but Enter doesn't?**
   - Escape is handled by Dialog internally
   - Does Dialog have special focus handling we're missing?
   - Does Dialog intercept all keyboard events before our Shortcuts?

2. **Focus Tree Issues?**
   - Is TextField stealing all Enter key events even when not focused?
   - Does AppBar or other widgets in the tree intercept Enter?
   - Is there a focus scope issue?

3. **TextField Interference?**
   - The TextField uses `_searchFocusNode` for focus tracking
   - TextField has `onSubmitted` callback for Enter key
   - Could TextField be capturing Enter globally even when unfocused?

4. **Event Propagation?**
   - Are Enter key events being consumed before reaching Shortcuts?
   - Is there a widget between Focus and TextField consuming events?

## Code Context

### Search Field Implementation

```dart
Widget _buildSearchField() {
  return Padding(
    padding: EdgeInsets.all(16),
    child: TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,  // ← Focus tracking
      autofocus: true,              // ← Gets focus on dialog open
      decoration: InputDecoration(
        hintText: 'Search titles, notes, tags...',
        prefixIcon: Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _debounceTimer?.cancel();
                  setState(() {
                    _results = [];
                    _breadcrumbs = {};
                  });
                },
              )
            : null,
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => _debouncedSearch(),
      onSubmitted: (value) {         // ← Enter in search field
        _debounceTimer?.cancel();
        _performSearch();
      },
    ),
  );
}
```

### Apply Active Tags Function

```dart
void _applyActiveTagFilters() {
  final taskProvider = context.read<TaskProvider>();
  final activeFilters = taskProvider.filterState;

  if (activeFilters.selectedTagIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No active tag filters to apply')),
    );
    return;
  }

  setState(() {
    _tagFilters = FilterState(
      selectedTagIds: activeFilters.selectedTagIds,
      logic: activeFilters.logic,
      presenceFilter: activeFilters.presenceFilter,
    );
  });

  _debouncedSearch();
}
```

## Debugging Ideas

1. **Add Debug Print Statements**
   - Add `debugPrint('Enter key received!')` in CallbackAction onInvoke
   - Add `debugPrint('Focus state: ${_searchFocusNode.hasFocus}')`
   - Check if action is even being invoked

2. **Test with Different Keys**
   - Try mapping to a different key (e.g., F1, F2) instead of Enter
   - See if those keys work with Shortcuts/Actions
   - If yes, confirms Enter is being intercepted elsewhere

3. **Remove TextField**
   - Temporarily comment out TextField to see if Enter works
   - If yes, confirms TextField is interfering

4. **Check Focus Tree**
   - Use Flutter DevTools to inspect focus tree
   - See what widget actually has focus when clicking empty space
   - Check if Shortcuts/Actions are in the right focus scope

5. **Check Event Order**
   - Add RawKeyboardListener at Dialog level
   - Log all key events to see what's receiving them
   - Track event propagation order

## Files Involved

- `lib/widgets/tag_filter_dialog.dart` - **CORRECT dialog** (filter icon in AppBar) - where Enter key should work
- `lib/widgets/search_dialog.dart` - Search dialog (search icon in AppBar) - was mistakenly edited first
- `lib/providers/task_provider.dart` - Where filterState lives

## Related Commits

- `f6cf147` - Initial Enter key attempt (fade animation added same commit)
- `97aeeb1` - CallbackShortcuts approach
- `2a86928` - KeyboardListener approach
- `b7571b9` - Shortcuts/Actions approach (outside Dialog)
- `8618498` - Shortcuts/Actions + Focus approach (inside Dialog)
- **NEW commits** (tag_filter_dialog.dart fixes) - Attempt #6 with FocusScope + GestureDetector

## Success Criteria

✅ Enter key triggers "Apply active tags" when:
- Dialog is open
- Search field is NOT focused
- User clicks anywhere in tag filter area
- User presses Enter

✅ Enter key still performs search when:
- Dialog is open
- Search field IS focused
- User types query
- User presses Enter

## Next Steps

1. Consult with Codex/Gemini on this document
2. Try debugging approaches listed above
3. Consider alternative UX if Enter key proves impossible
4. Check if Flutter has known issues with TextField + Shortcuts
