<img src="assets/icon.svg" width="56" alt="">

# TIDAL Web for Omarchy

TIDAL in the Omarchy shell **without Mopidy** — or any other package that
Omarchy does not already ship. Now-playing in the bar, a summonable player with
lyrics and the play queue, media keys and the OSD, and a search box that
deep-links into TIDAL. The audio comes from the TIDAL web player running in an
isolated Chromium that lives on its own workspace, out of the way.

This is a deliberately smaller cousin of
[`ph0bos/omarchy-tidal`](https://github.com/ph0bos/omarchy-tidal). That plugin
is headless and hi-res; it needs Mopidy 4, `python-tidalapi` and a companion
extension. This one needs none of that, and accepts the trade-offs below to get
there.

## Trade-offs — read these first

| | |
|---|---|
| **Audio quality** | Up to **16-bit / 44.1 kHz lossless**. The browser's Widevine path cannot do hi-res / MQA. Same ceiling as `tidal-hifi`. |
| **A browser window exists** | An isolated Chromium runs the TIDAL web app. It is parked on the `special:tidal` workspace and summoned on demand — you are not meant to look at it, but it is there. |
| **Fragility** | Lyrics, the queue and "favorite" are read out of TIDAL's web DOM. TIDAL changes its frontend without notice; when something breaks the fix is usually one line in [`bin/omt-inject.js`](bin/omt-inject.js). Now-playing and transport go through MPRIS and are solid. |
| **First run** | You sign in to TIDAL once, by hand, in the revealed browser window. |

## Requirements

- **Omarchy 4+** with the Quickshell shell
- A **Chromium-family browser** (`chromium`, Chrome, Brave, Edge, Vivaldi) with
  Widevine — Omarchy's default `chromium` is fine
- `python3` — present on every Omarchy install
- A **TIDAL subscription** (this is a client, not a source of music)

Everything above except your TIDAL account is already on a stock Omarchy box.

## Install

```bash
omarchy plugin add https://github.com/jasonzondor/omarchy-tidalweb.git
omarchy plugin enable com.zondor.tidalweb
omarchy restart shell
```

Then:

```bash
~/.config/omarchy/plugins/com.zondor.tidalweb/bin/omarchy-tidalweb-setup check
~/.config/omarchy/plugins/com.zondor.tidalweb/bin/omarchy-tidalweb-setup desktop     # add to the launcher
~/.config/omarchy/plugins/com.zondor.tidalweb/bin/omarchy-tidalweb-setup bindings    # print suggested keys
```

Add the keybindings it prints to `~/.config/hypr/bindings.lua` (SUPER+M is
often taken; the suggestions use SUPER+ALT), then press one and sign in to
TIDAL in the window that appears. Playback, lyrics and the queue then show up
in the shell.

## Using it

| Action | How |
|---|---|
| Open the player | `omarchy-shell tidalweb overlay`, or left-click the bar widget |
| Lyrics / Queue / Search | header buttons in the overlay, or `L` / `Q` / `/` while it is open |
| Reveal the actual TIDAL window | `omarchy-shell tidalweb web`, or the ⧉ button |
| Play / pause · next · previous | media keys, or middle-click / scroll the bar widget |
| Favorite the current track | ♥ in the transport bar, or `omarchy-shell tidalweb favorite` |
| Search | type in the overlay's Search view — it navigates the TIDAL window |

`omarchy-shell tidalweb status` prints a JSON snapshot for debugging.

## Configuration

The bar widget reads these from its `~/.config/omarchy/shell.json` layout entry
(edit them there, or via the shell's widget settings UI):

```jsonc
{
  "id": "com.zondor.tidalweb",
  "showLabel": true,        // show the track title next to the sleeve
  "maxLabelWidth": 260,     // px before the title elides
  "scrollLongLabels": true, // reserved for a future marquee
  "hideWhenPaused": false   // take the widget out of the bar when not playing
}
```

## Removal

```bash
~/.config/omarchy/plugins/com.zondor.tidalweb/bin/omarchy-tidalweb-setup uninstall --purge
omarchy plugin remove com.zondor.tidalweb
omarchy restart shell
```

`--purge` also deletes the isolated Chromium profile and your TIDAL login.

## How it works

```
special:tidal workspace          MPRIS (D-Bus, push)     ── title/artist/art
  Chromium --app=listen.tidal.com ───────────────────────── position/seek
    isolated profile + CDP port                             play/pause/next/prev
        │
        └── Chrome DevTools ── bin/omarchy-tidalweb-bridge (python3, stdlib)
              WebSocket          injects bin/omt-inject.js
                                 └── lyrics · queue · quality · favorite
                        │
              qml/Service.qml  (keepLoaded singleton, merges both sources)
                        │
          qml/BarWidget.qml    ·    qml/Overlay.qml
```

- `bin/omarchy-tidalweb` launches / shows / hides the Chromium instance and
  parks it on `special:tidal` itself (no Hyprland rule needed).
- `bin/omarchy-tidalweb-bridge` speaks the DevTools protocol over a minimal
  stdlib WebSocket client — no `pip`, no `playerctl`, no extra binaries.
- Nothing is stored except the Chromium profile at
  `~/.local/share/omarchy-tidalweb/chromium` (your TIDAL login) and a port file
  under `$XDG_RUNTIME_DIR`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Nothing in the bar | `omarchy-tidalweb show`, sign in, play something. `omarchy-tidalweb-setup check`. |
| Playback controls dead | Confirm Chromium exports MPRIS: `busctl --user list \| grep -i mpris`. |
| No lyrics / empty queue | Open the browser and show TIDAL's own lyrics / queue panel once. If still empty, the DOM selectors have drifted — see below. |
| DRM / playback error in the window | Your Chromium build lacks Widevine; install it (`chromium` on Arch may need the `chromium-widevine`-style component). |
| CDP not answering | Chromium ≥ M136 ignores `--remote-debugging-port` unless `--user-data-dir` is non-default — the launcher sets one, so make sure no stray Chromium is holding the profile. |

### When TIDAL changes its web player

`bin/omt-inject.js` has a `SELECTORS` block at the top. Open the TIDAL web
player, inspect the element that stopped working, and add its selector (prefer
`data-test="…"`) to the front of the matching list. Reload with
`omarchy-shell shell rescanPlugins` or restart Chromium.

## Security note

While TIDAL is running, Chromium exposes a DevTools endpoint on
`127.0.0.1:<port>` (default 9222+). It is loopback-only and drives an isolated
profile, but any local process could talk to it. Stop it with
`omarchy-tidalweb stop` when you are done, or `omarchy-shell tidalweb quit`.

## License

MIT. Portions adapted from `ph0bos/omarchy-tidal` (MIT). Not affiliated with or
endorsed by TIDAL.
