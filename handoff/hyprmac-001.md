# Handoff — hyprmac-001

Focus: the customizations made to HyprMac (fork of upstream HyprMac v0.17.0, base commit
`f3e002a`) to fit this user's setup and needs. Everything below is **uncommitted** in the working
tree on `main`. The user has not asked for any commit, branch or PR. Do not do any git operation
unless asked.

## The user's setup (why these changes exist)

- **Several native macOS desktops (Spaces)** on the external monitor. The monitor shows as
  "Mi 27 NU" or "HP HC270" depending on the day. It has desktops 3, 4, 5, 6, 7, 8, 9, 10, 11 and a
  fullscreen Space 52. The laptop display has a single desktop. Upstream assumes one Space per
  monitor; this user switches desktops all the time.
- The laptop display is the **rightmost** screen and is shorter than the monitor (usable height
  949pt), and HyprMac's global hide corner sits on it.
- Busy windows: Outlook (main window gets reopened under new ids, mail/reminder windows come and
  go), cmux terminals, Chrome, Word.

## What was built (all verified with tests; most also live-checked by the user)

| # | Change | Where | Live status |
|---|--------|-------|-------------|
| 1 | **Per-native-desktop tile trees.** On a desktop switch, each screen's trees are parked under the old Space and the new Space's parked trees are restored. | `TilingEngine.syncNativeSpaces`, wired in `WindowManager.pollWindowChanges` (before/after Space reading around the snapshot), `tileAllVisibleSpaces`, `activeSpaceDidChange`; `SpaceManager.activeSpaces` / `displayUUID` | Works: logs show `restored 1` on every return |
| 2 | Display change keeps parked trees unless their screen left (the first version dropped all of them on any `screenParametersChanged`) | `TilingEngine.handleDisplayChange` | Fixed after live run 1 |
| 3 | **Off-Space snapshot filter.** Windows whose Spaces are all inactive are left out of every AX snapshot; mid-animation the on-screen list held both desktops' windows | `SpaceManager.offSpaceWindowIDs`, `AccessibilityManager.offSpaceWindowIDs` seam, wired in `WindowManager` init | Fixed after live run 2 |
| 4 | **Inserts no longer wipe every user ratio** (only the new split starts at default) | `TilingEngine.updateTreeMembership` | Shipped; user had not reported back yet |
| 5 | **Flip workspace** action `flipWorkspace`, default **Hypr+Shift+J**, wire key `{"flipWorkspace":{}}` | `BSPNode.mirrorHorizontally` / `childRects`, `BSPTree.mirrorHorizontally` / `topologySnapshot`, `TilingEngine.flipWorkspace`, Action/dispatcher/settings/overlay | Confirmed working |
| 6 | **Hypr+F parking fix**: a hidden window that macOS resized (shorter parking display) is accepted once the frame settles | `TilingEngine.parkStableSamples` | User confirmed "now it works" |
| 7 | **Hypr+F is a toggle**: second press returns the window to its old slot/ratios; falls back to move-and-follow if the source workspace changed or the window was floating | `TilingEngine.rememberDedicatedReturn` / `dedicatedReturnWorkspace` / `restoreDedicatedReturn`, `WorkspaceOrchestrator.returnFromDedicatedWorkspace` | Shipped; not yet reported back |
| 8 | **Hypr+T float** centers the window at 60%×60% of the screen's usable area | `FloatingWindowController.toggledFloatingFrame`, `TilingConfig.floatingToggleScreenFraction` | Shipped just before this handoff; not yet reported back |

Design and rationale are already written up. Read them instead of re-deriving:
- `docs/architecture.md`, section "Native Spaces"
- `docs/tiling-algorithm.md`, "Ratio memory" (insert no longer clears ratios)
- `docs/keybinds-and-actions.md`, "Flip workspace" and the Hypr+F toggle paragraph
- `docs/dedicated-workspace-verification.md`, "Follow-up: parking on a shorter display"
- `docs/debugging.md`, "Sizes reset after switching macOS desktops" (log lines to grep)
- **`Issues - Pending Items.md`** (repo root): the pending/completed register for everything above

