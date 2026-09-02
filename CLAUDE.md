# Notes for working on this plugin

## What it is

A Quickshell plugin (`com.zondor.tidalweb`) that is a control surface for the
TIDAL **web player** running in an isolated Chromium. No Mopidy, no tidalapi,
no pip deps — only what Omarchy 4 ships. See README for the trade-offs.

## Layout

- `bin/omarchy-tidalweb` — bash. Launch / show / hide / stop the Chromium
  instance; parks it on `special:tidal` with `movetoworkspacesilent` so no
  Hyprland rule is needed.
- `bin/omarchy-tidalweb-bridge` — python3, **stdlib only** (runs on
  `/usr/bin/python3`). Minimal RFC 6455 client → Chrome DevTools Protocol.
  JSON-lines protocol on stdio. Keep it dependency-free.
- `bin/omt-inject.js` — **the only file that knows TIDAL's DOM.** All selectors
  in the `SELECTORS` block. This is where breakage from TIDAL frontend changes
  gets fixed.
- `qml/Service.qml` — keepLoaded singleton, the source of truth. Binds MPRIS
  (Quickshell.Services.Mpris) for now-playing + transport, runs the bridge as a
  child Process for lyrics/queue/quality/favorite. `IpcHandler` target
  `tidalweb`.
- `qml/BarWidget.qml`, `qml/Overlay.qml`, `qml/views/*`, `qml/components/*`.

## Gotchas

- **Hot-reload safety**: saving any file under `~/.config/omarchy/plugins/`
  reloads plugin code and destroys `Service`. Every async callback / Timer
  checks `root.alive` first; `Component.onDestruction` sets it false and stops
  the bridge. A callback that writes a property on a dead object aborts the
  whole shell.
- **MPRIS ↔ instance matching** is heuristic: `Service.player` picks "the
  Chromium player". The isolated profile only ever plays TIDAL, so this is
  fine in practice.
- **Position** runs off a wall-clock anchor (`anchorPos + (now - anchorAt)`),
  never a polled counter or repeated `player.position` reads.
- **Chromium ≥ M136** ignores `--remote-debugging-port` without a non-default
  `--user-data-dir`. The launcher always passes one.
- Nerd Font glyphs are literal PUA characters in the `.qml` files. `grep`/edit
  tools may render them blank — check with `grep -n glyph … | cat -A`.
- **Hot reload needs a real directory.** The shell watches
  `~/.config/omarchy/plugins` with `inotifywait -r`, which does not follow
  symlinks. If the plugin dir is a symlink to a checkout elsewhere, edits are
  invisible to the watcher — run `omarchy restart shell` after each change, or
  develop against a real copy under `~/.config/omarchy/plugins/`.
- **Child processes**: `Process`/`execDetached` go through `bash -c` (the form
  Omarchy's own shell uses). Running a plugin script by path directly can fail
  to start under Quickshell. `python3` is pinned to `/usr/bin/python3` to skip
  the mise shims that sit ahead of `/usr/bin` on the shell's PATH.

## Checks

```
python3 -m py_compile bin/omarchy-tidalweb-bridge
node --check bin/omt-inject.js
bash -n bin/omarchy-tidalweb bin/omarchy-tidalweb-setup
python3 scripts/validate-manifest.py .
```

Bridge can be exercised without the shell:

```
chromium --headless=new --user-data-dir=/tmp/x --remote-debugging-port=9333 \
  --remote-allow-origins='*' 'data:text/html,<title>tidal.x</title>...' &
printf '{"cmd":"lyrics"}\n' | python3 bin/omarchy-tidalweb-bridge --port=9333
```
