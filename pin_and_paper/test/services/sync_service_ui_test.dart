import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pin_and_paper/services/database_service.dart';
import 'package:pin_and_paper/services/sync_service.dart';
import '../helpers/test_database_helper.dart';

/// Phase 4.0: Tests for sync UI integration points.
///
/// Tests the callbacks and public API surface that the Settings screen
/// and HomeScreen use to interact with SyncService.
///
/// RED phase — these tests define the contract before implementation.
void main() {
  group('SyncService — UI integration', () {
    setUpAll(() {
      TestDatabaseHelper.initialize();
    });

    late Database testDb;
    late SyncService syncService;

    setUp(() async {
      testDb = await TestDatabaseHelper.createTestDatabase();
      DatabaseService.setTestDatabase(testDb);
      await TestDatabaseHelper.clearAllData(testDb);

      syncService = SyncService.testInstance(testDb);
    });

    // ═══════════════════════════════════════
    // onSyncComplete CALLBACK
    // ═══════════════════════════════════════

    group('onSyncComplete', () {
      test('field exists and is initially null', () {
        // onSyncComplete is a VoidCallback? that the Settings screen
        // wires to refresh the "Last synced" timestamp.
        expect(syncService.onSyncComplete, isNull);
      });

      test('can be set and cleared', () {
        var callCount = 0;
        syncService.onSyncComplete = () => callCount++;

        expect(syncService.onSyncComplete, isNotNull);

        // Invoke to verify it's callable
        syncService.onSyncComplete!();
        expect(callCount, 1);

        // Clear
        syncService.onSyncComplete = null;
        expect(syncService.onSyncComplete, isNull);
      });
    });
  });
}
