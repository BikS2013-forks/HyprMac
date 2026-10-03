# Issues - Pending Items

## Pending

1. **Native desktop support not yet checked live.** `TilingEngine.syncNativeSpaces` is unit-tested
   (`HyprMacTests/NativeSpaceTreeTests.swift`, 7 tests) but tests do not prove window behavior.
   Confirm on a real Mac with two or more desktops: resize, switch desktops, switch back, and look
   for the `native space change: … restored 1` log line (see `docs/debugging.md`, "Sizes reset after
   switching macOS desktops"). First live run (2026-10-02) found every saved layout dropped on a
   `screenParametersChanged` with unchanged monitors; fixed so only a departed screen's layouts are
   dropped, and rebuilt for a second run. Second live run found windows of the neighbouring desktop
   in the snapshot mid-animation, inserted into the current tree (resetting its ratios); snapshots
   now leave out windows whose Spaces are all inactive. Open risk: if the window server reports the new Space later than the
   on-screen window list changes, one poll could still drop departing windows from the tree before
   it is parked.

2. **A closing window whose neighbour is a stack forgets its boundary.** `BSPNode.remove` keeps the
   vanished split's ratio only when the surviving sibling is a single window. When it is a stack, the
   stack is promoted into the parent's place, the boundary is lost, and a window that comes back
   (Outlook reopens its main window under a new id) lands at the dwindle tip instead of its old slot.
   Fixing it needs a "wrap this subtree" insert path with depth and min-size fit checks. Seen
   2026-10-02 15:19:44 on the Outlook desktop.

3. **15 test classes crash (SIGTRAP, exit 133) on this Mac, also on unmodified `HEAD` (f3e002a).**
   Xcode 27.0 (27A266a), macOS 27. Classes: AdmissionRecoveryTests, CrossMonitorMoveRecoveryTests,
   FitAwareDisplayMigrationTests, FloatingFramePlacementTests, FloatingRaiseRegressionTests,
   FullscreenWorkspaceOrchestratorTests, LayoutRestorerTests, LayoutTreeRebuildTests,
   LayoutTreeSerializeTests, ScratchpadLayerLayoutTests, TilingEngineMembershipTransactionTests,
   TilingEngineSwapRevalidationTests, TilingEngineTiledDragTests, WorkspaceBatchMoveTests,
   WorkspaceFollowTests. Cause not investigated. Because one crash aborts an `All` run, run classes
   one by one until it is fixed.

4. **`scripts/test-isolated.sh` cannot load the test bundle on this Mac.** It exports
   `DYLD_LIBRARY_PATH` and then runs `xcrun xctest`. `xcrun` lives in `/usr/bin`, so macOS strips
   `DYLD_*` and the bundle fails with `Library not loaded: /usr/local/lib/HyprMac.dylib`. Workaround:
   run the build step through the script, then call `"$(xcrun -f xctest)"` directly with the same
   environment. A fix would be to resolve the xctest path with `xcrun -f` inside the script.

## Completed

- **2026-10-04 — Caps Lock works as Caps Lock again when tapped alone.** With Caps Lock remapped to
  F18 as the Hypr key it never toggled. A bare tap (no other key, modifier or mouse press, released
  within `HotkeyManager.bareTapMaxDuration` = 0.5 s) now flips the state through
  `IOHIDSetModifierLockState` (`CapsLockState.toggle`). Only for the Caps Lock Hypr key; works while
  paused and on disabled desktops. Tests in `CapsLockTapTests`. Not yet checked live.

- **2026-10-03 — A full workspace floats new windows instead of spilling.** At capacity, a new
  (unpinned) window floats on the workspace it was opened on rather than going to the next workspace
  with room, which could be on the other display. Pinned apps keep spilling. Tests in
  `RetileAllPlannerTests`.

- **2026-10-03 — New windows spilled to the other display.** All desktops on the monitor share
  HyprMac workspace 1, and hidden windows on the other desktops still reserved tile slots, so
  3 visible + 5 reserved filled ws1's capacity of 8 and an Outlook mail window (83869, 19:35:07)
  went to ws2 on the laptop. Windows on another or disabled desktop no longer reserve a slot.
  Tests in `WindowDiscoveryServiceTests`.

- **2026-10-03 — Per-desktop off switch and new-window placement.** `toggleDesktopTiling`
  (Hypr+Shift+P, menu bar row) and new windows joining the initiator's display. Design in
  `docs/architecture.md` ("Native Spaces") and `docs/keybinds-and-actions.md`. Not yet checked live.
  Known limits: windows an app opens on its own (e.g. reminders) follow whatever window had focus;
  a desktop's uuid is what is saved, so recreating a desktop in Mission Control makes a new one.

- **2026-10-03 — Hypr+F (move to dedicated workspace) always rolled back.** Parking the source
  workspace's other windows required their size unchanged, but the parking corner sits on the laptop
  display (949pt usable), which is shorter than the windows, so macOS shrank them and the park was
  rejected (`position-only park rejected … hidden=false`, log 2026-10-03 07:01:17). A hidden window
  whose size changed is now accepted once its frame settles (`TilingEngine.parkStableSamples`).
  Tests in `FullscreenWorkspaceTransferTests.swift` (they sit in a class that crashes as a whole on
  this Mac, item 3; run them by name).

- **2026-10-02 — Any new window reset every user-sized split in its tree.** `updateTreeMembership`
  ran `clearUserSetRatios()` on the whole tree whenever it inserted a window, so a mail window,
  reminder or reopened main window reset the layout (live log 15:19:55, Outlook window 53108). Now
  only the new split starts at the default; user-sized splits keep their ratio. Tests:
  `RatioMemoryEngineTests.testANewWindowKeepsTheUsersRatioOnExistingSplits` and
  `testAWindowReopenedUnderANewIDKeepsTheStacksRatio`. Swaps still reset every ratio by design
  (`TilingEngine` swap path).

- **2026-10-02 — Switching macOS desktops reset tiled window sizes.** Windows on an inactive native
  Space leave the on-screen list (`AccessibilityManager.cgWindowsByPID` uses `.optionOnScreenOnly`).
  Discovery marked them hidden, `removeWindowID` pulled them from the shared workspace tree, and on
  return they were re-inserted with default ratios. Fix: the engine parks each screen's trees per
  native Space and restores them on return (`TilingEngine.syncNativeSpaces`, wired into
  `WindowManager.pollWindowChanges`, `tileAllVisibleSpaces` and `activeSpaceDidChange`). Design in
  `docs/architecture.md`, "Native Spaces". Live check still pending (item 1).
