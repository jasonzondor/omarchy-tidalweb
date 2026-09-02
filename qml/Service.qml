import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "lib/Format.js" as Format

// Headless source of truth for the com.zondor.tidalweb plugin.
//
// The plugin is deliberately lean: the TIDAL web player in an isolated Chromium
// is the whole client. This service only
//
//   1. reads now-playing + transport off MPRIS (Chromium exports it over D-Bus,
//      push-based, so it costs nothing), and
//   2. drives bin/omarchy-tidalweb to show/hide/toggle that Chromium window.
//
// No DevTools bridge, no DOM scraping — search, lyrics, browse and the queue are
// just TIDAL's own web UI in the drop-down.
Item {
  id: root

  // Injected by the shell host (see shell.qml ensureService()).
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""
  property var pluginRegistry: null

  readonly property string pluginId: "com.zondor.tidalweb"
  readonly property string pluginDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string launcher: pluginDir === "" ? "" : pluginDir + "/bin/omarchy-tidalweb"

  // Hot-reload destroys this object while a Process callback or Timer may still
  // fire; every async path bails once this flips.
  property bool alive: true

  // Stop playback when the plugin is *disabled* — but not on a hot reload or a
  // shell restart, where the window (and its music) should survive. On disable
  // the registry has already flipped the plugin to not-enabled by the time this
  // runs; on a reload/restart it is still enabled (or the registry is gone).
  Component.onDestruction: {
    root.alive = false
    var disabled = false
    try {
      disabled = pluginRegistry && typeof pluginRegistry.isEnabled === "function"
        && pluginRegistry.isEnabled(root.pluginId) === false
    } catch (e) {}
    if (disabled) root.runLauncher("stop")
  }

  // ---- MPRIS binding -----------------------------------------------------

  readonly property var players: Mpris.players ? Mpris.players.values : []

  // Match the player that is actually playing tidal.com, so the widget never
  // latches onto a different Chromium window (a YouTube tab, another web app).
  readonly property var player: {
    var loose = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p) continue
      var url = String((p.metadata && p.metadata["xesam:url"]) || "").toLowerCase()
      if (url.indexOf("tidal.") !== -1 || url.indexOf("//tidal") !== -1) return p
      var bus = String(p.dbusName || "").toLowerCase()
      var id = String(p.identity || "").toLowerCase()
      var isChromium = bus.indexOf("chromium") !== -1 || bus.indexOf("chrome") !== -1
        || id.indexOf("chromium") !== -1 || id.indexOf("chrome") !== -1
      if (isChromium && (p.trackTitle || p.trackArtist) && !loose) loose = p
    }
    // Fall back to "the Chromium player with a track" only when nothing reported
    // a URL at all — some Chromium builds omit xesam:url.
    return loose
  }

  readonly property bool connected: player !== null
  readonly property bool playing: player ? !!player.isPlaying : false
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string album: player ? (player.trackAlbum || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property real length: player && player.lengthSupported ? player.length : 0
  readonly property bool stopped:
    player ? player.playbackState === MprisPlaybackState.Stopped : true
  readonly property bool hasTrack:
    (player !== null) && !stopped && (title !== "" || artist !== "")
  readonly property string trackKey: title + "" + artist + "" + album

  onTrackKeyChanged: {
    if (!root.alive) return
    if (root.seenATrack && root.hasTrack) Qt.callLater(root.announceTrack)
    if (root.hasTrack) root.seenATrack = true
  }
  property bool seenATrack: false

  // ---- the drop-down window -------------------------------------------

  readonly property string specialWs: "special:tidal"

  // True while the TIDAL panel is showing (special:tidal is the active special
  // workspace). Drives the bar widget's open-panel indicator.
  property bool panelVisible: false

  // Hyprland only tells us when the special workspace *changes*; seed the state
  // once so a shell restart with the panel already open is not wrong until the
  // next toggle.
  Process {
    id: specialProbe
    running: true
    command: ["bash", "-c",
      "hyprctl monitors -j | jq -r 'any(.[]; .specialWorkspace.name == \"" + root.specialWs + "\")'"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { if (root.alive) root.panelVisible = (String(line).trim() === "true") }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!root.alive || !event) return
      var name = String(event.name || "")
      var parts = String(event.data || "").split(",")

      if (name === "activespecial") {
        root.panelVisible = String(parts[0] || "") === root.specialWs
      } else if (name === "activespecialv2") {
        root.panelVisible = String(parts[1] || "") === root.specialWs
      }
    }
  }

  function runLauncher(arg) {
    if (root.launcher === "") return
    Quickshell.execDetached(["bash", "-c", "exec \"$0\" \"$1\"", root.launcher, String(arg)])
  }

  function toggleWeb() { root.runLauncher("toggle"); return true }
  function showWeb() { root.runLauncher("show"); return true }
  function hideWeb() { root.runLauncher("hide"); return true }
  function quit() { root.runLauncher("stop"); return true }

  // ---- transport -----------------------------------------------------

  function playPause() {
    if (!player) { root.showWeb(); return true }
    if (player.canTogglePlaying) player.togglePlaying()
    else if (player.isPlaying && player.canPause) player.pause()
    else if (player.canPlay) player.play()
    return true
  }

  function next() {
    if (player && player.canGoNext) player.next()
    return true
  }

  function previous() {
    if (player && player.canGoPrevious) player.previous()
    return true
  }

  // ---- track notifications ------------------------------------------

  property bool notifyOnTrackChange: true

  function announceTrack() {
    if (!root.notifyOnTrackChange || !root.hasTrack) return
    var body = root.artist
    if (root.album !== "") body = body === "" ? root.album : body + "  ·  " + root.album
    Quickshell.execDetached([
      "notify-send", "--app-name=TIDAL", "--expire-time=5000",
      "--hint=string:x-canonical-private-synchronous:omarchy-tidalweb",
      Format.plain(root.title), Format.plain(body)
    ])
  }

  // ---- status + IPC ------------------------------------------------

  function statusJson() {
    return JSON.stringify({
      connected: root.connected,
      playing: root.playing,
      hasTrack: root.hasTrack,
      title: root.title,
      artist: root.artist,
      album: root.album,
      artUrl: root.artUrl,
      panelVisible: root.panelVisible
    })
  }

  IpcHandler {
    target: "tidalweb"

    function status(): string { return root.statusJson() }
    function toggle(): string { return root.toggleWeb() ? "ok" : "unhandled" }
    function show(): string { return root.showWeb() ? "ok" : "unhandled" }
    function hide(): string { return root.hideWeb() ? "ok" : "unhandled" }
    function playPause(): string { return root.playPause() ? "ok" : "unhandled" }
    function next(): string { return root.next() ? "ok" : "unhandled" }
    function previous(): string { return root.previous() ? "ok" : "unhandled" }
    function quit(): string { return root.quit() ? "ok" : "unhandled" }
    function ping(): string { return "ok" }
  }
}
