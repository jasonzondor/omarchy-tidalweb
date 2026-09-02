/*
 * omt-inject.js — the only file that knows what TIDAL's web DOM looks like.
 *
 * The Python bridge injects this into the TIDAL page (once on every document
 * via Page.addScriptToEvaluateOnNewDocument, and once immediately for the
 * already-loaded page). It reads now-playing / lyrics / queue / quality and
 * pushes them back through the `__omtSend` binding the bridge registers, and
 * it exposes `window.__omt` so the bridge can drive actions with
 * Runtime.evaluate.
 *
 * TIDAL ships frontend changes without notice. When lyrics or the queue stop
 * working, the fix is almost always in SELECTORS below — add the new selector
 * to the front of the relevant list. Derive one by opening the TIDAL web
 * player, DevTools > Elements, and inspecting the element you want. `data-test`
 * attributes are the most stable; class names are hashed and rotate.
 */
(function () {
  "use strict";
  if (window.__omt) {
    window.__omt.rescan();
    return;
  }

  var SELECTORS = {
    play: ['[data-test="play"]', 'button[aria-label="Play" i]', '#footerPlayerControls [aria-label="Play" i]'],
    pause: ['[data-test="pause"]', 'button[aria-label="Pause" i]', '#footerPlayerControls [aria-label="Pause" i]'],
    next: ['[data-test="next"]', 'button[aria-label="Next track" i]', 'button[aria-label="Next" i]'],
    prev: ['[data-test="previous"]', 'button[aria-label="Previous track" i]', 'button[aria-label="Previous" i]'],
    favorite: [
      '[data-test="footer-favorite-button"]',
      '[data-test="favorite-button"]',
      '#footerPlayer button[aria-label*="favorite" i]',
      'button[aria-label*="Add to favorites" i]',
    ],
    title: ['[data-test="footer-track-title"]', '[data-test="now-playing-track-title"]', '#footerPlayer a[href*="/track/"]'],
    artist: ['[data-test="footer-track-artist"]', '#footerPlayer a[href*="/artist/"]', '[data-test="grid-item-detail-meta"] a'],
    album: ['#footerPlayer a[href*="/album/"]'],
    lyricsLine: [
      '[data-test="lyrics-line"]',
      '[class*="lyricsLine" i]',
      '[class*="LyricLine" i]',
      '[data-test="lyrics"] p',
    ],
    lyricsActiveAttr: ["data-current", "aria-current"],
    lyricsActiveClass: ["current", "active", "highlight"],
    queueItem: [
      '[data-test="queue-item"]',
      '[data-test="play-queue-item"]',
      '[class*="queueItem" i]',
      '[class*="QueueItem" i]',
    ],
    quality: [
      '[data-test="quality-selector"] [class*="value" i]',
      '[data-test="playback-quality"]',
      '[class*="mediaQuality" i]',
      '[data-test="streaming-quality"]',
    ],
    loginWall: ['a[href*="login.tidal.com"]', '[data-test="login-button"]', 'input[type="password"]'],
  };

  function first(list) {
    for (var i = 0; i < list.length; i++) {
      try {
        var el = document.querySelector(list[i]);
        if (el) return el;
      } catch (e) {}
    }
    return null;
  }

  function all(list) {
    for (var i = 0; i < list.length; i++) {
      try {
        var els = document.querySelectorAll(list[i]);
        if (els && els.length) return Array.prototype.slice.call(els);
      } catch (e) {}
    }
    return [];
  }

  function txt(el) {
    return el ? String(el.textContent || "").replace(/\s+/g, " ").trim() : "";
  }

  function send(obj) {
    try {
      if (typeof window.__omtSend === "function") window.__omtSend(JSON.stringify(obj));
    } catch (e) {}
  }

  function signedIn() {
    return !first(SELECTORS.loginWall);
  }

  // ---- readers ------------------------------------------------------------

  function nowPlaying() {
    var meta = navigator.mediaSession && navigator.mediaSession.metadata;
    var art = "";
    if (meta && meta.artwork && meta.artwork.length) {
      art = meta.artwork[meta.artwork.length - 1].src || "";
    }
    var title = (meta && meta.title) || txt(first(SELECTORS.title));
    var artist = (meta && meta.artist) || txt(first(SELECTORS.artist));
    var album = (meta && meta.album) || txt(first(SELECTORS.album));
    var state = navigator.mediaSession ? navigator.mediaSession.playbackState : "none";
    return { ev: "nowplaying", title: title, artist: artist, album: album, art: art, state: state, signedIn: signedIn() };
  }

  function isActiveLine(el) {
    for (var i = 0; i < SELECTORS.lyricsActiveAttr.length; i++) {
      var v = el.getAttribute(SELECTORS.lyricsActiveAttr[i]);
      if (v && v !== "false") return true;
    }
    var cls = String(el.className || "").toLowerCase();
    for (var j = 0; j < SELECTORS.lyricsActiveClass.length; j++) {
      if (cls.indexOf(SELECTORS.lyricsActiveClass[j]) !== -1) return true;
    }
    return false;
  }

  function lyrics() {
    var nodes = all(SELECTORS.lyricsLine);
    var lines = [];
    var activeIndex = -1;
    for (var i = 0; i < nodes.length; i++) {
      var t = txt(nodes[i]);
      if (!t) continue;
      if (isActiveLine(nodes[i])) activeIndex = lines.length;
      lines.push(t);
    }
    return { ev: "lyrics", lines: lines, activeIndex: activeIndex };
  }

  function queue() {
    var nodes = all(SELECTORS.queueItem);
    var tracks = [];
    for (var i = 0; i < nodes.length && i < 100; i++) {
      var titleEl = nodes[i].querySelector('[data-test="table-cell-title"], [class*="title" i], a[href*="/track/"]');
      var artistEl = nodes[i].querySelector('[data-test="table-cell-artist"], [class*="artist" i], a[href*="/artist/"]');
      var line = txt(titleEl) || txt(nodes[i]).split("\n")[0];
      if (!line) continue;
      tracks.push({ title: line, artist: txt(artistEl), index: i });
    }
    return { ev: "queue", tracks: tracks };
  }

  function quality() {
    return { ev: "quality", label: txt(first(SELECTORS.quality)) };
  }

  // ---- actions -----------------------------------------------------------

  function click(list) {
    var el = first(list);
    if (el) {
      el.click();
      return true;
    }
    return false;
  }

  function playpause() {
    var state = navigator.mediaSession ? navigator.mediaSession.playbackState : "";
    if (state === "playing") return click(SELECTORS.pause) || click(SELECTORS.play);
    return click(SELECTORS.play) || click(SELECTORS.pause);
  }

  function queuePlay(i) {
    var nodes = all(SELECTORS.queueItem);
    if (nodes[i]) {
      var ev = new MouseEvent("dblclick", { bubbles: true, cancelable: true, view: window });
      nodes[i].dispatchEvent(ev);
      return true;
    }
    return false;
  }

  // ---- scan + observe --------------------------------------------------

  var lastLyrics = "";
  var lastQueue = "";
  var lastQuality = "";
  var lastNow = "";

  function rescan() {
    var n = nowPlaying();
    var nk = n.title + "" + n.artist + "" + n.state + "" + n.signedIn;
    if (nk !== lastNow) { lastNow = nk; send(n); }

    var l = lyrics();
    var lk = l.lines.join("\n") + "" + l.activeIndex;
    if (lk !== lastLyrics) { lastLyrics = lk; send(l); }

    var q = queue();
    var qk = JSON.stringify(q.tracks);
    if (qk !== lastQueue) { lastQueue = qk; send(q); }

    var qual = quality();
    if (qual.label !== lastQuality) { lastQuality = qual.label; send(qual); }
  }

  var pending = null;
  function schedule() {
    if (pending) return;
    pending = setTimeout(function () {
      pending = null;
      rescan();
    }, 250);
  }

  var mo = new MutationObserver(schedule);
  function attach() {
    if (document.body) {
      mo.observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ["data-current", "aria-current", "class"] });
      rescan();
    } else {
      setTimeout(attach, 200);
    }
  }
  attach();
  // Backstop: MediaSession has no change event and some updates dodge the
  // observer. Cheap enough at this interval.
  setInterval(rescan, 2000);

  window.__omt = {
    rescan: rescan,
    playpause: playpause,
    next: function () { return click(SELECTORS.next); },
    prev: function () { return click(SELECTORS.prev); },
    favorite: function () { return click(SELECTORS.favorite); },
    queuePlay: queuePlay,
    signedIn: signedIn,
    snapshot: function () {
      return JSON.stringify({ now: nowPlaying(), lyrics: lyrics(), queue: queue(), quality: quality() });
    },
  };

  send({ ev: "injected" });
})();
