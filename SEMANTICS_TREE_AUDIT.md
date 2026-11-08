# Flutter Semantics Tree Corruption Audit & Lifecycle Hardening
**Subsystem:** Flutter Semantics Engine, RenderObject Lifecycle, Accessibility (a11y)  
**Component:** `NewContextualPanel`, `LyricsScreen`, `QueueBottomSheet`, `NewMiniPlayer`, `NewDesktopPlayerBar`  
**Status:** Audit Completed & Lifecycle Hardened (v3.9.7)

---

## 1. Overview & Architectural Diagnosis

### 1.1 The Fatal Assertions
The application crashed on Windows with the following fatal assertions in Flutter's rendering and semantics engine:

```text
[FATAL]
SemanticsNode._replaceChildren
Failed assertion: line 241 pos 12: '!child.attached': is not true.

[FATAL]
RenderObject semantics
Failed assertion: line 5831 pos 12: 'node.built': is not true.
```

### 1.2 Flutter Semantics Invariants
In Flutter's semantics subsystem (`flutter/rendering/semantics.dart`), semantics nodes form an accessibility tree mirroring the `RenderObject` tree:
1. **The Attachment Invariant**: A `SemanticsNode` cannot be attached to a parent while it is already attached (`assert(!child.attached)`). When a node moves between parents or is re-indexed, it must be detached from its current owner/parent before attachment to a new parent.
2. **The Build Invariant**: When semantics are updated during the layout/paint traversal pass, every node involved in the subtree must have finished its build cycle (`assert(node.built)`). State mutations inside widget `build` methods or stream builder listeners scheduled mid-frame violate this contract.

---

## 2. Forensic Audit of Root Causes

Our investigation revealed that the semantics tree corruption was triggered by four architectural issues:

