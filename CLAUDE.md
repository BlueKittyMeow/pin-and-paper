# pin-and-paper — session notes

## Running tests (IMPORTANT)

Use the wrapper, not bare `flutter test`, for anything bigger than a single file:

```bash
./run-tests.sh              # full suite, serialized + concurrency-capped
./run-tests.sh test/screens # subset
```

**Why:** full-suite `flutter test` runs on MysteryOfGlass have "hung" forever
displaying `canvas_screen_test.dart: (tearDownAll)` (or whichever suite label
happened to be on screen last). That display is a red herring — the tests all
pass. The real failure is flutter_tools' shared incremental compiler
(frontend_server) silently wedging/starving mid-run, which stalls every
not-yet-loaded test file; the compact reporter then redraws the last visible
label forever (or, if the loads got far enough to start, they each die with a
12-minute `loading <file>` TimeoutException). Diagnosed 2026-08-06: the JSON
reporter showed every started suite completing — including canvas's
tearDownAll — with only `loading <file>` pseudo-tests pending; the verbose log
showed a `<- recompile` request the compiler never answered.

Triggers, in order of impact:

1. **Disk: the root partition (which holds /tmp) runs chronically ~100%
   full.** `flutter test` writes a ~55 MB kernel dill into
   `/tmp/flutter_tools.*` per test file, several at a time, plus a 54 MB
   copy into `build/test_cache/`. With the partition full, the compiler
   crashes ("The Dart compiler exited unexpectedly." — or wedges silently
   when it dies while idle, because flutter_tools' death check lives in an
   unawaited future). Single-file runs fit in the leftover space, which is
   why "the file passes standalone". Killed runs leak their
   `/tmp/flutter_tools.*` dirs, making the next run more likely to die.
   The wrapper redirects TMPDIR to `~/.cache/flutter-test-tmp` (on the
   bigger /home partition), preflights 2 GB free, and sweeps stale scratch.
2. **Two `flutter test` runs in the same checkout at once** (e.g. two Claude
   sessions, or a forgotten background run). They race over
   `build/test_cache/*.dill` shared incremental-compile state. The wrapper's
   flock prevents this.
3. **Memory/CPU pressure.** Default `flutter test` spawns `cores-2` = 10
   flutter_tester processes (~0.5 GB each) on this 15 GB machine, which is
   usually already deep in swap from Claude sessions — and a Gradle
   `flutter build apk` daemon can hold another 8 GB. The wrapper caps test
   concurrency at 4 (`CONCURRENCY=n ./run-tests.sh` to override).

If a run does hang: kill it, then check for orphans —
`pgrep -af "flutter_tools.snapshot test|flutter_tester|frontend_server_aot"`.
Note `timeout N flutter test` orphans the dart process (timeout kills only the
bash wrapper script); kill the dart PID directly.

Test DBs are true in-memory sqlite (see `test/helpers/test_database_helper.dart`).
If files named `:memory:_test_*` ever accumulate under
`pin_and_paper/.dart_tool/sqflite_common_ffi/databases/`, the helper regressed.
