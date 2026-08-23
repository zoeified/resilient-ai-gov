# Blackboard

A chalkboard that lives on your iPhone Home Screen. Tap it, scribble, close the
app — what you drew is sitting there in the widget. Add bullets for the things
that need words. Wipe it in one tap when the day is done.

<pre>
┌──────────────────────────┐
│  • Milk, eggs, coffee    │   Large widget (also medium & small)
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
already in hand — there is no menu, no document picker, no "new drawing".

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
5. Run on a device or simulator, then long-press the Home Screen → *Edit* →
   *Add Widget* → **Blackboard** → pick the large size.

Deployment target is iOS 17.0 (required for the wipe button — interactive
widgets did not exist before it).

## How it works

```
Shared/                      compiled into BOTH the app and the widget
  AppGroup.swift             group identifier + deep-link URLs
  BoardModel.swift           Board = strokes + bullets, stored in a unit square
  BoardStore.swift           disk I/O (BoardFile) + the app's observable store
  ChalkTheme.swift           slate, chalk colours, dust
  BoardCanvasView.swift      the one renderer used by app and widget alike
  BoardIntents.swift         WipeBoardIntent, AddNoteIntent

Blackboard/                  the app
BlackboardWidget/            the widget extension
```

**Why the drawing looks identical in both.** Strokes are stored as normalized
points in a 0…1 square rather than pixels, and every size — chalk width, font,
padding — is derived from the rendered width. The app's board is pinned to the
large widget's aspect ratio (`BoardGeometry.aspect`), so what you draw is
literally what appears on the Home Screen, at any device size.

**How the widget sees your drawing.** Both processes read and write
`board.json` in the shared App Group container. The app coalesces writes while
you draw and pushes `WidgetCenter.reloadAllTimelines()` when the strokes settle,
plus an immediate flush when the app leaves the foreground. The widget's
timeline policy is `.never` — it only refreshes when something actually changed.

**Wiping.** In the app: one tap, with an *Undo* offered for eight seconds. From
the widget: the first tap arms the button (it turns amber and says "Tap to
confirm"), the second within six seconds wipes — a stray Home Screen tap should
never erase your board. Either way the previous board is kept as a backup, so
the app can put it back.

**The eraser** paints an opaque slate-coloured streak rather than cutting a hole
in the chalk layer. That is what a felt eraser actually leaves behind, and it
avoids depending on blend modes inside the widget renderer.

## Siri and Shortcuts

- "Add a note to Blackboard" — appends a bullet without opening the app.
- "Wipe my Blackboard" — clears it.

Both are also available as Shortcuts actions, so the wipe can be put on the
Action button or an automation ("clear the board every night at 11").

## Notes for future work

The Xcode project file is hand-maintained. If you add a source file, add it to
the right target(s) in Xcode — anything under `Shared/` needs to be a member of
**both** the app and the widget extension.

Ideas that would fit naturally: Apple Pencil pressure via PencilKit, a
Lock Screen accessory widget, multiple boards, and a Live Activity for a board
you are actively working on.
