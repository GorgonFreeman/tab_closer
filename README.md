# Tab Closer

macOS SwiftUI app that lists every open Google Chrome tab in one scrollable list, grouped by domain (then alphabetically by title). Click **×** next to a tab to close it in Chrome.

## Open in Xcode

```bash
open TabCloser.xcodeproj
```

Requires macOS 13+.

## Build from the command line

```bash
xcodebuild -scheme TabCloser -configuration Debug build
```

After building, open the `.app` from the build products folder (or run from Xcode) — it is a normal Mac app you can put in Applications or the Dock.

## Usage

1. Open Google Chrome with some tabs.
2. Launch **Tab Closer**.
3. Grant **Automation** access when macOS asks (System Settings → Privacy & Security → Automation → Tab Closer → Google Chrome).
4. Browse tabs by domain; click **×** to close one, or the refresh button to reload the list.

## Notes

- Sandbox is off so the app can send Apple Events to Chrome.
- Chrome must already be running; otherwise the app shows a short status message.
