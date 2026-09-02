<img src="assets/icon.svg" width="56" alt="">

# TIDAL Web for Omarchy

TIDAL in the Omarchy bar **without Mopidy** — or anything else Omarchy doesn't
already ship. Click the bar widget and the TIDAL web player drops down from its
own workspace; the widget shows what's playing and the media keys work. That's
it — TIDAL's own web UI does search, browse, lyrics and the queue.

A deliberately lean take next to
[`ph0bos/omarchy-tidal`](https://github.com/ph0bos/omarchy-tidal), which is
headless and hi-res but needs Mopidy 4, `python-tidalapi` and a companion
extension. This one is a thin wrapper around the TIDAL web player.

## Trade-offs — read these first

| | |
|---|---|
| **Audio quality** | Up to **16-bit / 44.1 kHz lossless**. The browser's Widevine path can't do hi-res / MQA — same ceiling as `tidal-hifi`. |
| **It's a real window** | An isolated Chromium runs the TIDAL web app, parked on the `special:tidal` workspace. The widget **toggles** it in and out of view. **Closing it stops the music** — that window *is* the player. Tuck it away, don't close it. |
| **First run** | Sign in to TIDAL once, by hand, in the window. |

## Requirements

- **Omarchy 4+** with the Quickshell shell
- A **Chromium-family browser** with Widevine — Omarchy's default `chromium` is fine
- A **TIDAL subscription** (this is a client, not a source of music)

Nothing else — no `pip` packages, no Mopidy, no `playerctl`.

## Install

```bash
omarchy plugin add https://github.com/jasonzondor/omarchy-tidalweb.git
omarchy plugin enable com.zondor.tidalweb
omarchy restart shell
```

Then, from `~/.config/omarchy/plugins/com.zondor.tidalweb/`:

```bash
bin/omarchy-tidalweb-setup check      # what's ready
bin/omarchy-tidalweb-setup hypr       # print the recommended window rule (optional, tidier drop-down)
bin/omarchy-tidalweb-setup bindings   # print a suggested keybinding
bin/omarchy-tidalweb-setup desktop    # add "TIDAL Web" to the app launcher
```

Click the widget in the bar, sign in to TIDAL, play something.

## Using it

| Action | How |
|---|---|
| Show / hide the TIDAL window | left- or right-click the widget, or `omarchy-shell tidalweb toggle` |
| Play / pause | media key, or middle-click the widget |
| Next / previous | media keys, or scroll the widget |
| Stop everything | `omarchy-shell tidalweb quit` (closes the window, ends playback) |

`omarchy-shell tidalweb status` prints a JSON snapshot for debugging.

## Configuration

Bar-widget options live in the `~/.config/omarchy/shell.json` layout entry
(edit there or via the shell's widget settings):

```jsonc
{
  "id": "com.zondor.tidalweb",
  "showLabel": true,       // show the track title next to the sleeve
  "maxLabelWidth": 260,    // px before the title elides
  "hideWhenPaused": false  // take the widget out of the bar when nothing is playing
}
```

## How it works

```
special:tidal workspace                 MPRIS (D-Bus, push)
  Chromium --app=listen.tidal.com  ───────────────────────────►  qml/Service.qml
    isolated profile, no debug port      title / artist / art      (keepLoaded singleton)
        ▲                                play / pause / next          │       │
        │ toggle / show / hide                                        │       ▼
  bin/omarchy-tidalweb  ◄──── Quickshell.execDetached ───────────────┘   qml/BarWidget.qml
  (parks it on special:tidal, floats + sizes it)
```

- `bin/omarchy-tidalweb` launches the isolated Chromium and parks it on
  `special:tidal`, floating and panel-sized. `toggle` / `show` / `hide` slide it
  in and out via `togglespecialworkspace`.
- `qml/Service.qml` reads now-playing and transport off MPRIS and drives that
  script. No DevTools, no DOM scraping.
- The only thing stored is the Chromium profile at
  `~/.local/share/omarchy-tidalweb/chromium` (your TIDAL login).

## Troubleshooting

| Symptom | Fix |
|---|---|
| Widget not in the bar | It's there unless `hideWhenPaused` is on and nothing's playing. `omarchy plugin list \| grep tidalweb`; `omarchy restart shell`. |
| Window opens full-screen, not as a panel | Run `bin/omarchy-tidalweb-setup hypr` and add the printed `o.window` rule. |
| DRM / playback error | Your Chromium lacks Widevine. On Arch, `chromium` normally has it; otherwise install the Widevine component. |
| Media keys do nothing | `busctl --user list \| grep -i mpris` while a track plays — Chromium should be listed. |
| Music stopped by itself | You closed the window instead of hiding it. Reopen with the widget and press play. |

## Security note

No DevTools / remote-debugging port is opened. The isolated Chromium profile
keeps the TIDAL login separate from your normal browser. `omarchy-shell
tidalweb quit` shuts the window down.

## License

MIT. Not affiliated with or endorsed by TIDAL.
