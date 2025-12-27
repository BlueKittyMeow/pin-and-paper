# Phase 3.2 Integration Tests

Comprehensive integration tests for hierarchical task features including drag-and-drop, breadcrumb navigation, and CASCADE delete.

## Test Coverage

### Drag and Drop Reordering (6 tests)
- ✅ Create parent and child tasks
- ✅ Sibling reordering bug fix - drag to position 0
- ✅ Reorder multiple times within same parent

### Breadcrumb Navigation (2 tests)
- ✅ Breadcrumbs show navigation path
- ✅ Clicking breadcrumb navigates back

### CASCADE Delete (3 tests)
- ✅ Delete parent with children shows confirmation
- ✅ Confirming delete removes parent and all children
- ✅ Delete does not affect unrelated tasks

### Edge Cases (2 tests)
- ✅ Maximum nesting depth (4 levels)
- ✅ Reordering with empty list

## Running Integration Tests

### Option 1: Using flutter drive (RECOMMENDED for devices)
```bash
# Most reliable for real devices
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/phase_3_2_integration_test.dart \
  -d <device_id>
```

### Option 2: On desktop/emulator
```bash
flutter test integration_test/phase_3_2_integration_test.dart
```

### Option 3: On real Android device via USB
```bash
# Find your device ID
flutter devices

# Connect via USB (more stable than WiFi)
# Run on specific device
flutter test integration_test/phase_3_2_integration_test.dart -d <device_id>
```

### Known Issues

**WiFi Connection Timeout:**
Integration tests may fail on Android devices over WiFi with `WebSocketChannelException`. This is a known Flutter limitation. Solutions:
- Use USB connection instead of WiFi
- Use `flutter drive` instead of `flutter test`
- Run on emulator/desktop platform

## Test Philosophy

These tests simulate real user interactions:
- **Tap** - Simulates finger taps
- **Long-press** - Simulates holding down on a widget
- **Drag** - Simulates drag gestures with calculated offsets
- **Enter text** - Simulates typing
- **Pump and settle** - Waits for animations to complete

## Debugging Failed Tests

If a test fails unexpectedly:

1. **Run the specific test in isolation:**
   ```bash
   flutter test integration_test/phase_3_2_integration_test.dart \
     --plain-name "test name here"
   ```

2. **Add screenshots:**
   ```dart
   await binding.takeScreenshot('step_name');
   ```

3. **Add debug prints:**
   ```dart
   debugPrint('Current state: ${tester.widget(...)}');
   ```

4. **Write a new focused test** to investigate the specific scenario

## Known Limitations

- Integration tests require a running app instance
- Tests depend on UI structure (changes to widget tree may break tests)
- Drag gestures use calculated offsets (screen size dependent)
- Some tests may be timing-sensitive (increase `pumpAndSettle` duration if flaky)

## Test Maintenance

When UI changes:
- Update finders (`find.text()`, `find.byIcon()`, etc.)
- Adjust drag offsets if layout changes
- Update expected widget counts
- Re-verify test assertions match new behavior
