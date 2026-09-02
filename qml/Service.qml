import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "lib/Format.js" as Format

// Headless source of truth for the com.zondor.tidalweb plugin.
//
// Two inputs feed it:
//
//   1. MPRIS (Quickshell.Services.Mpris) — Chromium exports the TIDAL web
//      player's now-playing state and transport over D-Bus, push-based, so
//      title/artist/art/position/play-pause cost nothing and need no polling.
//   2. bin/omarchy-tidalweb-bridge — a child process speaking the Chrome
//      DevTools Protocol to the same Chromium, for the things MPRIS cannot
//      express: synced-ish lyrics, the play queue, the stream-quality badge,
//      and "favorite this track". Events arrive as JSON lines on its stdout.
//
// Everything degrades: no bridge means no lyrics/queue but a fully working
// now-playing widget and transport.
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
  readonly property string bridgeScript: pluginDir === "" ? "" : pluginDir + "/bin/omarchy-tidalweb-bridge"


  // Saving any file under ~/.config/omarchy/plugins/ hot-reloads plugin code,
  // destroying this object while a Process callback or Timer may still fire.
  // Every async path bails once this flips (mirrors ph0bos/omarchy-tidal).
  property bool alive: true
  Component.onDestruction: {
    root.alive = false
    root.bridgeWanted = false
    bridgeProcess.running = false
  }

  // ---- MPRIS binding -----------------------------------------------------

  readonly property var players: Mpris.players ? Mpris.players.values : []

  // The Chromium instance we launched only ever plays TIDAL, so "the chromium
  // player" is the right one. When more than one Chromium is exporting a
  // player, prefer the one that actually has a track.
  readonly property var player: {
    var fallback = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p) continue
      var bus = String(p.dbusName || "").toLowerCase()
      var id = String(p.identity || "").toLowerCase()
      var entry = String(p.desktopEntry || "").toLowerCase()
      var isChromium = bus.indexOf("chromium") !== -1 || bus.indexOf("chrome") !== -1
        || id.indexOf("chromium") !== -1 || id.indexOf("chrome") !== -1
        || entry.indexOf("chromium") !== -1 || entry.indexOf("chrome") !== -1
      if (!isChromium) continue
      if (p.trackTitle || p.trackArtist) return p
      if (!fallback) fallback = p
    }
    return fallback
  }

  readonly property bool connected: player !== null || bridgeConnected
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
  readonly property string trackKey: title + "" + artist + "" + album

  // Position runs off a wall-clock anchor rather than polling player.position
  // (a D-Bus round trip) or a counter (drifts under load).
  property real position: 0
  property real anchorPos: 0
  property real anchorAt: 0

  function anchorPosition(seconds) {
    root.anchorPos = Math.max(0, seconds)
    root.anchorAt = Date.now()
    root.position = root.anchorPos
  }

  function syncPosition() {
    if (player && player.positionSupported) root.anchorPosition(player.position)
  }

  Timer {
    running: root.playing && root.hasTrack
    interval: 250
    repeat: true
    onTriggered: {
      if (!root.alive) return
      var next = root.anchorPos + (Date.now() - root.anchorAt) / 1000
      root.position = root.length > 0 ? Math.min(next, root.length) : next
    }
  }

  Timer {
    running: root.playing && root.hasTrack
    interval: 5000
    repeat: true
    onTriggered: if (root.alive) root.syncPosition()
  }

  onPlayingChanged: {
    if (!root.alive) return
    root.anchorPosition(root.position)
    Qt.callLater(root.syncPosition)
  }

  onTrackKeyChanged: {
    if (!root.alive) return
    root.anchorPosition(0)
    Qt.callLater(root.syncPosition)
    if (root.seenATrack && root.hasTrack) Qt.callLater(root.announceTrack)
    if (root.hasTrack) root.seenATrack = true
    // Lyrics/queue for the new track arrive via the bridge's own observers;
    // nudge it in case the page was quiet.
    root.sendBridge({ cmd: "rescan" })
  }
  property bool seenATrack: false

  // ---- bridge (Chrome DevTools) -----------------------------------------

  property bool bridgeConnected: false
  property bool signedIn: true
  property var lyricsLines: []
  property int lyricsActive: -1
  property var queue: []
  property string qualityLabel: ""

  function sendBridge(obj) {
    if (!bridgeProcess.running) return
    try { bridgeProcess.write(JSON.stringify(obj) + "\n") } catch (e) {}
  }

  function handleBridgeLine(line) {
    if (!root.alive || !line) return
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    switch (msg.ev) {
      case "ready":
        root.bridgeConnected = true
        break
      case "disconnected":
        root.bridgeConnected = false
        break
      case "nowplaying":
        if (msg.signedIn !== undefined) root.signedIn = !!msg.signedIn
        break
      case "lyrics":
        root.lyricsLines = Array.isArray(msg.lines) ? msg.lines : []
        root.lyricsActive = typeof msg.activeIndex === "number" ? msg.activeIndex : -1
        break
      case "queue":
        root.queue = Array.isArray(msg.tracks) ? msg.tracks : []
        break
      case "quality":
        root.qualityLabel = String(msg.label || "")
        break
    }
  }

  Process {
    id: bridgeProcess
    // python3 pinned to /usr/bin: the shell's PATH puts mise shims first, and a
    // shim with no project context fails to start under QProcess. Guarded so it
    // is never spawned before pluginDir (and so bridgeScript) is known.
    command: root.bridgeScript === "" ? [] : ["/usr/bin/python3", root.bridgeScript]
    running: false
    stdinEnabled: true
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.handleBridgeLine(line) }
    }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { if (line) console.warn("tidalweb bridge:", line) }
    }
    onExited: {
      if (!root.alive) return
      root.bridgeConnected = false
      bridgeRestart.restart()
    }
  }

  Timer {
    id: bridgeRestart
    interval: 4000
    repeat: false
    onTriggered: root.maybeStartBridge()
  }

  property bool bridgeWanted: false

  function startBridge() {
    root.bridgeWanted = true
    root.maybeStartBridge()
  }

  // The shell injects `manifest` AFTER Component.onCompleted runs, so pluginDir
  // (and therefore the resolved bridge path) is empty at construction. Wait for
  // it before spawning, and react when it arrives.
  function maybeStartBridge() {
    if (!root.alive || !root.bridgeWanted) return
    if (root.pluginDir === "") return
    if (!bridgeProcess.running) bridgeProcess.running = true
  }

  onPluginDirChanged: root.maybeStartBridge()

  Component.onCompleted: {
    // Want the bridge up on shell load so a track already playing shows lyrics
    // and the quality badge without waiting for a summon. The shell injects
    // `manifest` (and so pluginDir) AFTER this runs, so the actual spawn is
    // deferred to onPluginDirChanged via maybeStartBridge.
    root.bridgeWanted = true
    root.maybeStartBridge()
  }

  // ---- web instance -----------------------------------------------------

  function runLauncher(arg) {
    if (root.pluginDir === "") return
    Quickshell.execDetached(["bash", "-c", "exec \"$0\" \"$1\"", root.launcher, String(arg)])
  }

  function ensureWeb() {
    root.startBridge()
    root.runLauncher("launch")
  }

  function showWeb() {
    root.startBridge()
    root.runLauncher("show")
    return true
  }

  // ---- transport -------------------------------------------------------

  function playPause() {
    if (player && player.canTogglePlaying) { player.togglePlaying(); return true }
    if (player && player.isPlaying && player.canPause) { player.pause(); return true }
    if (player && player.canPlay) { player.play(); return true }
    root.sendBridge({ cmd: "playpause" })
    return true
  }

  function next() {
    if (player && player.canGoNext) { player.next(); return true }
    root.sendBridge({ cmd: "next" })
    return true
  }

  function previous() {
    if (player && player.canGoPrevious) { player.previous(); return true }
    root.sendBridge({ cmd: "prev" })
    return true
  }

  function previewSeek(ms) {
    root.anchorPosition(ms / 1000)
  }

  function commitSeek(ms) {
    root.anchorPosition(ms / 1000)
    if (player && player.canSeek && player.positionSupported) {
      player.position = ms / 1000
      Qt.callLater(root.syncPosition)
    }
  }

  function seekTo(ms) { root.commitSeek(ms) }

  function favorite() {
    root.sendBridge({ cmd: "favorite" })
    root.osd("Favorite", "heart")
    return true
  }

  function search(query) {
    var q = String(query || "").trim()
    if (q === "") { return root.showWeb() }
    root.ensureWeb()
    root.sendBridge({ cmd: "navigate", url: "https://listen.tidal.com/search?q=" + encodeURIComponent(q) })
    Qt.callLater(root.showWeb)
    return true
  }

  function playQueueIndex(i) {
    root.sendBridge({ cmd: "queuePlay", index: Number(i) || 0 })
  }

  // Deep-link the existing web window to a TIDAL route (e.g. "/browse").
  function openPath(path) {
    root.ensureWeb()
    root.sendBridge({ cmd: "navigate", url: "https://listen.tidal.com" + String(path || "/") })
    Qt.callLater(root.showWeb)
    return true
  }

  // ---- surfaces -------------------------------------------------------

  function openView(view) {
    if (!shell) return false
    root.ensureWeb()
    return shell.summon(pluginId, JSON.stringify({ view: String(view || "player") })) === true
  }

  function closeSurfaces() {
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function quit() {
    root.closeSurfaces()
    root.bridgeWanted = false
    bridgeProcess.running = false
    root.runLauncher("stop")
    return true
  }

  function plainMessage(message) { return Format.plain(message) }

  function osd(message, icon) {
    if (!shell) return
    shell.summon("omarchy.osd", JSON.stringify({
      icon: icon || "media",
      message: Format.plain(message)
    }))
  }

  // ---- track notifications -------------------------------------------

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

  // ---- status + IPC -------------------------------------------------

  function statusJson() {
    return JSON.stringify({
      connected: root.connected,
      bridge: root.bridgeConnected,
      signedIn: root.signedIn,
      playing: root.playing,
      hasTrack: root.hasTrack,
      title: root.title,
      artist: root.artist,
      album: root.album,
      artUrl: root.artUrl,
      position: root.position,
      length: root.length,
      quality: root.qualityLabel,
      lyrics: root.lyricsLines.length,
      queue: root.queue.length
    })
  }

  IpcHandler {
    target: "tidalweb"

    function status(): string { return root.statusJson() }
    function overlay(): string { return root.openView("player") ? "ok" : "unhandled" }
    function player(): string { return root.openView("player") ? "ok" : "unhandled" }
    function lyrics(): string { return root.openView("lyrics") ? "ok" : "unhandled" }
    function queue(): string { return root.openView("queue") ? "ok" : "unhandled" }
    function search(query: string): string {
      root.openView("search")
      if (query && String(query).trim() !== "") root.search(String(query))
      return "ok"
    }
    function web(): string { return root.showWeb() ? "ok" : "unhandled" }
    function favorite(): string { return root.favorite() ? "ok" : "unhandled" }
    function playPause(): string { return root.playPause() ? "ok" : "unhandled" }
    function next(): string { return root.next() ? "ok" : "unhandled" }
    function previous(): string { return root.previous() ? "ok" : "unhandled" }
    function quit(): string { return root.quit() ? "ok" : "unhandled" }
    function ping(): string { return "ok" }
  }
}
