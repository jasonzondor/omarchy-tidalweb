# Notes for working on this plugin

## What it is

`com.zondor.tidalweb` — a thin Quickshell wrapper around the TIDAL **web
player** running in an isolated Chromium. No Mopidy, no tidalapi, no pip deps,
no DevTools bridge. The Chromium window *is* the client; this plugin just shows
now-playing in the bar and toggles that window in and out of view.

## Layout

- `bin/omarchy-tidalweb` — bash. Launch / `toggle` / `show` / `hide` / `stop`
  the Chromium instance; parks it on `special:tidal`, floating and panel-sized
  (`stow_window`). No `--remote-debugging-port`.
- `qml/Service.qml` — keepLoaded singleton. Reads now-playing + transport off
  `Quickshell.Services.Mpris`; drives `bin/omarchy-tidalweb` via
  `Quickshell.execDetached`. `IpcHandler` target `tidalweb`.
- `qml/BarWidget.qml` — sleeve + title when playing, mark when idle. Click =
  toggle window, middle = play/pause, scroll = next/prev.
- `qml/components/RoundedImage.qml`, `qml/lib/Format.js` — small helpers.

## Gotchas

- **Real directory only.** The shell watches `~/.config/omarchy/plugins` with
  `inotifywait -r`, which doesn't follow symlinks, and `omarchy plugin
  validate` rejects a symlinked plugin dir outright. Keep the repo *at*
  `~/.config/omarchy/plugins/com.zondor.tidalweb`.
- **Hot-reload safety**: saving any file reloads the plugin and destroys
  `Service`. `alive` is set false in `Component.onDestruction`; guard async
  paths with it.
- **`manifest` (and so `pluginDir` / `launcher`) is injected AFTER
  `Component.onCompleted`.** Anything needing the plugin path must tolerate an
  empty value at construction.
- **Child processes** go through `bash -c` (`["bash","-c","exec \"$0\" \"$1\"",
  script, arg]`) — Quickshell's `Process` / `execDetached` won't reliably start
  a script by path directly, especially through a symlinked dir.
- **Hyprland is Lua here** (Omarchy, Hyprland ≥ 0.56). `hyprctl dispatch` takes
  Lua, not `dispatcher args` strings: `hyprctl dispatch
  'hl.dsp.window.move({ window = "address:0x..", workspace = "special:tidal",
  follow = false })'`. Ops by `window = "address:.."` don't steal focus.
  `hl.dsp.workspace.toggle_special("tidal")` shows/hides the special ws.
  `hyprctl clients -j` / `monitors -j` queries still work normally.
- **Chromium ignores `--class` in `--app` mode on Wayland** — the window comes
  up as `chrome-listen.tidal.com__-Default` (derived from the `--app` URL, fixed
  for the window's life). Match by pid first, that class regex as fallback.
- **The launcher takes an flock** (`$XDG_RUNTIME_DIR/omarchy-tidalweb/lock`) and
  holds it until the spawned Chromium is pgrep-visible, so a click storm can't
  spawn a pile of windows. Chromium is spawned with `9>&-` so it doesn't
  inherit and pin that lock.
- **Panel state**: `Service.qml` sets `panelVisible` from `Hyprland.rawEvent`
  `activespecial`(`v2`). `BarWidget` mirrors it into `bar.requestPopout(root)` /
  `releasePopout(root)` for the accent under-line + one-popup-at-a-time.
- **Click-away** is `qml/Scrim.qml` (an `overlay` kind, keepLoaded): a
  transparent full-screen layer-shell `PanelWindow` on `WlrLayer.Overlay` whose
  input `mask` is the screen minus the panel rect minus the bar strip. A press
  anywhere in that region calls `hideWeb`. Focus events are *not* used for
  click-away — they fire on hover with focus-follows-mouse. The launcher writes
  `window-geometry` (`x y w h barHeight`, monitor-local) for the mask.
- **`hyprctl dispatch` is Lua here.** `activespecial`/`activewindowv2` etc.
  are still emitted on `.socket2.sock` in the classic `name>>a,b,c` form.
- **MPRIS matching**: `Service.player` prefers the player whose
  `metadata["xesam:url"]` contains `tidal`, so it never latches onto another
  Chromium window. Falls back to "a Chromium player with a track" only if no
  player reports a URL.
- Nerd Font glyphs are literal PUA chars in the `.qml`. Edit tools may render
  them blank — check with `grep -n glyph … | cat -A`.
- **Closing the Chromium window stops playback** by design (it's the audio
  engine). The widget toggles it; `quit` is the deliberate "stop" path.

## Checks

```
bash -n bin/omarchy-tidalweb bin/omarchy-tidalweb-setup
python3 scripts/validate-manifest.py .
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I "$OMARCHY_PATH/shell" qml/*.qml qml/components/*.qml
```

## Why not embed a web view

Considered QtWebEngine in a Quickshell popup. Blocked: it needs
`Qt::AA_ShareOpenGLContexts` + `QtWebEngineQuick::initialize()` before the app
starts, and Quickshell's `main()` (a packaged binary) does neither. A separate
QtWebEngine helper would work but gains nothing over real Chromium, which
brings Widevine + MPRIS for free.