### 2.1 Cause 1: Dual Viewport Conflict in `ScrollablePositionedList`
In [`NewContextualPanel._buildLyricsView`](file:///c:/Users/Achie/kiro-projects/it-feels-android/lib/features/new_experience/shell/new_contextual_panel.dart) and [`LyricsScreen`](file:///c:/Users/Achie/kiro-projects/it-feels-android/lib/features/player/lyrics_screen.dart), lyrics were rendered using `ScrollablePositionedList.builder`:

```dart
// ❌ BEFORE: Default addSemanticIndexes is true!
ScrollablePositionedList.builder(
  itemScrollController: _lyricsScrollController,
  itemCount: lines.length,
  itemBuilder: (context, index) { ... }
)
```

**The Mechanism of Failure**:
- `ScrollablePositionedList` internally maintains **two viewports**:
  1. An offscreen measuring viewport used to compute variable item heights.
  2. The visible display viewport rendering the active list.
- When `addSemanticIndexes: true` (the framework default for slivers and lists), both viewports attempt to register identical semantic indices (0, 1, 2, ...) for the same items.
- As the active lyric position changed and the list auto-scrolled, items transitioning between the measuring viewport and display viewport attempted to attach a `SemanticsNode` whose previous handle had not been detached. This directly triggered `SemanticsNode._replaceChildren Failed assertion: '!child.attached'`.

### 2.2 Cause 2: Volatile Reorderable Keys Tied to List Index
In both [`NewContextualPanel._buildQueueView`](file:///c:/Users/Achie/kiro-projects/it-feels-android/lib/features/new_experience/shell/new_contextual_panel.dart) and [`QueueBottomSheet`](file:///c:/Users/Achie/kiro-projects/it-feels-android/lib/features/player/queue_bottom_sheet.dart), queue items were keyed with the item index:

```dart
// ❌ BEFORE: Key changes on every reorder or drag!
key: ValueKey('queue_item_${song.id}_$index')
key: ValueKey('${song.id}_$index')
```

**The Mechanism of Failure**:
- When a user dragged a song to reorder the queue, `ReorderableListView` creates an animated overlay to follow the cursor.
- As the dragged item hovered over adjacent tracks, the indices shifted. Because the index was embedded in the `ValueKey`, Flutter perceived this as destroying the old elements and constructing new ones mid-drag.
- However, the `ReorderableListView` drag overlay maintained an active reference to the existing `SemanticsNode`. Attaching the newly constructed element while the overlay held the existing semantics handle triggered `assert(!child.attached)`.

### 2.3 Cause 3: Inline State Mutation During Widget Build
In [`NewContextualPanel._buildLyricsView`](file:///c:/Users/Achie/kiro-projects/it-feels-android/lib/features/new_experience/shell/new_contextual_panel.dart):

```dart
// ❌ BEFORE: Mutating state directly inside StreamBuilder.builder!
builder: (context, snapshot) {
  final position = snapshot.data ?? Duration.zero;
  final activeIndex = lyricsState.getActiveLineIndex(position);

  if (activeIndex != _currentActiveIndex && activeIndex >= 0) {
    _currentActiveIndex = activeIndex; // ❌ MUTATION DURING BUILD!
    WidgetsBinding.instance.addPostFrameCallback((_) { ... });
  }
```

**The Mechanism of Failure**:
- Mutating `_currentActiveIndex` during the widget build method altered the identity of active lines before the layout pass completed.
- When Flutter attempted to reconcile the `RenderObject` semantics tree, the node's layout state was inconsistent with its build state, triggering `RenderObject semantics Failed assertion: 'node.built': is not true`.

### 2.4 Cause 4: Micro-Progress Bar High-Frequency Semantics Churn
In [`NewMiniPlayer`](file:///c:/Users/Achie/kiro-projects/it-feels-android/lib/features/new_experience/player/new_mini_player.dart), a 2.5px micro-progress bar was connected to `AudioEngineService.positionStream`:
- Every 200 milliseconds, a new position tick updated the `LinearProgressIndicator`.
- By default, `LinearProgressIndicator` emits accessibility semantics (`value`, `min`, `max`).
- This generated continuous 5Hz semantic node invalidations during modal popups and navigation route transitions, colliding with active layout passes.

---

## 3. Implemented Fixes & Stabilization

### 3.1 Stable Queue Identity Architecture
To guarantee that widget and semantics keys remain completely invariant under queue drags, reorders, and track shifts:
1. **Added `queueKey` to `Song` Model**:
   ```dart
   @ignore
   String? queueKey;

   String get effectiveQueueKey => queueKey ?? '${id}_$isarId';
   ```
2. **Assigned Stable UUIDs upon Insertion in `AudioPlayerNotifier`**:
   - Implemented `_ensureQueueKeys(List<Song> songs)` in [`audio_player_provider.dart`](file:///c:/Users/Achie/kiro-projects/it-feels-android/lib/features/player/audio_player_provider.dart).
   - Applied across `playSong`, `addToQueue`, `addSongsToQueue`, `playNext`, and `playNextBatch`.
3. **Keyed Queue Lists by `effectiveQueueKey`**:
   - `NewContextualPanel`: `key: ValueKey('queue_item_${song.effectiveQueueKey}')`
   - `QueueBottomSheet`: `key: ValueKey('queue_sheet_${song.effectiveQueueKey}')`

### 3.2 Dual-Viewport Index De-Duplication
In both `NewContextualPanel._buildLyricsView` and `LyricsScreen`:
```dart
ScrollablePositionedList.builder(
  key: const ValueKey('contextual_panel_lyrics_list'),
  itemScrollController: _lyricsScrollController,
  addSemanticIndexes: false, // ✅ Eliminates dual-viewport index collisions
  itemCount: lines.length,
  itemBuilder: (context, index) { ... }
)
```
- Setting `addSemanticIndexes: false` prevents `ScrollablePositionedList`'s internal measuring viewport from generating conflicting semantic indices.
- **Accessibility Preserved**: The children (lyric lines) remain fully accessible and readable by screen readers. The blanket `ExcludeSemantics` wrapper was removed, allowing users relying on assistive technology to hear each lyric line as it syncs.

### 3.3 Deferred State Updates Post-Frame
In `NewContextualPanel._buildLyricsView`:
```dart
if (activeIndex != _currentActiveIndex && activeIndex >= 0) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (activeIndex != _currentActiveIndex && activeIndex >= 0) {
      _currentActiveIndex = activeIndex; // ✅ Mutated safely outside build phase
      if (_lyricsScrollController.isAttached && activeIndex < lines.length) {
        _lyricsScrollController.scrollTo(
          index: activeIndex,
          alignment: 0.35,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  });
}
```

### 3.4 Micro-Progress Bar Semantics Isolation
In `NewMiniPlayer`:
```dart
return ExcludeSemantics(
  child: LinearProgressIndicator(
    value: progress,
    minHeight: 2.5,
    backgroundColor: Colors.white.withValues(alpha: 0.06),
    valueColor: const AlwaysStoppedAnimation<Color>(
      NewExperienceTokens.accentViolet,
    ),
  ),
);
```
- Prevents 5Hz semantics tree churn from purely cosmetic 2.5px indicators while preserving full accessibility on the player sheet and desktop bar.

### 3.5 Desktop Track Scrubber Key Stabilization
In `NewDesktopPlayerBar`:
```dart
_DesktopTrackScrubber(
  key: ValueKey('scrubber_${song.id}'), // ✅ Resets cleanly on track change
  song: song,
  notifier: notifier,
)
```

---

## 4. Accessibility & Semantics Compliance Verification

All accessibility features remain 100% operational and compliant:
- **No Global Semantics Disabling**: `WidgetsApp.showPerformanceOverlay` or global `excludeSemantics` was never used.
- **Screen Reader Support**: Tested with `tester.ensureSemantics()` active across all tests:
  - Track titles, artist names, transport controls, and scrubbers have valid semantic labels.
  - Lyrics screen text lines are individually readable.
  - Queue items announce track title and can be rearranged cleanly.
