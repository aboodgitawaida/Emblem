import AppKit

/// A snapshot of what's playing in one app.
struct NowPlayingInfo: Equatable {
    var bundleID: String
    var title: String
    var artist: String
    var album: String = ""
    /// The source sent an album field (even an empty one). The system player then shows "Artist – ".
    var hasAlbum = false
    var isPlaying: Bool
    var duration: TimeInterval = 0          // seconds, 0 if unknown
    var elapsed: TimeInterval = 0           // seconds at `elapsedAt`
    var elapsedAt: Date = Date()
    var trackID: String = ""
    var artwork: NSImage? = nil

    /// Elapsed time extrapolated to `date` while playing.
    func elapsed(at date: Date) -> TimeInterval {
        let e = isPlaying ? elapsed + date.timeIntervalSince(elapsedAt) : elapsed
        return duration > 0 ? min(max(e, 0), duration) : max(e, 0)
    }

    /// Browsers playing web video get 15-second skip buttons instead of previous/next, like the system player.
    var isWebVideo: Bool {
        ["com.apple.Safari", "com.google.Chrome", "company.thebrowser.Browser", "org.mozilla.firefox",
         "com.microsoft.edgemac", "com.brave.Browser", "com.operasoftware.Opera"].contains(bundleID)
    }

    var appName: String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let name = FileManager.default.displayName(atPath: url.path).split(separator: ".").first {
            return String(name)
        }
        return bundleID
    }

    var appIcon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map {
            NSWorkspace.shared.icon(forFile: $0.path)
        }
    }

    static func == (a: Self, b: Self) -> Bool {
        a.bundleID == b.bundleID && a.title == b.title && a.artist == b.artist && a.album == b.album && a.hasAlbum == b.hasAlbum
            && a.isPlaying == b.isPlaying && a.duration == b.duration && a.elapsed == b.elapsed
            && a.elapsedAt == b.elapsedAt && a.trackID == b.trackID && a.artwork === b.artwork
    }
}

enum PlaybackCommand { case togglePlayPause, next, previous, skipBack15, skipForward15 }