New test files: `HyprMacTests/NativeSpaceTreeTests.swift`, `FlipWorkspaceTests.swift`,
`DedicatedReturnTests.swift`, `FloatingToggleFrameTests.swift`. There are also additions in
`RatioMemoryEngineTests.swift`, `FullscreenWorkspaceTransferTests.swift` (inside a crashing class;
run its tests by name) and `KeybindOverlayContentTests.swift`.

## Open problems / next steps

1. **Await live feedback** on #4, #7 and #8. To diagnose, read the debug file log
   `~/Library/Logs/HyprMac/com.zachgray.HyprMac.debug.log` around the time the user names. Useful
   greps: `native space change`, `discovery retile`, `off-space`, `Hypr+F back`,
   `position-only park`, `float toggle`, `matched: `.
2. **Pending item 2** in the issues file: a window that closes next to a *stack* forgets its
   boundary (`BSPNode.remove` only remembers when the sibling is a leaf). The user's Outlook column
   hits this. It needs a "wrap a subtree" insert path with depth and min-size checks. Offered to the
   user but not yet requested.
3. **Swaps still reset every user ratio** (`TilingEngine` swap path: `clearUserSetRatios` at the
   swap sites). Offered to make swaps keep sizes like flip does. Not requested yet.
4. **Pending item 1** open risk: the window server could report the new Space later than the
   window list changes. The off-Space filter (#3) should cover this; watch for regressions.
5. The first visit to each desktop after an app restart rebuilds that desktop once, because parked
   trees live in memory only. Nobody has asked to persist them.

## How to build, run and test on this Mac (non-obvious)

- `xcodegen` was installed with Homebrew this session (`/opt/homebrew/bin/xcodegen`). Run
  `xcodegen generate` after adding or removing files. Never hand-edit `project.pbxproj`.
- `scripts/test-isolated.sh` builds but **cannot load the bundle** here: `xcrun` strips `DYLD_*`.
  Build with the script, then run Xcode's xctest directly:
  ```bash
  ./scripts/test-isolated.sh --debug-variant <Class>   # builds (bundle load then fails, ignore)
  A=$PWD/build/sizing/isolated-tests; P=$A/derived/Build/Products/Debug
  CFFIXED_USER_HOME=$A/home TMPDIR=$A/tmp HYPRMAC_HEADLESS_TESTS=1 DYLD_LIBRARY_PATH=$P \
    DYLD_FRAMEWORK_PATH=$P "$(xcrun -f xctest)" -XCTest <Class> $P/HyprMacTests.xctest
  ```
- **15 test classes crash (exit 133) on this Mac, and they did so on untouched `HEAD` too.** The
  list is in `Issues - Pending Items.md` item 3. Run classes one by one. The last sweep had 1,217
  tests passing and only those 15 failing.
- **Debug app:** `scripts/build-debug.sh` needs upstream's signing identity, so build directly with
  the user's own Developer ID:
  ```bash
  xcodebuild -project HyprMac.xcodeproj -scheme "HyprMac Debug" -configuration Debug \
    -derivedDataPath build/local-debug.noindex -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY=<user's Developer ID SHA-1, see `security find-identity -v -p codesigning`, team 9F9H8NCAUB> \
    CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=9F9H8NCAUB build
  ```
  Restart it by sending `kill -TERM` to the pid of `build/local-debug.noindex/.../HyprMac Debug.app`,
  then `/usr/bin/open` the app. Accessibility trust carries over because the signature is the same.
  Check the log for `AXIsProcessTrusted=true`. The `/Applications/HyprMac.app` release build is
  quit and must stay quit while the debug build runs.
- SourceKit "Cannot find type …" diagnostics in the editor are noise (files indexed alone); trust
  the xcodebuild result.
- The user wants every rebuild followed by a restart of the debug app.

## Suggested skills

- `mattpocock-skills:diagnosing-bugs`: for the next "it still resets" style report (log-first,
  evidence before fix; project rule: no guess fixes for intermittent bugs).
- `mattpocock-skills:tdd`: for item 2 or 3 above (pure-tree tests first, as done this session).
- `code-review`: before the user asks for a commit/PR of this large uncommitted diff.
- `commit-commands:commit`: only if the user explicitly asks to commit.
- `run`: to relaunch the debug app if the manual recipe above changes.
