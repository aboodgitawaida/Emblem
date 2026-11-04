import AppKit

/// A snapshot of what's playing in one app.
struct NowPlayingInfo: Equatable {
    var bundleID: String
    var title: String
    var artist: String
    var album: String = ""
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
        a.bundleID == b.bundleID && a.title == b.title && a.artist == b.artist && a.album == b.album
            && a.isPlaying == b.isPlaying && a.duration == b.duration && a.elapsed == b.elapsed
            && a.elapsedAt == b.elapsedAt && a.trackID == b.trackID && a.artwork === b.artwork
    }
}

enum PlaybackCommand { case togglePlayPause, next, previous }
