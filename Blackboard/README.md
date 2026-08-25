# Blackboard

A chalkboard that lives on your Home Screen. Tap it, scribble, close the app —
what you drew is sitting there in the widget. Add bullets for the things that
need words. Wipe it in one tap when the day is done.

White chalk on a near-black slate. That is the whole palette.

<pre>
┌──────────────────────────┐
│  • Milk, eggs, coffee    │   Widget: small, medium, large, extra large (iPad)
│  • Call the vet at 4     │
│  • Ellie — soccer kit    │   Tap anywhere  → opens the board, ready to draw
│                          │   [+ Note]      → opens with the bullet field up
│         ⌣  (chalk)       │   [Wipe]        → tap once to arm, again to erase
│                 [+][Wipe]│
└──────────────────────────┘
</pre>

## One thing to know up front

**iOS widgets cannot be drawn on directly.** WidgetKit renders a static
snapshot; the only interaction it allows is buttons and links (iOS 17+). So the
split is:

| Where | What you can do |
|---|---|
| Widget | See the board. Tap to open it. Wipe it. Jump to adding a bullet. |
| App | Draw, erase, undo, manage bullets, wipe. |

Opening is one tap and the app launches straight onto the board with the chalk
already in hand — no menu, no document picker, no "new drawing".

## iPad and Apple Pencil

The app is universal, and the canvas is PencilKit — so on iPad the Pencil gets
real **pressure, tilt and palm rejection**, and the low-latency stroke
prediction you expect from a native drawing app. The ink is PencilKit's
`.pencil` type, which is textured and tilt-sensitive: it genuinely reads as
chalk on a dark board in a way a plain pen stroke never does.

A **Pencil only** toggle appears in the chalk tray on iPad. Off (the default),
fingers draw too. On, fingers and palms are ignored entirely — turn it on when
you are resting your hand on the screen.

**Your board does not sync between devices yet.** The iPhone and the iPad each
keep their own board. Making them one board needs iCloud (CloudKit, or an
iCloud Documents container the App Group mirrors locally for the widget) — a
real piece of work rather than a flag, so it is not in here. Say the word and
it's the obvious next addition.

## Building without a Mac

Xcode is macOS-only, so `.github/workflows/blackboard-ios.yml` builds this on a
GitHub-hosted macOS runner instead. It compiles the app and the widget
extension for the simulator with signing disabled — **no Apple Developer
account and no certificates needed** — prints every compiler error in a
collapsed log group, then boots a simulator, launches the app and uploads a
screenshot as an artifact. This repository is public, so macOS runner minutes
are free.

Verified on Xcode 16.4 / iOS 18.5: builds clean, no warnings, the widget
extension embeds correctly, and the App Shortcuts phrases compile.

What CI cannot check: the App Group (entitlements are stripped for an unsigned
build, so the app falls back to its own Documents directory), the widget on a
real Home Screen, and Apple Pencil. Those need a signed build on a device — see
Setup below, then TestFlight.

## Setup

1. Open `Blackboard.xcodeproj` in Xcode 15 or later.
2. Select the **Blackboard** target → *Signing & Capabilities* → pick your Team.
   Do the same for **BlackboardWidgetExtension**.
3. Change the bundle identifiers to something you own, e.g.
   `com.yourname.blackboard` and `com.yourname.blackboard.widget`. The widget's
   identifier **must** be prefixed by the app's.
4. Change the App Group in all three places so it matches your identifier:
   - `Shared/AppGroup.swift` → `AppGroup.identifier`
   - `Blackboard/Blackboard.entitlements`
   - `BlackboardWidget/BlackboardWidget.entitlements`

   With a paid developer account, register the group under
   *Signing & Capabilities → App Groups*. This is the one step that, if skipped,
   leaves the widget permanently blank — so the app shows a **"Widget not
   linked"** warning in its header when the group is missing.
5. Run, then long-press the Home Screen → *Edit* → *Add Widget* →
   **Blackboard** → pick the size you want.

Deployment target is iOS 17.0 (required for the wipe button — interactive
widgets did not exist before it). Builds for iPhone and iPad from one target.

## How it works

```
Shared/                      compiled into BOTH the app and the widget
  AppGroup.swift             group identifier + deep-link URLs
  BoardModel.swift           bullets, board metadata, chalk sizing
  BoardStore.swift           BoardFile (disk) + the app's observable store
  ChalkTheme.swift           slate, chalk white, dust
  BoardCanvasView.swift      slate + bullets + rasterised ink
  BoardIntents.swift         WipeBoardIntent, AddNoteIntent

Blackboard/                  the app
  DrawingController.swift    tool, undo stack, debounced save, ink rasteriser
  PencilBoardView.swift      the PKCanvasView itself
BlackboardWidget/            the widget extension
```

Three files live in the App Group container:

| File | What it holds | Who reads it |
|---|---|---|
| `board.json` | bullets + metadata | app, widget, intents |
| `drawing.data` | PencilKit's own representation | app (to keep editing) |
| `ink.png` | the strokes, rasterised on a transparent background | widget |

The widget never touches PencilKit — it composites one PNG over the slate and
draws the bullets as text. The app writes both files half a second after the
pen comes to rest, and immediately when the app leaves the foreground, then
pushes `WidgetCenter.reloadAllTimelines()`. The widget's timeline policy is
`.never`: it refreshes when something actually changed, not on a clock.

**Why the drawing looks identical in both.** The board is pinned to the large
widget's aspect ratio everywhere, the ink is rasterised at 3× its point size,
and chalk widths are stored as a *fraction of board width* rather than in
points — so a stroke is the same weight on a phone and on a 13-inch iPad. Open a
board drawn on another device and the drawing is scaled uniformly to fit.

**Wiping.** In the app: one tap, with an *Undo* offered for eight seconds. From
the widget: the first tap arms the button (it turns amber and says "Tap to
confirm"), the second within six seconds wipes — a stray Home Screen tap should
never erase your board. Either way one generation of backup is kept, so the app
can put it back.

**Undo** is an explicit stack of drawing snapshots rather than PencilKit's own
undo manager, which comes off the responder chain and is easy to lose track of
in SwiftUI. Depth is 25 strokes.

## Siri and Shortcuts

- "Add a note to Blackboard" — appends a bullet without opening the app.
- "Wipe my Blackboard" — clears it.

Both are also Shortcuts actions, so the wipe can go on the Action button or a
nightly automation.

## Notes for future work

The Xcode project file is hand-maintained. If you add a source file, add it to
the right target(s) in Xcode — anything under `Shared/` needs to be a member of
**both** the app and the widget extension.

Natural next steps: iCloud sync between iPhone and iPad, a Lock Screen
accessory widget, multiple boards, and double-tap / squeeze Pencil gestures for
switching to the eraser.
