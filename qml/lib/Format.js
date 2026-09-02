// Small formatting helpers shared across the plugin's surfaces.
.pragma library

// Seconds -> "1:04". The only time format the UI shows.
function clock(seconds) {
  var total = Number(seconds)
  if (!isFinite(total) || total < 0) return "0:00"
  total = Math.floor(total)
  var m = Math.floor(total / 60)
  var s = total % 60
  return m + ":" + (s < 10 ? "0" + s : s)
}

// "Title  ·  Artist", or just one side when the other is empty.
function trackLabel(title, artist) {
  if (!title) return artist || ""
  return artist ? (title + "  ·  " + artist) : title
}

// Angle brackets stripped: catalogue strings (a playlist name, a TIDAL error)
// cross into other plugins' surfaces that may treat them as markup.
function plain(message) {
  return String(message || "").replace(/[<>]/g, "")
}
